#include <stdio.h>
#include <stdint.h>

#define CLK_WIZ_BASE  0x44a10000
#define GPU_WIZ_BASE  0x44a00000
#define B 0x44a00000
#define CLK_SRR       0x000   // Software Reset Register
#define CLK_SR        0x004   // Status Register (bit0 = locked)
#define CLK_REG0      0x200   // DIVCLK_DIVIDE [7:0], CLKFBOUT_MULT [15:8], CLKFBOUT_FRAC [25:16]
#define CLK_REG1      0x204   // CLKFBOUT_PHASE
#define CLK_REG2      0x208   // CLKOUT0_DIVIDE [7:0], CLKOUT0_FRAC [17:8]
#define CLK_REG3      0x20C   // CLKOUT0_PHASE
#define CLK_REG4      0x210   // CLKOUT0_DUTY
#define CLK_LOAD      0x25C   // bit[0]=LOAD, bit[1]=SADDR
void Xil_Out32(uint32_t whoCares, uint32_t val) {
    if(val >> 16 == 0x6169) {
        // printf("INST: ");
    }
    printf("%08X\n", val);
}
uint32_t Xil_In32(uint32_t whoCares) {
    return 0;
}
void reconfig_clk(void) {
    // Wait until the clk_wiz is locked before touching it
    while (!(Xil_In32(CLK_WIZ_BASE + CLK_SR) & 0x1));

    Xil_Out32(CLK_WIZ_BASE + CLK_REG0, (0u << 16) | (6u << 8) | 1u); // DIVCLK=1, MULT=6
    Xil_Out32(CLK_WIZ_BASE + CLK_REG1, 0u);                          // FBOUT phase
    Xil_Out32(CLK_WIZ_BASE + CLK_REG2, (0u << 8) | 18u);  // CLKOUT0_DIVIDE=8
    Xil_Out32(CLK_WIZ_BASE + CLK_REG3, 0u);                          // CLKOUT0 phase
    Xil_Out32(CLK_WIZ_BASE + CLK_REG4, 0x0000C350u);                 // 50% duty

    Xil_Out32(CLK_WIZ_BASE + CLK_LOAD, 0x3u);                        // SADDR=1, LOAD=1

    while (  Xil_In32(CLK_WIZ_BASE + CLK_SR) & 0x1 );  // wait for unlock (reconfig started)
    while (!(Xil_In32(CLK_WIZ_BASE + CLK_SR) & 0x1));  // wait for relock (reconfig done)
}





#define SCREEN_W 640
#define SCREEN_H 480
#define TILE_W   20      /* 20 lanes    -> x */
#define TILE_H   16      /* 16 contexts -> y */

/* Screen-affine interpolants carried per vertex and per edge endpoint. */

typedef struct { uint32_t x, y, z, w, r, g, b; } Vertex;   /* input, clip space */



static const uint8_t linear_to_srgb_lut[512] = {
      0,   6,  13,  18,  22,  25,  28,  31,  34,  36,  38,  40,  42,  44,  46,  48,
     50,  51,  53,  54,  56,  57,  59,  60,  61,  62,  64,  65,  66,  67,  69,  70,
     71,  72,  73,  74,  75,  76,  77,  78,  79,  80,  81,  82,  83,  84,  85,  86,
     86,  87,  88,  89,  90,  91,  91,  92,  93,  94,  95,  95,  96,  97,  98,  98,
     99, 100, 101, 101, 102, 103, 103, 104, 105, 106, 106, 107, 108, 108, 109, 110,
    110, 111, 111, 112, 113, 113, 114, 115, 115, 116, 116, 117, 118, 118, 119, 119,
    120, 121, 121, 122, 122, 123, 123, 124, 125, 125, 126, 126, 127, 127, 128, 128,
    129, 129, 130, 130, 131, 132, 132, 133, 133, 134, 134, 135, 135, 136, 136, 137,
    137, 138, 138, 139, 139, 140, 140, 140, 141, 141, 142, 142, 143, 143, 144, 144,
    145, 145, 146, 146, 147, 147, 147, 148, 148, 149, 149, 150, 150, 151, 151, 151,
    152, 152, 153, 153, 154, 154, 154, 155, 155, 156, 156, 156, 157, 157, 158, 158,
    159, 159, 159, 160, 160, 161, 161, 161, 162, 162, 163, 163, 163, 164, 164, 165,
    165, 165, 166, 166, 166, 167, 167, 168, 168, 168, 169, 169, 169, 170, 170, 171,
    171, 171, 172, 172, 172, 173, 173, 174, 174, 174, 175, 175, 175, 176, 176, 176,
    177, 177, 177, 178, 178, 179, 179, 179, 180, 180, 180, 181, 181, 181, 182, 182,
    182, 183, 183, 183, 184, 184, 184, 185, 185, 185, 186, 186, 186, 187, 187, 187,
    188, 188, 188, 189, 189, 189, 190, 190, 190, 191, 191, 191, 192, 192, 192, 193,
    193, 193, 193, 194, 194, 194, 195, 195, 195, 196, 196, 196, 197, 197, 197, 198,
    198, 198, 198, 199, 199, 199, 200, 200, 200, 201, 201, 201, 201, 202, 202, 202,
    203, 203, 203, 204, 204, 204, 204, 205, 205, 205, 206, 206, 206, 206, 207, 207,
    207, 208, 208, 208, 208, 209, 209, 209, 210, 210, 210, 210, 211, 211, 211, 212,
    212, 212, 212, 213, 213, 213, 214, 214, 214, 214, 215, 215, 215, 215, 216, 216,
    216, 217, 217, 217, 217, 218, 218, 218, 218, 219, 219, 219, 220, 220, 220, 220,
    221, 221, 221, 221, 222, 222, 222, 222, 223, 223, 223, 224, 224, 224, 224, 225,
    225, 225, 225, 226, 226, 226, 226, 227, 227, 227, 227, 228, 228, 228, 228, 229,
    229, 229, 229, 230, 230, 230, 230, 231, 231, 231, 231, 232, 232, 232, 232, 233,
    233, 233, 233, 234, 234, 234, 234, 235, 235, 235, 235, 236, 236, 236, 236, 237,
    237, 237, 237, 238, 238, 238, 238, 239, 239, 239, 239, 239, 240, 240, 240, 240,
    241, 241, 241, 241, 242, 242, 242, 242, 243, 243, 243, 243, 243, 244, 244, 244,
    244, 245, 245, 245, 245, 246, 246, 246, 246, 246, 247, 247, 247, 247, 248, 248,
    248, 248, 249, 249, 249, 249, 249, 250, 250, 250, 250, 251, 251, 251, 251, 251,
    252, 252, 252, 252, 253, 253, 253, 253, 253, 254, 254, 254, 254, 255, 255, 255,
};
/* ---- helpers -------------------------------------------------------------- */

void setupColors(){
	Xil_Out32(B+16, 0xD2031770);   //cpu_store 6000, 515
	for(int i = 0; i < 512; i++){
		Xil_Out32(B+16, linear_to_srgb_lut[i] << 24 | linear_to_srgb_lut[i] << 16 | linear_to_srgb_lut[i] << 8 | linear_to_srgb_lut[i]);
	}
	Xil_Out32(B+16, 0xFFFFFFFF);
	Xil_Out32(B+16, 0xFFFFFFFF);
	Xil_Out32(B+16, 0xFFFFFFFF);
}
void clearBuf(uint32_t color, uint32_t buffer_index) {
//	while (Xil_In32(B)>0){}
	Xil_Out32(B+16, 0xF000000F);   //barrier 16
	Xil_Out32(B+16, 0xD0011FFF);   //cpu_store 8191, 1
	Xil_Out32(B+16, color);   //color
	Xil_Out32(B+16, 0xF000000F);   //barrier 16
	Xil_Out32(B+16, 0x10080000);   //and r0, r0, 0
	Xil_Out32(B+16, 0x81081FFF);   //lw r1, r0, 8191
	Xil_Out32(B+16, 0x00080280);   //add r0, r0, 640
	Xil_Out32(B+16, 0x300801E0);   //mul r0, r0, 480
	Xil_Out32(B+16, 0x30080000 + buffer_index);   //mul r0, r0, 0 #ADD BUFFER INDEX - r0 for first screen buf, r1 for second, r2, for z-buf
//	Xil_Out32(B+16, 0x0003C000);   //add r0, r0, r15 #after this it's just the loop for 960 times
	Xil_Out32(B+16, 0x32F80050);   //mul r2, r15, 80
	Xil_Out32(B+16, 0x42280050);   //div r2, r2, 80
	Xil_Out32(B+16, 0x00008000);   //add r0, r0, r2
	for(int i = 0; i < 960; i++){
		Xil_Out32(B+16, 0xB01F0000);   //swg r1, r0, 0
		Xil_Out32(B+16, 0x00080140);   //add r0, r0, 320
		while (Xil_In32(B)>800){}
	}
}

static void swap(Vertex ** a, Vertex **b) {
	Vertex * c;
	c = *a;
	*a = *b;
	*b = c;
}
/* Sort in place so a is topmost, c is bottommost (smallest y first). */
static void sort_by_y(Vertex **a, Vertex **b, Vertex **c)
{
	if ((int)((*a)->y) > (int)((*b)->y)) {swap(a, b);}
    if ((int)((*a)->y) > (int)((*c)->y)) {swap(a, c);}
    if ((int)((*b)->y) > (int)((*c)->y)) {swap(b, c);}
}

void render_straight_tri(Vertex * a, Vertex * b, Vertex * c, uint32_t is_second_buf){
	Vertex * d = a;
	Vertex * e = b;
	if((int)(d->y) > (int)(e->y)) {
		swap(&d, &e);
	}
	while (Xil_In32(B)>600){}
	Xil_Out32(B+16, 0xD01C1680);   //cpu_store 5760, 28
	for(int i = 0; i < 7; i++){
		Xil_Out32(B+16, ((uint32_t *)(d))[i]);
	}
	for(int i = 0; i < 7; i++){
		Xil_Out32(B+16, ((uint32_t *)(e))[i]);
	}
	d = a;
	e = c;
	if((int)(d->y) > (int)(e->y)) {
		swap(&d, &e);
	}
	for(int i = 0; i < 7; i++){
		Xil_Out32(B+16, ((uint32_t *)(d))[i]);
	}
	for(int i = 0; i < 7; i++){
		Xil_Out32(B+16, ((uint32_t *)(e))[i]);
	}
	Xil_Out32(B+16, 0xF000000B);   //barrier 12
	Xil_Out32(B+16, 0x01F80000);   //add r1, r15, 0
	Xil_Out32(B+16, 0x16680000);   //and r6, r6, 0
	for(int i = 0; i < 2; i++) {


		Xil_Out32(B+16, 0x82681681);   //lw r2, r6, 5761
		Xil_Out32(B+16, 0x83681688);   //lw r3, r6, 5768
		Xil_Out32(B+16, 0x03348000);   //sub r3, r3, r2

		Xil_Out32(B+16, 0x50110000);   //lsl r0, r1, 4
		Xil_Out32(B+16, 0x70280200);   //skip_ge r0, r2, 1
		Xil_Out32(B+16, 0x00280000);   //add r0, r2, 0
		Xil_Out32(B+16, 0x00048000);   //sub r0, r0, r2
		Xil_Out32(B+16, 0x50020000);   //lsl r0, r0, 16
		Xil_Out32(B+16, 0x40018000);   //div r0, r0, r3 //ratio

		Xil_Out32(B+16, 0x12280000);   //and r2, r2, 0
		Xil_Out32(B+16, 0x02280001);   //add r2, r2, 1
		Xil_Out32(B+16, 0x52220000);   //lsl r2, r2, 16
		Xil_Out32(B+16, 0x02240000);   //sub r2, r2, r0 //1-ratio
		Xil_Out32(B+16, 0x83681680);   //lw r3, r6, 5760
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x84681687);   //lw r4, r6, 5767
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F0000);   //sw r3, r1, 0
		Xil_Out32(B+16, 0x83681682);   //lw r3, r6, 5762
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x84681689);   //lw r4, r6, 5769
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F01E0);   //sw r3, r1, 480
		Xil_Out32(B+16, 0x83681683);   //lw r3, r6, 5763
		Xil_Out32(B+16, 0x55258000);   //lsr r5, r2, 8
		Xil_Out32(B+16, 0x33328000);   //mul r3, r3, r5
		Xil_Out32(B+16, 0x8468168A);   //lw r4, r6, 5770
		Xil_Out32(B+16, 0x55058000);   //lsr r5, r0, 8
		Xil_Out32(B+16, 0x34428000);   //mul r4, r4, r5
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53358000);   //lsr r3, r3, 8
		Xil_Out32(B+16, 0xA13F03C0);   //sw r3, r1, 960
		Xil_Out32(B+16, 0x83681684);   //lw r3, r6, 5764
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x8468168B);   //lw r4, r6, 5771
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F05A0);   //sw r3, r1, 1440
		Xil_Out32(B+16, 0x83681685);   //lw r3, r6, 5765
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x8468168C);   //lw r4, r6, 5772
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F0780);   //sw r3, r1, 1920
		Xil_Out32(B+16, 0x83681686);   //lw r3, r6, 5766
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x8468168D);   //lw r4, r6, 5773
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F0960);   //sw r3, r1, 2400
		Xil_Out32(B+16, 0x011800F0);   //add r1, r1, 240
	}
	Xil_Out32(B+16, 0x01F80000);   //add r1, r15, 0
	Xil_Out32(B+16, 0x16680000);   //and r6, r6, 0
	for(int i = 0; i < 2; i++) {


		Xil_Out32(B+16, 0x8268168F);   //lw r2, r6, 5775
		Xil_Out32(B+16, 0x83681696);   //lw r3, r6, 5782
		Xil_Out32(B+16, 0x03348000);   //sub r3, r3, r2

		Xil_Out32(B+16, 0x50110000);   //lsl r0, r1, 4
		Xil_Out32(B+16, 0x70280200);   //skip_ge r0, r2, 1
		Xil_Out32(B+16, 0x00280000);   //add r0, r2, 0
		Xil_Out32(B+16, 0x00048000);   //sub r0, r0, r2
		Xil_Out32(B+16, 0x50020000);   //lsl r0, r0, 16
		Xil_Out32(B+16, 0x40018000);   //div r0, r0, r3 //ratio

		Xil_Out32(B+16, 0x12280000);   //and r2, r2, 0
		Xil_Out32(B+16, 0x02280001);   //add r2, r2, 1
		Xil_Out32(B+16, 0x52220000);   //lsl r2, r2, 16
		Xil_Out32(B+16, 0x02240000);   //sub r2, r2, r0 //1-ratio
		Xil_Out32(B+16, 0x8368168E);   //lw r3, r6, 5774
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x84681695);   //lw r4, r6, 5781
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F0B40);   //sw r3, r1, 2880
		Xil_Out32(B+16, 0x83681690);   //lw r3, r6, 5776
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x84681697);   //lw r4, r6, 5783
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F0D20);   //sw r3, r1, 3360
		Xil_Out32(B+16, 0x83681691);   //lw r3, r6, 5777
		Xil_Out32(B+16, 0x55258000);   //lsr r5, r2, 8
		Xil_Out32(B+16, 0x33328000);   //mul r3, r3, r5
		Xil_Out32(B+16, 0x84681698);   //lw r4, r6, 5784
		Xil_Out32(B+16, 0x55058000);   //lsr r5, r0, 8
		Xil_Out32(B+16, 0x34428000);   //mul r4, r4, r5
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53358000);   //lsr r3, r3, 8
		Xil_Out32(B+16, 0xA13F0F00);   //sw r3, r1, 3840
		Xil_Out32(B+16, 0x83681692);   //lw r3, r6, 5778
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x84681699);   //lw r4, r6, 5785
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F10E0);   //sw r3, r1, 4320
		Xil_Out32(B+16, 0x83681693);   //lw r3, r6, 5779
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x8468169A);   //lw r4, r6, 5786
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F12C0);   //sw r3, r1, 4800
		Xil_Out32(B+16, 0x83681694);   //lw r3, r6, 5780
		Xil_Out32(B+16, 0x33310000);   //mul r3, r3, r2
		Xil_Out32(B+16, 0x8468169B);   //lw r4, r6, 5787
		Xil_Out32(B+16, 0x34400000);   //mul r4, r4, r0
		Xil_Out32(B+16, 0x03310000);   //add r3, r3, r4
		Xil_Out32(B+16, 0x53360000);   //lsr r3, r3, 16
		Xil_Out32(B+16, 0xA13F14A0);   //sw r3, r1, 5280
		Xil_Out32(B+16, 0x011800F0);   //add r1, r1, 240
	}
	Xil_Out32(B+16, 0xF000000F);   //barrier 16
	int min_x = ((int)(a->x) < (int)(b->x)) ? a->x : b->x;
	int max_x = ((int)(a->x) > (int)(c->x)) ? a->x : c->x;
	int min_y = ((int)(a->y) < (int)(b->y)) ? a->y : b->y;
	int max_y = ((int)(a->y) >= (int)(b->y)) ? a->y : b->y;
	for(int i = ((min_y > 0) ? min_y : 0) >> 4; i < ((max_y < (SCREEN_H << 4)) ? max_y >> 4 : SCREEN_H) + TILE_H - 1; i += TILE_H){
		Xil_Out32(B+16, 0x41F80014);   //div r1, r15, 20
		Xil_Out32(B+16, 0x32180014);   //mul r2, r1, 20
		Xil_Out32(B+16, 0x00F48000);   //sub r0, r15, r2 #my_x
		Xil_Out32(B+16, 0x00080000 + ((min_x > 0) ? (min_x >> 4 ): 0));   //add r0, r0, 0 #PLUS min_x
		Xil_Out32(B+16, 0x01180000 + i);   //add r1, r1, 0 #PLUS y_cur #my_y
		Xil_Out32(B+16, 0x82180000);   //lw r2, r1, 0
		Xil_Out32(B+16, 0x83180B40);   //lw r3, r1, 2880
		Xil_Out32(B+16, 0x0D380000);   //add r13, r3, 0
		Xil_Out32(B+16, 0x03348000);   //sub r3, r3, r2 #span
		Xil_Out32(B+16, 0x1EE80000);   //and r14, r14, 0
		Xil_Out32(B+16, 0x0EE88000);   //add r14, r14, 0x8000
		Xil_Out32(B+16, 0x5EE20000);   //lsl r14, r14, 16
		Xil_Out32(B+16, 0x43E18000);   //div r3, r14, r3
		for(int j = ((min_x > 0) ? min_x : 0) >> 4; j < (((max_x < (SCREEN_W << 4)) ? max_x : (SCREEN_W << 4)) >> 4) + TILE_W - 1; j += TILE_W){
			Xil_Out32(B+16, 0x5C010000);   //lsl r12, r0, 4 //I don't have to check my_x against 0 because 0 + tid%20 is the min
			Xil_Out32(B+16, 0x608A6280);   //skip_ge r0, 640, skip_pixel //if guard on my_x >= 640
			Xil_Out32(B+16, 0x7CD8A400);   //skip_ge r12, r13, skip_pixel //if guard on my_x >= right_x
			Xil_Out32(B+16, 0x7C26A200);   //skip_lt r12, r2, skip_pixel //if guard on my_x < left_x
			Xil_Out32(B+16, 0x618A0000 + ((max_y >> 4 > 480) ? 480 : max_y >> 4));   //skip_ge r1, 0, skip_pixel //if guard on my_y >= min(480, y_bottom) #ADD min(480, y_bottom)
			Xil_Out32(B+16, 0x6169E000 + ((min_y < 0) ? 0 : min_y >> 4));   //skip_lt r1, 0, skip_pixel //if guard on my_y >= max(0, y_top) #ADD max(0, y_top)
			Xil_Out32(B+16, 0x56010000);   //lsl r6, r0, 4
			Xil_Out32(B+16, 0x06648000);   //sub r6, r6, r2 #dx
			Xil_Out32(B+16, 0x36618000);   //mul r6, r6, r3 #ratio
			Xil_Out32(B+16, 0x56658000);   //lsr r6, r6, 8
			Xil_Out32(B+16, 0x56600000);   //lsl r6, r6, 1
			Xil_Out32(B+16, 0x56658000);   //lsr r6, r6, 8
			Xil_Out32(B+16, 0x17380000);   //and r7, r3, 0
			Xil_Out32(B+16, 0x07780001);   //add r7, r7, 1
			Xil_Out32(B+16, 0x57720000);   //lsl r7, r7, 16
			Xil_Out32(B+16, 0x07758000);   //sub r7, r7, r6 #1-ratio
			Xil_Out32(B+16, 0x841801E0);   //lw r4, r1, 480 #l_z
			Xil_Out32(B+16, 0x85180D20);   //lw r5, r1, 3360 #r_z
			Xil_Out32(B+16, 0x34438000);   //mul r4, r4, r7
			Xil_Out32(B+16, 0x35530000);   //mul r5, r5, r6
			Xil_Out32(B+16, 0x04414000);   //add r4, r4, r5 #pix_z
			Xil_Out32(B+16, 0x18880000);   //and r8, r8, 0
			Xil_Out32(B+16, 0x08880500);   //add r8, r8, 1280
			Xil_Out32(B+16, 0x388801E0);   //mul r8, r8, 480
			Xil_Out32(B+16, 0x08800000);   //add r8, r8, r0
			Xil_Out32(B+16, 0x39180280);   //mul r9, r1, 640
			Xil_Out32(B+16, 0x08824000);   //add r8, r8, r9
			Xil_Out32(B+16, 0x99880000);   //lwg r9, r8, 0 #z_cur
			Xil_Out32(B+16, 0x74987000);   //skip_ge r4, r9, skip_pixel
			Xil_Out32(B+16, 0xB84F0000);   //swg r4, r8, 0 #z_buf = z_cur
			Xil_Out32(B+16, 0x841803C0);   //lw r4, r1, 960 #l_w
			Xil_Out32(B+16, 0x59658000);   //lsr r9, r6, 8
			Xil_Out32(B+16, 0x5A758000);   //lsr r10, r7, 8
			Xil_Out32(B+16, 0x85180F00);   //lw r5, r1, 3840 #r_w
			Xil_Out32(B+16, 0x34450000);   //mul r4, r4, r10
			Xil_Out32(B+16, 0x35548000);   //mul r5, r5, r9
			Xil_Out32(B+16, 0x04414000);   //add r4, r4, r5 #1/pix_w
			Xil_Out32(B+16, 0x54458000);   //lsr r4, r4, 8
			Xil_Out32(B+16, 0x19980000);   //and r9, r9, 0
			Xil_Out32(B+16, 0x09988000);   //add r9, r9, 0x8000
			Xil_Out32(B+16, 0x59920000);   //lsl r9, r9, 16
			Xil_Out32(B+16, 0x44920000);   //div r4, r9, r4 #pix_w
			Xil_Out32(B+16, 0x1CC80000);   //and r12, r12, 0
			Xil_Out32(B+16, 0x3B180280);   //mul r11, r1, 640
			Xil_Out32(B+16, 0x0BB00000);   //add r11, r11, r0
			if(is_second_buf){
				Xil_Out32(B+16, 0x0CC80280);   //add r12, r12, 640
				Xil_Out32(B+16, 0x3CC801E0);   //mul r12, r12, 480
				Xil_Out32(B+16, 0x0CC80000);   //add r12, r12, 0
			} else {
				Xil_Out32(B+16, 0x0CC80000);   //add r12, r12, 0
				Xil_Out32(B+16, 0x0CC80000);   //add r12, r12, 0
				Xil_Out32(B+16, 0x0CC80000);   //add r12, r12, 0
			}
			Xil_Out32(B+16, 0x0CB30000);   //add r12, r11, r12
			Xil_Out32(B+16, 0x8A1805A0);   //lw r10, r1, 1440 #r_l
			Xil_Out32(B+16, 0x3AA38000);   //mul r10, r10, r7
			Xil_Out32(B+16, 0x8B1810E0);   //lw r11, r1, 4320 #r_r
			Xil_Out32(B+16, 0x3BB30000);   //mul r11, r11, r6
			Xil_Out32(B+16, 0x0AA2C000);   //add r10, r10, r11
			Xil_Out32(B+16, 0x5AA60000);   //lsr r10, r10, 16
			Xil_Out32(B+16, 0x3AA20000);   //mul r10, r10, r4
			Xil_Out32(B+16, 0x5AA58000);   //lsr r10, r10, 8
			Xil_Out32(B+16, 0x5AA00000);   //lsl r10, r10, 1
			Xil_Out32(B+16, 0x5AA58000);   //lsr r10, r10, 8
			Xil_Out32(B+16, 0x8AA81770);   //lw r10, r10, 6000
			Xil_Out32(B+16, 0xBCA80000);   //swg r10, r12, 0, 8 #STORE THE TOP BYTE
			Xil_Out32(B+16, 0x8A180780);   //lw r10, r1, 1920 #g_l
			Xil_Out32(B+16, 0x3AA38000);   //mul r10, r10, r7
			Xil_Out32(B+16, 0x8B1812C0);   //lw r11, r1, 4800 #g_r
			Xil_Out32(B+16, 0x3BB30000);   //mul r11, r11, r6
			Xil_Out32(B+16, 0x0AA2C000);   //add r10, r10, r11
			Xil_Out32(B+16, 0x5AA60000);   //lsr r10, r10, 16
			Xil_Out32(B+16, 0x3AA20000);   //mul r10, r10, r4
			Xil_Out32(B+16, 0x5AA58000);   //lsr r10, r10, 8
			Xil_Out32(B+16, 0x5AA00000);   //lsl r10, r10, 1
			Xil_Out32(B+16, 0x5AA58000);   //lsr r10, r10, 8
			Xil_Out32(B+16, 0x8AA81770);   //lw r10, r10, 6000
			Xil_Out32(B+16, 0xBCA40000);   //swg r10, r12, 0, 4 #STORE THE THIRD BYTE
			Xil_Out32(B+16, 0x8A180960);   //lw r10, r1, 2400 #b_l
			Xil_Out32(B+16, 0x3AA38000);   //mul r10, r10, r7
			Xil_Out32(B+16, 0x8B1814A0);   //lw r11, r1, 5280 #b_r
			Xil_Out32(B+16, 0x3BB30000);   //mul r11, r11, r6
			Xil_Out32(B+16, 0x0AA2C000);   //add r10, r10, r11
			Xil_Out32(B+16, 0x5AA60000);   //lsr r10, r10, 16
			Xil_Out32(B+16, 0x3AA20000);   //mul r10, r10, r4
			Xil_Out32(B+16, 0x5AA58000);   //lsr r10, r10, 8
			Xil_Out32(B+16, 0x5AA00000);   //lsl r10, r10, 1
			Xil_Out32(B+16, 0x5AA58000);   //lsr r10, r10, 8
			Xil_Out32(B+16, 0x8AA81770);   //lw r10, r10, 6000
			Xil_Out32(B+16, 0xBCA20000);   //swg r10, r12, 0, 2 #STORE THE SECOND BYTE
			Xil_Out32(B+16, 0x00080014);   //add r0, r0, 20
			while (Xil_In32(B)>650){}
		}
	}

}


void render_tri(Vertex * a, Vertex * b, Vertex * c, uint32_t is_second_buf)
{

    /* 3. Sort vertices top -> bottom. */

    sort_by_y(&a, &b, &c);

    /* 4. Integer scanline bounds. A scanline y is covered when its center
     *    (y + 0.5) lies in [top.y, bot.y); the bottom half begins at y_mid. */

    int y_top = (int)(a->y);
    int y_bot = (int)(c->y);   /* exclusive */


    if (y_bot < 0)   return;           /* fully clipped vertically */
    if (y_top >= SCREEN_H << 4)   return;           /* fully clipped vertically */

    //I'm going to need a conditional on whether to prevent rendering of the top or bottom half of the triangle
    //This will depend on y_mid


    /* 5. Orientation. With vertices y-sorted, the sign of the sorted signed
     *    area tells which side the long (top->bottom) edge is on -- no divide. */

    uint32_t dy1 = b->y - a->y;              /* raw Q12.4 */
    uint32_t dy2 = c->y - a->y;
    if (dy2 < 0x10) return;                  /* degenerate: whole tri < 1 px tall */
    uint32_t ratio  = ((uint32_t)dy1 << 16) / dy2;   /* exact Q0.16 */
    uint32_t ratio2 = 0x10000 - ratio;
    Vertex d;
    for (int i = 0; i < 7; i++) {
        uint32_t ai = ((uint32_t *)a)[i];
        uint32_t ci = ((uint32_t *)c)[i];
        ((uint32_t *)&d)[i] = (i == 3)
            ? (ai >> 8) * (ratio2 >> 8) + (ci >> 8) * (ratio >> 8)   /* q: prescale */
            : (ai * ratio2 + ci * ratio) >> 16;                      /* full precision */
    }
    d.y = b->y;
    Vertex *pd = &d;
    if ((int)(b->x) > (int)(d.x))  { Vertex *t = b; b = pd; pd = t; }
    if((int)(b->y) >= 0 && b->y - a->y >= 0x10) {
    	render_straight_tri(a, b, pd, is_second_buf);
    }
    if((int)(b->y) < (SCREEN_H << 4) && c->y - b->y >= 0x10) {
    	render_straight_tri(c, b, pd, is_second_buf);
    }

}


typedef int32_t q16;

#define Q16(x)      ((q16)((x) * 65536.0))          /* compile-time only     */
#define QINT(x)     ((q16)((x) << 16))              /* integer -> Q16.16     */
#define DEG_TO_BAM(d) ((uint16_t)(((int32_t)(d) * 65536L) / 360L))

static q16 qmul(q16 a, q16 b) {
    uint32_t neg = (uint32_t)(a ^ b) >> 31;
    uint32_t ua = (a < 0) ? (uint32_t)(-a) : (uint32_t)a;
    uint32_t ub = (b < 0) ? (uint32_t)(-b) : (uint32_t)b;
    uint32_t ah = ua >> 16, al = ua & 0xFFFFu;
    uint32_t bh = ub >> 16, bl = ub & 0xFFFFu;
    /* (a*b) >> 16 = (ah*bh << 16) + ah*bl + al*bh + (al*bl >> 16) */
    uint32_t r = (ah * bh) << 16;
    r += ah * bl;
    r += al * bh;
    r += (al * bl) >> 16;
    return neg ? -(q16)r : (q16)r;
}


static uint32_t udiv_frac(uint32_t a, uint32_t b, int bits) {
    uint32_t q = a / b;
    uint32_t r = a - q * b;
    while (bits--) {
        q <<= 1;
        r <<= 1;                       /* r < b < 2^31, so this can't wrap */
        if (r >= b) { r -= b; q |= 1; }
    }
    return q;
}

static q16 qdiv(q16 a, q16 b) {
    if (b == 0) return (a >= 0) ? 0x7FFFFFFF : (q16)0x80000000;
    uint32_t neg = (uint32_t)(a ^ b) >> 31;
    uint32_t ua = (a < 0) ? (uint32_t)(-a) : (uint32_t)a;
    uint32_t ub = (b < 0) ? (uint32_t)(-b) : (uint32_t)b;
    uint32_t r = udiv_frac(ua, ub, 16);
    return neg ? -(q16)r : (q16)r;
}

typedef struct { q16 x, y, z;    } Vec3;
typedef struct { q16 x, y, z, w; } Vec4;
typedef struct { q16 m[4][4];    } Mat4;
/* ---- Integer square root (input Q32.32 in a uint64, output Q16.16) --------
 * sqrt(v * 2^32) = sqrt(v) * 2^16, so feeding it a Q32.32 raw value directly
 * yields a Q16.16 result. Perfect fit for vector lengths (see v3_norm).
 * -------------------------------------------------------------------------- */
static uint32_t isqrt32(uint32_t v) {
    uint32_t rem = 0, root = 0;
    for (int i = 0; i < 16; i++) {
        root <<= 1;
        rem = (rem << 2) | (v >> 30);
        v <<= 2;
        if (root < rem) { rem -= root + 1; root += 2; }
    }
    return root >> 1;
}

static const q16 sine_lut[257] = {
         0,    804,   1608,   2412,   3216,   4019,   4821,   5623,
      6424,   7224,   8022,   8820,   9616,  10411,  11204,  11996,
     12785,  13573,  14359,  15143,  15924,  16703,  17479,  18253,
     19024,  19792,  20557,  21320,  22078,  22834,  23586,  24335,
     25080,  25821,  26558,  27291,  28020,  28745,  29466,  30182,
     30893,  31600,  32303,  33000,  33692,  34380,  35062,  35738,
     36410,  37076,  37736,  38391,  39040,  39683,  40320,  40951,
     41576,  42194,  42806,  43412,  44011,  44604,  45190,  45769,
     46341,  46906,  47464,  48015,  48559,  49095,  49624,  50146,
     50660,  51166,  51665,  52156,  52639,  53114,  53581,  54040,
     54491,  54934,  55368,  55794,  56212,  56621,  57022,  57414,
     57798,  58172,  58538,  58896,  59244,  59583,  59914,  60235,
     60547,  60851,  61145,  61429,  61705,  61971,  62228,  62476,
     62714,  62943,  63162,  63372,  63572,  63763,  63944,  64115,
     64277,  64429,  64571,  64704,  64827,  64940,  65043,  65137,
     65220,  65294,  65358,  65413,  65457,  65492,  65516,  65531,
     65536,  65531,  65516,  65492,  65457,  65413,  65358,  65294,
     65220,  65137,  65043,  64940,  64827,  64704,  64571,  64429,
     64277,  64115,  63944,  63763,  63572,  63372,  63162,  62943,
     62714,  62476,  62228,  61971,  61705,  61429,  61145,  60851,
     60547,  60235,  59914,  59583,  59244,  58896,  58538,  58172,
     57798,  57414,  57022,  56621,  56212,  55794,  55368,  54934,
     54491,  54040,  53581,  53114,  52639,  52156,  51665,  51166,
     50660,  50146,  49624,  49095,  48559,  48015,  47464,  46906,
     46341,  45769,  45190,  44604,  44011,  43412,  42806,  42194,
     41576,  40951,  40320,  39683,  39040,  38391,  37736,  37076,
     36410,  35738,  35062,  34380,  33692,  33000,  32303,  31600,
     30893,  30182,  29466,  28745,  28020,  27291,  26558,  25821,
     25080,  24335,  23586,  22834,  22078,  21320,  20557,  19792,
     19024,  18253,  17479,  16703,  15924,  15143,  14359,  13573,
     12785,  11996,  11204,  10411,   9616,   8820,   8022,   7224,
      6424,   5623,   4821,   4019,   3216,   2412,   1608,    804, 0
};


static q16 qsin(uint16_t a) {
    uint32_t idx  = a >> 7;                    /* 0..1023        */
    uint32_t should_invert = idx & 0x100;
    idx &= 0xFF;
    int32_t y0 = sine_lut[idx];
    int32_t y1 = sine_lut[idx + 1];
    if(should_invert != 0){
    	y0 *= -1;
    	y1 *= -1;
    }
    uint32_t ratio = a & 0x7F;
    uint32_t ratio2 = 0x80 - ratio;
    int32_t value = ratio2 * y0 + ratio * y1;
    return (value >> 7);
}

static q16 qcos(uint16_t a) { return qsin((uint16_t)(a + 16384u)); }

static Vec3 v3_sub(Vec3 a, Vec3 b) { return (Vec3){a.x-b.x, a.y-b.y, a.z-b.z}; }
static q16  v3_dot(Vec3 a, Vec3 b) {
    return qmul(a.x,b.x) + qmul(a.y,b.y) + qmul(a.z,b.z);
}
static Vec3 v3_cross(Vec3 a, Vec3 b) {
    return (Vec3){ qmul(a.y,b.z) - qmul(a.z,b.y),
                   qmul(a.z,b.x) - qmul(a.x,b.z),
                   qmul(a.x,b.y) - qmul(a.y,b.x) };
}

/* Length: pre-shift dot into the top bits so isqrt32 yields 16 good bits,
 * then rescale to Q16.16.  sqrt(d * 4^k) = sqrt(d) * 2^k.
 * Requires |vector| < ~181 so the Q16.16 dot doesn't overflow. */
static q16 v3_len(Vec3 a) {
    uint32_t d = (uint32_t)v3_dot(a, a);        /* Q16.16, >= 0 */
    if (d == 0) return 0;
    int s = 0;
    while (!(d & 0xC0000000u)) { d <<= 2; s += 2; }
    uint32_t r = isqrt32(d);                    /* = sqrt(orig raw) * 2^(s/2) */
    /* raw = real*2^16, sqrt(raw) = real_sqrt*2^8 -> want *2^16: <<8 net */
    int sh = 8 - (s >> 1);
    return (sh >= 0) ? (q16)(r << sh) : (q16)(r >> -sh);
}
static Vec3 v3_norm(Vec3 a) {
    q16 len = v3_len(a);
    if (len == 0) return (Vec3){0, 0, 0};
    return (Vec3){ qdiv(a.x, len), qdiv(a.y, len), qdiv(a.z, len) };
}

static Mat4 mat4_identity(void) {
    Mat4 r = {{{QINT(1),0,0,0},{0,QINT(1),0,0},{0,0,QINT(1),0},{0,0,0,QINT(1)}}};
    return r;
}

static Mat4 mat4_mul(const Mat4 *a, const Mat4 *b) {        /* out = a*b */
    Mat4 r;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) {
            q16 s = 0;
            for (int k = 0; k < 4; k++) s += qmul(a->m[i][k], b->m[k][j]);
            r.m[i][j] = s;
        }
    return r;
}

static Vec4 mat4_mul_vec4(const Mat4 *a, Vec4 v) {
    Vec4 r;
    const q16 *p;
    p = a->m[0]; r.x = qmul(p[0],v.x) + qmul(p[1],v.y) + qmul(p[2],v.z) + qmul(p[3],v.w);
    p = a->m[1]; r.y = qmul(p[0],v.x) + qmul(p[1],v.y) + qmul(p[2],v.z) + qmul(p[3],v.w);
    p = a->m[2]; r.z = qmul(p[0],v.x) + qmul(p[1],v.y) + qmul(p[2],v.z) + qmul(p[3],v.w);
    p = a->m[3]; r.w = qmul(p[0],v.x) + qmul(p[1],v.y) + qmul(p[2],v.z) + qmul(p[3],v.w);
    return r;
}

/* ---- Model-space helpers --------------------------------------------------- */
static Mat4 mat4_translate(q16 x, q16 y, q16 z) {
    Mat4 r = mat4_identity();
    r.m[0][3] = x; r.m[1][3] = y; r.m[2][3] = z;    /* lives in the w column */
    return r;
}
static Mat4 mat4_rotate_y(uint16_t bam) {
    Mat4 r = mat4_identity();
    q16 c = qcos(bam), s = qsin(bam);
    r.m[0][0] =  c; r.m[0][2] = s;
    r.m[2][0] = -s; r.m[2][2] = c;
    return r;
}

/* ---- View matrix: inverse of the camera pose ------------------------------- */
static Mat4 mat4_look_at(Vec3 eye, Vec3 target, Vec3 up) {
    Vec3 f = v3_norm(v3_sub(target, eye));      /* forward = camera -z */
    Vec3 r = v3_norm(v3_cross(f, up));          /* right               */
    Vec3 u = v3_cross(r, f);                    /* true up             */
    Mat4 v = {{
        {  r.x,  r.y,  r.z, -v3_dot(r, eye) },
        {  u.x,  u.y,  u.z, -v3_dot(u, eye) },
        { -f.x, -f.y, -f.z,  v3_dot(f, eye) },
        {  0,    0,    0,    QINT(1)        }
    }};
    return v;
}

/* FPS-style: eye + yaw/pitch in BAM. yaw=0,pitch=0 looks down -z. */
static Mat4 mat4_fps_view(Vec3 eye, uint16_t yaw, uint16_t pitch) {
    q16 cy = qcos(yaw),   sy = qsin(yaw);
    q16 cp = qcos(pitch), sp = qsin(pitch);
    Vec3 f = { -qmul(sy, cp), sp, -qmul(cy, cp) };
    Vec3 target = { eye.x + f.x, eye.y + f.y, eye.z + f.z };
    return mat4_look_at(eye, target, (Vec3){0, QINT(1), 0});
}

/* ---- Projection: w_clip = -z_view; z_ndc in [0,1] (0 = near, wins) --------- */
static Mat4 mat4_perspective(uint16_t fovy_bam, q16 aspect, q16 near, q16 far) {
    uint16_t h = fovy_bam >> 1;
    q16 f = qdiv(qcos(h), qsin(h));             /* cot(fov/2), no tan */
    q16 nmf = near - far;                       /* negative           */
    Mat4 p = {{{0}}};
    p.m[0][0] = qdiv(f, aspect);
    p.m[1][1] = f;
    p.m[2][2] = qdiv(far, nmf);
    p.m[2][3] = qdiv(qmul(near, far), nmf);
    p.m[3][2] = Q16(-1);                        /* THE trick: w = -z_view */
    return p;
}

/* ---- Clip -> screen packing -------------------------------------------------
 * Rejects (returns 0) if: w too small (near plane / behind camera), w too big
 * (pix_w overflow), or outside a +/-4 NDC guard band (keeps every later
 * multiply in int32 AND inside signed Q12.4). Reject the whole triangle if
 * any vertex fails; real near-plane clipping is a later milestone.
 * -------------------------------------------------------------------------- */
#define W_MIN  Q16(1.25)     /* hardware needs w > 1; colors want w >= 2 */
#define W_MAX  QINT(500)     /* pix_w = 128*w must fit 16 bits           */

static int pack_vertex(Vertex *out, Vec4 clip, uint32_t cr, uint32_t cg, uint32_t cb)
{
    if (clip.w < W_MIN || clip.w > W_MAX) return 0;

    /* Guard BEFORE dividing: |x| <= 4*w  <=>  |ndc| <= 4 (+/-1280 px). */
    q16 lim = clip.w << 2;
    if (clip.x >  lim || clip.x < -lim) return 0;
    if (clip.y >  lim || clip.y < -lim) return 0;

    q16 nx = qdiv(clip.x, clip.w);              /* |q16| <= 4*65536      */
    q16 ny = qdiv(clip.y, clip.w);
    q16 nz = qdiv(clip.z, clip.w);

    /* NDC [-1,1] -> Q12.4 pixels. |nx*5120| <= 1.34e9: fits int32.
     * Framebuffer y grows downward: flip. */
    int32_t sx_q4 = ((nx * 5120) >> 16) + 5120;         /* 5120 = 320 px * 16 */
    int32_t sy_q4 = 3840 - ((ny * 3840) >> 16);         /* 3840 = 240 px * 16 */

    if (nz < 0)       nz = 0;                   /* clamp depth to [0,1) */
    if (nz > 0xFFFF)  nz = 0xFFFF;

    out->x = (uint32_t)sx_q4;
    out->y = (uint32_t)sy_q4;
    out->z = (uint32_t)nz;                                      /* 16-bit depth */
    out->w = udiv_frac(1u << 24, (uint32_t)clip.w, 16);         /* 2^24 / w     */
    out->r = udiv_frac(cr << 9,  (uint32_t)clip.w, 16);         /* c*512 / w    */
    out->g = udiv_frac(cg << 9,  (uint32_t)clip.w, 16);
    out->b = udiv_frac(cb << 9,  (uint32_t)clip.w, 16);
    if (out->r > 0xFFFF) out->r = 0xFFFF;       /* c=255 & w<2: clamp (dims) */
    if (out->g > 0xFFFF) out->g = 0xFFFF;
    if (out->b > 0xFFFF) out->b = 0xFFFF;
    return 1;
}

/* ---- Putting it together ---------------------------------------------------- */
typedef struct { Vec3 pos; uint32_t r, g, b; } WorldVertex;   /* colors 0..255 */

extern void render_tri(Vertex *a, Vertex *b, Vertex *c, uint32_t is_second_buf);

static int draw_world_tri(const Mat4 *view_proj,
                          const WorldVertex *wa,
                          const WorldVertex *wb,
                          const WorldVertex *wc,
                          uint32_t is_second_buf)
{
    Vertex a, b, c;
    Vec4 pa = mat4_mul_vec4(view_proj, (Vec4){wa->pos.x, wa->pos.y, wa->pos.z, QINT(1)});
    Vec4 pb = mat4_mul_vec4(view_proj, (Vec4){wb->pos.x, wb->pos.y, wb->pos.z, QINT(1)});
    Vec4 pc = mat4_mul_vec4(view_proj, (Vec4){wc->pos.x, wc->pos.y, wc->pos.z, QINT(1)});

    if (!pack_vertex(&a, pa, wa->r, wa->g, wa->b)) return 0;
    if (!pack_vertex(&b, pb, wb->r, wb->g, wb->b)) return 0;
    if (!pack_vertex(&c, pc, wc->r, wc->g, wc->b)) return 0;

    render_tri(&a, &b, &c, is_second_buf);
    return 1;
}


#define MESH_MAX_VERTS 16
#define BACKFACE_CULL  1    /* set 1 to skip faces pointing away (2x fill rate) */

typedef struct {
    const WorldVertex *verts;
    const uint8_t   (*tris)[3];
    uint32_t n_verts, n_tris;
} Mesh;

/* ---- Octahedron: apex up, apex down, unit square on the equator. -----------
 * NOTE: shared vertices mean colors BLEND smoothly across faces (each face
 * corner inherits the shared vertex color). For flat, distinctly-colored
 * faces, duplicate vertices so each face owns its own three.
 * -------------------------------------------------------------------------- */
static const WorldVertex octa_verts[6] = {
    { { 0,        QINT(1),  0        }, 255, 255, 255 },   /* 0: top apex    */
    { { QINT(1),  0,        0        }, 255,   0,   0 },   /* 1: +x  red     */
    { { 0,        0,        QINT(1)  },   0, 255,   0 },   /* 2: +z  green   */
    { { Q16(-1),  0,        0        },   0,   0, 255 },   /* 3: -x  blue    */
    { { 0,        0,        Q16(-1)  }, 255, 255,   0 },   /* 4: -z  yellow  */
    { { 0,        Q16(-1),  0        },  40,  40,  40 },   /* 5: bottom apex */
};

/* Counter-clockwise seen from OUTSIDE (matters only if culling is on). */
static const uint8_t octa_tris[8][3] = {
    { 0, 2, 1 }, { 0, 3, 2 }, { 0, 4, 3 }, { 0, 1, 4 },   /* top pyramid    */
    { 5, 1, 2 }, { 5, 2, 3 }, { 5, 3, 4 }, { 5, 4, 1 },   /* bottom pyramid */
};

static const Mesh octa = { octa_verts, octa_tris, 6, 8 };

/* ---- Transform once, assemble from indices, dispatch. ----------------------
 * A face is skipped if ANY of its vertices failed pack_vertex (near-plane /
 * guard-band reject) — crude clipping, fine while the object stays in view.
 * Returns the number of triangles actually dispatched.
 * -------------------------------------------------------------------------- */
static uint32_t draw_mesh(const Mat4 *vp, const Mesh *m, uint32_t buf)
{
    Vertex  xf[MESH_MAX_VERTS];
    uint8_t ok[MESH_MAX_VERTS];

    for (uint32_t i = 0; i < m->n_verts; i++) {
        const WorldVertex *wv = &m->verts[i];
        Vec4 clip = mat4_mul_vec4(vp, (Vec4){wv->pos.x, wv->pos.y, wv->pos.z, QINT(1)});
        ok[i] = (uint8_t)pack_vertex(&xf[i], clip, wv->r, wv->g, wv->b);
    }

    uint32_t drawn = 0;
    for (uint32_t t = 0; t < m->n_tris; t++) {
        uint8_t i0 = m->tris[t][0], i1 = m->tris[t][1], i2 = m->tris[t][2];
        if (!(ok[i0] & ok[i1] & ok[i2])) continue;

#if BACKFACE_CULL
        /* Signed area of the screen-space triangle (Q12.4 coords, fits int32:
         * |diff| <= 2*10240, product <= 4.2e8). World-CCW faces come out
         * NEGATIVE on screen because the y-axis flip mirrors orientation. */
        int32_t ax = (int32_t)xf[i1].x - (int32_t)xf[i0].x;
        int32_t ay = (int32_t)xf[i1].y - (int32_t)xf[i0].y;
        int32_t bx = (int32_t)xf[i2].x - (int32_t)xf[i0].x;
        int32_t by = (int32_t)xf[i2].y - (int32_t)xf[i0].y;
        if (ax * by - ay * bx >= 0) continue;      /* back-facing: skip */
#endif
        // printf("TRIANGLE DISPATCHED! COLORS: <%d, %d, %d>, <%d, %d, %d>, <%d, %d, %d>\n", xf[i0].r, xf[i0].g, xf[i0].b,
        //  xf[i1].r, xf[i1].g, xf[i1].b,  xf[i2].r, xf[i2].g, xf[i2].b);
        render_tri(&xf[i0], &xf[i1], &xf[i2], buf);
        drawn++;
    }
    return drawn;
}

/* ---- Per-frame entry -------------------------------------------------------- */
void frame(uint16_t angle)
{
    clearBuf(0xFFFFFFFF, 2);                       /* z-buffer to far        */
    uint32_t buf = 1 - ((Xil_In32(B + 8) >> 20) & 1);          /* which buffer to render */
    clearBuf(0xFFFFFF00, 0);

    Vec3 eye = { qmul(QINT(6), qsin(angle)), QINT(1), qmul(QINT(6), qcos(angle)) };
    Mat4 view = mat4_look_at(eye, (Vec3){0, 0, 0}, (Vec3){0, QINT(1), 0});
    Mat4 proj = mat4_perspective(DEG_TO_BAM(60),
                                 Q16(640.0 / 480.0),
                                 QINT(2),          /* near: hardware-friendly */
                                 QINT(500));       /* far:  w < 512 limit     */
    Mat4 vp = mat4_mul(&proj, &view);              /* proj AFTER view         */

    draw_mesh(&vp, &octa, 0);

}

int main() {
    setupColors();

//    Vertex a = {1600,  800, 32768, 4194304, 32640,     0,     0};  /* red   */
//    Vertex b = {8000, 1600, 32768, 4194304,     0, 32640,     0};  /* green */
//    Vertex c = {4800, 6400, 32768, 4194304,     0,     0, 32640};  /* blue  */
//    render_tri(&a, &b, &c, 0);
//    clearBuf(0xFFFFFFFF, 2);
//
//    Vertex d = {1600,  800, 32768, 4194304, 32640,     0,     0};  /* red   */
//    Vertex e = {8000, 1600, 32768, 4194304,     0, 32640,     0};  /* green */
//    Vertex f = {4800, 6400, 32768, 4194304,     0,     0, 32640};  /* blue  */
//    render_tri(&d, &e, &f, 1);

//    for(int i = 0; i < 1000000; i++){
//    	q16 angle = qsin((i << 5) & 0xFFFF);
//    	frame(angle);
//    }
    q16 angle = qsin((0xabcd) & 0xFFFF);
    frame(angle);
//    while((Xil_In32(B)) != 0) {}
//    frame(angle);
//    while((Xil_In32(B)) != 0) {}
//    frame(angle);



    return 0;
}

