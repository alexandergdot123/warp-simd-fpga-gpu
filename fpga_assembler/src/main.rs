//! Assembler for the SIMT GPU ISA (redesigned).
//!
//! 32-bit fixed-width instructions. Opcode is ALWAYS the top 4 bits [31:28].
//! No .org / no absolute addressing. Output is a flat word stream from index 0.
//!
//! ============================ ISA REFERENCE ============================
//!
//! Register file: r0..r15 (4-bit fields).
//!
//! ALU (opcode 0b0000 .. 0b0101):
//!   add  rD, rS1, (rS2|imm18)   op=0  bit18=0   reg: sr2@[17:14]  imm@[17:0]
//!   sub  rD, rS1, (rS2|imm18)   op=0  bit18=1   reg: sr2@[17:14]  imm@[17:0]
//!   and  rD, rS1, (rS2|imm18)   op=1  bit18=0   reg: sr2@[17:14]  imm@[17:0]
//!   or   rD, rS1, (rS2|imm18)   op=1  bit18=1   reg: sr2@[17:14]  imm@[17:0]   (ASSUMPTION: OR=bit18=1)
//!   xor  rD, rS1, (rS2|imm19)   op=2            reg: sr2@[18:15]  imm@[18:0]
//!   mul  rD, rS1, (rS2|imm19)   op=3            reg: sr2@[18:15]  imm@[18:0]
//!   div  rD, rS1, (rS2|imm19)   op=4            reg: sr2@[18:15]  imm@[18:0]
//!   bit19 = immediate flag for all of the above.
//!
//! Shifts (opcode 0b0101). Shift amount must be one of {1,2,4,8,16,24}:
//!   lsl rD, rS1, amt    bit19=0 bit18=0   sel@[17:15]
//!   lsr rD, rS1, amt    bit19=0 bit18=1   sel@[17:15]
//!   asr rD, rS1, amt    bit19=1 bit18=0   sel@[17:15]
//!     sel encoding: 1->000 2->001 4->010 8->011 16->100 24->101
//!
//! Compare / predicated core-disable. The core turns OFF for `count` dynamic
//! instructions when the chosen condition holds. NZP bits: a 0 bit means
//! "turn off for that sign of (sr1 - operand)". The third operand is either an
//! immediate skip count (0..63) or a forward label (distance auto-computed).
//!   Register operand  -> CMP  (op=0b0111): sr1@[27:24] sr2@[23:20] N=19 Z=18 P=17 count@[16:9]
//!   Immediate operand -> CMPi (op=0b0110): sr1@[27:24] imm@[14:0]  N=23 Z=22 P=21 count@[20:13]
//!     (ASSUMPTION: CMPi immediate lives in bits [14:0], sign-extended 15-bit.)
//!   Mnemonics (condition under which the core SKIPS / turns off):
//!     skip_lt  sr1 <  operand   NZP=011
//!     skip_le  sr1 <= operand   NZP=001
//!     skip_eq  sr1 == operand   NZP=101
//!     skip_ne  sr1 != operand   NZP=010
//!     skip_gt  sr1 >  operand   NZP=110
//!     skip_ge  sr1 >= operand   NZP=100
//!   Usage:  skip_eq r1, r2, end      (register compare, forward label)
//!           skip_lt r1, 10, 4        (immediate compare, skip 4 instructions)
//!
//! Loads  DR <- M[SR1 + (SR2|imm19)]   bit19 = immediate flag:
//!   lw   rD, rS1, (rS2|imm19)   op=0b1000  (shared / SRAM)
//!   lwg  rD, rS1, (rS2|imm19)   op=0b1001  (global / DDR3)
//!     reg: sr2@[18:15]   imm@[18:0]
//!
//! Stores  M[SR1 + imm16] <- SR2 (always immediate offset). Optional 4-bit
//! byte-enable (default 0xF = full word):
//!   sw   rAddr, rVal, imm16 [, be]   op=0b1010  (shared / SRAM)
//!   swg  rAddr, rVal, imm16 [, be]   op=0b1011  (global / DDR3)
//!     sr1(addr)@[27:24] sr2(val)@[23:20] be@[19:16] imm@[15:0]
//!
//! Set-less-than (writes 1/0 to rD):
//!   slt  rD, rS1, (rS2|imm18)   op=0b1100  bit18=0   sr1 <  operand
//!   slte rD, rS1, (rS2|imm18)   op=0b1100  bit18=1   sr1 <= operand
//!     bit19=imm flag   reg: sr2@[17:14]   imm@[17:0]
//!
//! Barrier (memory sync + context-count reprogram), op=0b1111:
//!   barrier            reuse previous context count
//!   barrier N          set context count to N (1..16); field = N-1 @[3:0]
//!     (ASSUMPTION: the very first barrier must specify N; otherwise error.)
//!
//! CPU store block, op=0b1101 (CPU writes shared mem directly):
//!   cpu_store addr16 [, N]
//!   <N data words follow, one per line: bare value, .word V, or .data V>
//!     num_words@[27:16]   addr@[15:0].  N may be omitted and inferred from the
//!     contiguous block of following data lines.
//!
//! Data directive (raw word emit, usable anywhere):
//!   .data V  /  .data(K) V  /  .word V
//!
//! ======================================================================

use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::Path;

/* ===================== TEXT HELPERS ===================== */

fn strip_comment(s: &str) -> &str {
    let markers = ["#", ";", "//"];
    let end = markers
        .iter()
        .filter_map(|m| s.find(m))
        .min()
        .unwrap_or(s.len());
    &s[..end]
}

fn is_reg(tok: &str) -> bool {
    let t = tok.trim();
    (t.starts_with('r') || t.starts_with('R'))
        && t.len() >= 2
        && t[1..].chars().all(|c| c.is_ascii_digit())
}

fn parse_reg(tok: &str, lineno: usize) -> u32 {
    if !is_reg(tok) {
        panic!("line {}: expected register r0..r15, got '{}'", lineno, tok);
    }
    let n: u32 = tok[1..].parse().expect("digits");
    if n > 15 {
        panic!("line {}: register r{} out of range (r0..r15)", lineno, n);
    }
    n
}

/// Parse a signed integer literal (decimal or 0x hex). Hex is taken as a bit
/// pattern (e.g. 0xFFFF -> 65535), decimal may be negative.
fn parse_int(tok: &str) -> Option<i64> {
    let t = tok.trim();
    if t.is_empty() {
        return None;
    }
    if let Some(h) = t.strip_prefix("-0x").or_else(|| t.strip_prefix("-0X")) {
        return i64::from_str_radix(h, 16).ok().map(|x| -x);
    }
    if let Some(h) = t.strip_prefix("0x").or_else(|| t.strip_prefix("0X")) {
        return i64::from_str_radix(h, 16).ok();
    }
    t.parse::<i64>().ok()
}

/// Encode a signed immediate into a `width`-bit field (returned already
/// positioned at bit 0). Accepts signed [-2^(w-1), 2^(w-1)-1] or the unsigned
/// bit-pattern range [0, 2^w - 1]. Range-checked.
fn enc_imm(value: i64, width: u32, lineno: usize) -> u32 {
    let umax = (1i64 << width) - 1;
    let smin = -(1i64 << (width - 1));
    if value < smin || value > umax {
        panic!(
            "line {}: immediate {} out of range for {}-bit field [{}..{}]",
            lineno, value, width, smin, umax
        );
    }
    (value as u32) & (((1u64 << width) - 1) as u32)
}

/// `.data` -> 1, `.data(K)` -> K. None if not a .data directive.
fn parse_data_repeat(op_lower: &str) -> Option<usize> {
    if op_lower == ".data" {
        Some(1)
    } else if let Some(inner) = op_lower
        .strip_prefix(".data(")
        .and_then(|s| s.strip_suffix(')'))
    {
        let n = inner
            .parse::<usize>()
            .unwrap_or_else(|_| panic!("bad .data repeat count '{}'", inner));
        if n == 0 {
            panic!(".data repeat count must be >= 1");
        }
        Some(n)
    } else {
        None
    }
}

/// Parse a raw 32-bit data word literal (decimal/hex, optional leading '-').
fn parse_word_value(s: &str) -> Option<u32> {
    let s = s.trim();
    if s.is_empty() {
        return None;
    }
    let (neg, body) = if let Some(r) = s.strip_prefix('-') {
        (true, r)
    } else {
        (false, s)
    };
    let mag: u64 = if let Some(h) = body.strip_prefix("0x").or_else(|| body.strip_prefix("0X")) {
        u64::from_str_radix(h, 16).ok()?
    } else {
        body.parse::<u64>().ok()?
    };
    if mag > 0xFFFF_FFFF {
        return None;
    }
    let v = mag as u32;
    Some(if neg { v.wrapping_neg() } else { v })
}

/// Try to read a line as one or more data words.
/// `allow_bare`: also accept a bare numeric literal (used inside cpu_store blocks).
fn try_data_word(line: &str, allow_bare: bool) -> Option<Vec<u32>> {
    let mut toks = line.split_whitespace();
    let first = toks.next()?;
    let lower = first.to_lowercase();

    if let Some(rep) = parse_data_repeat(&lower) {
        let val_str = line[first.len()..].trim();
        let w = parse_word_value(val_str)
            .unwrap_or_else(|| panic!("bad .data value '{}'", val_str));
        return Some(vec![w; rep]);
    }
    if lower == ".word" {
        let val_str = line[first.len()..].trim();
        let w = parse_word_value(val_str)
            .unwrap_or_else(|| panic!("bad .word value '{}'", val_str));
        return Some(vec![w]);
    }
    if allow_bare {
        if let Some(w) = parse_word_value(first) {
            if toks.next().is_none() {
                return Some(vec![w]);
            }
        }
    }
    None
}

/* ===================== PENDING (forward label fixups) ===================== */

struct Pending {
    pos: usize,   // index into `words` of the compare instruction
    label: String,
    shift: u32,   // bit position of the 8-bit count field (9 for CMP, 13 for CMPi)
    lineno: usize,
}

/* ===================== INSTRUCTION ENCODER ===================== */

fn encode_instruction(
    mn_raw: &str,
    args: &[String],
    next_index: usize,
    pending: &mut Vec<Pending>,
    labels: &HashMap<String, usize>,
    prev_ctx: &mut Option<u32>,
    lineno: usize,
) -> u32 {
    let mn = mn_raw.to_lowercase();

    let need = |n: usize| {
        if args.len() != n {
            panic!(
                "line {}: '{}' expects {} operand(s), got {}",
                lineno, mn, n, args.len()
            );
        }
    };
    let reg = |i: usize| parse_reg(&args[i], lineno);

    // ---------- ALU: add/sub/and/or (18-bit imm, sr2@[17:14], bit18=opsel) ----------
    let alu18 = |opcode: u32, opsel: bool| -> u32 {
        need(3);
        let mut w = opcode << 28;
        w |= reg(0) << 24;
        w |= reg(1) << 20;
        if opsel {
            w |= 1 << 18;
        }
        if is_reg(&args[2]) {
            // bit19 = 0 (register)
            w |= reg(2) << 14;
        } else {
            w |= 1 << 19; // immediate
            let v = parse_int(&args[2])
                .unwrap_or_else(|| panic!("line {}: bad operand '{}'", lineno, args[2]));
            w |= enc_imm(v, 18, lineno);
        }
        w
    };

    // ---------- ALU: xor/mul/div (19-bit imm, sr2@[18:15]) ----------
    let alu19 = |opcode: u32| -> u32 {
        need(3);
        let mut w = opcode << 28;
        w |= reg(0) << 24;
        w |= reg(1) << 20;
        if is_reg(&args[2]) {
            w |= reg(2) << 15;
        } else {
            w |= 1 << 19;
            let v = parse_int(&args[2])
                .unwrap_or_else(|| panic!("line {}: bad operand '{}'", lineno, args[2]));
            w |= enc_imm(v, 19, lineno);
        }
        w
    };

    // ---------- shifts (opcode 5) ----------
    let shift = |b19: bool, b18: bool| -> u32 {
        need(3);
        let mut w = 5u32 << 28;
        w |= reg(0) << 24;
        w |= reg(1) << 20;
        if b19 {
            w |= 1 << 19;
        }
        if b18 {
            w |= 1 << 18;
        }
        let amt = parse_int(&args[2])
            .unwrap_or_else(|| panic!("line {}: shift amount must be a literal", lineno));
        let sel = match amt {
            1 => 0,
            2 => 1,
            4 => 2,
            8 => 3,
            16 => 4,
            24 => 5,
            other => panic!(
                "line {}: shift amount {} unsupported (use 1,2,4,8,16,24)",
                lineno, other
            ),
        };
        w |= (sel as u32) << 15;
        w
    };

    // ---------- loads (opcode 8 shared / 9 global) ----------
    let load = |opcode: u32| -> u32 {
        need(3);
        let mut w = opcode << 28;
        w |= reg(0) << 24;
        w |= reg(1) << 20;
        if is_reg(&args[2]) {
            w |= reg(2) << 15;
        } else {
            w |= 1 << 19;
            let v = parse_int(&args[2])
                .unwrap_or_else(|| panic!("line {}: bad offset '{}'", lineno, args[2]));
            w |= enc_imm(v, 19, lineno);
        }
        w
    };

    // ---------- stores (opcode 10 shared / 11 global) ----------
    let store = |opcode: u32| -> u32 {
        if args.len() != 3 && args.len() != 4 {
            panic!(
                "line {}: '{}' expects rVal, rAddr, imm [, be]",
                lineno, mn
            );
        }
        let mut w = opcode << 28;
        w |= reg(0) << 20; // value   -> sr2 @[23:20]
        w |= reg(1) << 24; // address -> sr1 @[27:24]
        let be: u32 = if args.len() == 4 {
            let b = parse_int(&args[3])
                .unwrap_or_else(|| panic!("line {}: bad byte-enable '{}'", lineno, args[3]));
            if !(0..=0xF).contains(&b) {
                panic!("line {}: byte-enable {} out of range (0..15)", lineno, b);
            }
            b as u32
        } else {
            0xF
        };
        w |= be << 16;
        let v = parse_int(&args[2])
            .unwrap_or_else(|| panic!("line {}: bad immediate '{}'", lineno, args[2]));
        w |= enc_imm(v, 16, lineno);
        w
    };

    // ---------- slt / slte (opcode 12) ----------
    let slt = |slte: bool| -> u32 {
        need(3);
        let mut w = 12u32 << 28;
        w |= reg(0) << 24;
        w |= reg(1) << 20;
        if slte {
            w |= 1 << 18;
        }
        if is_reg(&args[2]) {
            w |= reg(2) << 14;
        } else {
            w |= 1 << 19;
            let v = parse_int(&args[2])
                .unwrap_or_else(|| panic!("line {}: bad operand '{}'", lineno, args[2]));
            w |= enc_imm(v, 18, lineno);
        }
        w
    };

    // ---------- compares (CMP op7 / CMPi op6) ----------
    // nzp given as (N,Z,P) where a bit value of 1 = STAY ON for that sign.
    let mut compare = |n: u32, z: u32, p: u32| -> u32 {
        need(3);
        let sr1 = reg(0);
        let mut w;
        let count_shift;
        if is_reg(&args[1]) {
            // CMP, opcode 7
            w = 7u32 << 28;
            w |= sr1 << 24;
            w |= reg(1) << 20;
            w |= n << 19;
            w |= z << 18;
            w |= p << 17;
            count_shift = 9;
        } else {
            // CMPi, opcode 6
            w = 6u32 << 28;
            w |= sr1 << 24;
            w |= n << 23;
            w |= z << 22;
            w |= p << 21;
            let v = parse_int(&args[1])
                .unwrap_or_else(|| panic!("line {}: bad compare immediate '{}'", lineno, args[1]));
            w |= enc_imm(v, 13, lineno);
            count_shift = 13;
        }
        // third operand: immediate count or forward label
        if let Some(c) = parse_int(&args[2]) {
            if !(0..=127).contains(&c) {
                panic!("line {}: skip count {} out of range (0..127)", lineno, c);
            }
            w |= (c as u32) << count_shift;
        } else {
            let label = args[2].clone();
            if let Some(&tgt) = labels.get(&label) {
                let c = tgt as i64 - next_index as i64 - 1;
                if !(0..=127).contains(&c) {
                    panic!(
                        "line {}: backward/oversized skip to '{}' ({} instr) — must be forward, 0..63",
                        lineno, label, c
                    );
                }
                w |= (c as u32) << count_shift;
            } else {
                pending.push(Pending {
                    pos: next_index,
                    label,
                    shift: count_shift,
                    lineno,
                });
            }
        }
        w
    };

    match mn.as_str() {
        "add" => alu18(0, false),
        "sub" => alu18(0, true),
        "and" => alu18(1, false),
        "or" => alu18(1, true),
        "xor" => alu19(2),
        "mul" => alu19(3),
        "div" => alu19(4),

        "lsl" => shift(false, false),
        "lsr" => shift(false, true),
        "asr" => shift(true, false),

        "skip_lt" => compare(0, 1, 1),
        "skip_le" => compare(0, 0, 1),
        "skip_eq" => compare(1, 0, 1),
        "skip_ne" => compare(0, 1, 0),
        "skip_gt" => compare(1, 1, 0),
        "skip_ge" => compare(1, 0, 0),

        "lw" => load(8),
        "lwg" => load(9),
        "sw" => store(10),
        "swg" => store(11),

        "slt" => slt(false),
        "slte" => slt(true),

        "barrier" => {
            let ctx = if args.is_empty() {
                prev_ctx.unwrap_or_else(|| {
                    panic!(
                        "line {}: first barrier must specify a context count (1..16)",
                        lineno
                    )
                })
            } else {
                need(1);
                let n = parse_int(&args[0])
                    .unwrap_or_else(|| panic!("line {}: bad context count", lineno));
                if !(1..=16).contains(&n) {
                    panic!("line {}: context count {} out of range (1..16)", lineno, n);
                }
                *prev_ctx = Some(n as u32);
                n as u32
            };
            (15u32 << 28) | ((ctx - 1) & 0xF)
        }

        other => panic!("line {}: unknown opcode '{}'", lineno, other),
    }
}

/* ===================== DRIVER ===================== */

fn assemble(src: &str) -> Vec<(u32, String)> {
    // clean: (lineno, text) with comments stripped & blanks removed
    let cleaned: Vec<(usize, String, String)> = src
        .lines()
        .enumerate()
        // (lineno, stripped code for parsing, original line for display)
        .map(|(i, l)| (i + 1, strip_comment(l).trim().to_string(), l.trim().to_string()))
        .filter(|(_, code, _)| !code.is_empty())
        .collect();

    let mut words: Vec<(u32, String)> = Vec::new();
    let mut labels: HashMap<String, usize> = HashMap::new();
    let mut pending: Vec<Pending> = Vec::new();
    let mut prev_ctx: Option<u32> = None;

    let mut ip = 0usize;
    while ip < cleaned.len() {
        let (lineno, text, raw) =
            (cleaned[ip].0, cleaned[ip].1.clone(), cleaned[ip].2.clone());

        // labels
        if text.ends_with(':') {
            let name = text[..text.len() - 1].trim().to_string();
            if name.is_empty() {
                panic!("line {}: empty label", lineno);
            }
            if labels.contains_key(&name) {
                panic!("line {}: duplicate label '{}'", lineno, name);
            }
            let here = words.len();
            labels.insert(name.clone(), here);
            // resolve any forward references now
            for p in pending.iter().filter(|p| p.label == name) {
                let c = here as i64 - p.pos as i64 - 1;
                if !(0..=127).contains(&c) {
                    panic!(
                        "line {}: skip distance to '{}' is {} (must be 0..127)",
                        p.lineno, name, c
                    );
                }
                words[p.pos].0 |= (c as u32) << p.shift;
            }
            pending.retain(|p| p.label != name);
            ip += 1;
            continue;
        }

        // tokenize
        let mut toks = text.split_whitespace();
        let mn = toks.next().unwrap();
        let rest: String = toks.collect::<Vec<_>>().join(" ");
        let args: Vec<String> = rest
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        // ignore a stray .org (not needed in this ISA)
        if mn.eq_ignore_ascii_case(".org") {
            ip += 1;
            continue;
        }

        // general data directive (.data / .data(K) / .word)
        // data directive
        if let Some(w) = try_data_word(&text, false) {
            words.extend(w.into_iter().map(|v| (v, raw.clone())));
            ip += 1;
            continue;
        }

        // cpu_store: emit header word, then consume the following data block
        if mn.eq_ignore_ascii_case("cpu_store") {
            if args.len() != 2 {
                panic!("line {}: cpu_store expects: cpu_store addr, N", lineno);
            }
            let addr = parse_int(&args[0])
                .unwrap_or_else(|| panic!("line {}: bad cpu_store address", lineno));
            if !(0..=0xFFFF).contains(&addr) {
                panic!("line {}: cpu_store address {} out of range (0..65535)", lineno, addr);
            }
            let n = parse_int(&args[1])
                .unwrap_or_else(|| panic!("line {}: bad cpu_store word count", lineno));
            if !(1..=4096).contains(&n) {
                panic!("line {}: cpu_store count {} out of range (1..4096)", lineno, n);
            }
            words.push(((13u32 << 28) | ((n as u32) << 16) | (addr as u32 & 0xFFFF), raw));
            ip += 1;
            continue;
        }

        // regular instruction
        let next_index = words.len();
        let w = encode_instruction(
            mn, &args, next_index, &mut pending, &labels, &mut prev_ctx, lineno,
        );
        words.push((w, raw));
        ip += 1;
    }

    if !pending.is_empty() {
        let names: Vec<String> = pending.iter().map(|p| p.label.clone()).collect();
        panic!("unresolved forward label(s): {}", names.join(", "));
    }

    words
}

/* ===================== CLI ===================== */

fn main() -> io::Result<()> {
    let argv: Vec<String> = env::args().collect();
    if argv.len() < 2 || argv.len() > 3 {
        eprintln!("Usage: {} <input.asm> [output.hex|output.bin]", argv[0]);
        eprintln!("  .bin output -> little-endian u32 binary");
        eprintln!("  any other extension -> $readmemh-style hex (one word/line)");
        std::process::exit(1);
    }

    let input_path = &argv[1];
    let output_path = argv.get(2);

    let src = fs::read_to_string(input_path)
        .unwrap_or_else(|e| panic!("failed to read '{}': {}", input_path, e));

    let words = assemble(&src);

    println!("Assembled {} words ({} bytes)\n", words.len(), words.len() * 4);
    println!("===== HEX =====");
    for w in words.iter() {
        println!("Xil_Out32(B+16, 0x{:08X});   //{}", w.0, w.1);
    }

    if let Some(out) = output_path {
        let path = Path::new(out);
        let mut file = fs::File::create(path)
            .unwrap_or_else(|e| panic!("failed to create '{}': {}", out, e));
        let mut my_vec = vec![];
        for i in &words {
            my_vec.push(i.0);
        }
        if out.to_lowercase().ends_with(".bin") {
            for w in &my_vec {
                file.write_all(&w.to_le_bytes())?;
            }
        } else {
            for w in &my_vec {
                writeln!(file, "{:08X}", w)?;
            }
        }
        println!("\nWrote {} words to '{}'", words.len(), out);
    }

    Ok(())
}
