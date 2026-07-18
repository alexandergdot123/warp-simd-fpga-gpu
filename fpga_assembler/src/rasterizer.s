# ; ... SETUP + PHASE 1 NEGATIVE + PHASE 2 FOLD unchanged, except the
# ;     last fold level now PERSISTS the total so the repaint can read it:
#     barrier 1
#     lw  r4, r10, 0
#     lw  r5, r10, 20
#     add r4, r4, r5
#     sw  r10, r4, 0        ; <-- NEW: SRAM[lane] = 2400 + 16*lane

# ; PHASE 3 REPAINT (1 ctx = 20 lanes, coalesced like the negative)
#     add r9, r15, 0        ; addr = lane (0..19)
# ; ---- body, streamed 15360x ----
#     div r6, r9, 15360     ; band = addr / 15360   (0..19)
#     lw  r4, r6, 0         ; total = SRAM[band]     <- reads the fold result
#     sub r6, r4, 2400      ; 16*band
#     lsr r6, r6, 4         ; band
#     mul r6, r6, 13        ; gray 0..247
#     lsl r5, r6, 8
#     lsl r7, r6, 16
#     or  r7, r7, r5
#     lsl r5, r6, 24
#     or  r7, r7, r5        ; grayscale pixel
#     swg r9, r7, 0         ; 20 CONSECUTIVE words per dispatch (coalesced)
#     add r9, r9, 20        ; march by thread count
#     sub r4, r4, 2400
#     div r4, r4, 16         ; band
    

#     lsl r5, r4, 8
#     lsl r5, r5, 4
#     lsl r5, r5, 2
#     swg r9, r5, 0
#     add r9, r9, 20
#     add r4, r4, 20
#     add r4, r15, 0

cpu_store 5760, 28
barrier 12
add r1, r15, 0
and r6, r6, 0
//for loop twice below
lw r2, r6, 5761
lw r3, r6, 5768
sub r3, r3, r2
lsl r0, r1, 4
sub r0, r0, r2
lsl r0, r0, 16
div r0, r0, r3 //ratio
and r2, r2, 0
add r2, r2, 1
lsl r2, r2, 16
sub r2, r2, r0 //1-ratio
lw r3, r6, 5760
mul r3, r3, r2
lw r4, r6, 5767
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 0
lw r3, r6, 5762
mul r3, r3, r2
lw r4, r6, 5769
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 480
lw r3, r6, 5763
lsr r5, r2, 8
mul r3, r3, r5
lw r4, r6, 5770
lsr r5, r0, 8
mul r4, r4, r5
add r3, r3, r4
lsr r3, r3, 8
sw r3, r1, 960
lw r3, r6, 5764
mul r3, r3, r2
lw r4, r6, 5771
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 1440
lw r3, r6, 5765
mul r3, r3, r2
lw r4, r6, 5772
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 1920
lw r3, r6, 5766
mul r3, r3, r2
lw r4, r6, 5773
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 2400
add r1, r1, 240

add r1, r15, 0
and r6, r6, 0
//for loop twice below
lw r2, r6, 5775
lw r3, r6, 5782
sub r3, r3, r2
lsl r0, r1, 4
sub r0, r0, r2
lsl r0, r0, 16
div r0, r0, r3 //ratio
and r2, r2, 0
add r2, r2, 1
lsl r2, r2, 16
sub r2, r2, r0 //1-ratio
lw r3, r6, 5774
mul r3, r3, r2
lw r4, r6, 5781
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 2880
lw r3, r6, 5776
mul r3, r3, r2
lw r4, r6, 5783
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 3360
lw r3, r6, 5777
lsr r5, r2, 8
mul r3, r3, r5
lw r4, r6, 5784
lsr r5, r0, 8
mul r4, r4, r5
add r3, r3, r4
lsr r3, r3, 8
sw r3, r1, 3840
lw r3, r6, 5778
mul r3, r3, r2
lw r4, r6, 5785
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 4320
lw r3, r6, 5779
mul r3, r3, r2
lw r4, r6, 5786
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 4800
lw r3, r6, 5780
mul r3, r3, r2
lw r4, r6, 5787
mul r4, r4, r0
add r3, r3, r4
lsr r3, r3, 16
sw r3, r1, 5280
add r1, r1, 240

barrier 16


#Happens once per x run, every y run
div r1, r15, 20
mul r2, r1, 20
sub r0, r15, r2 #my_x
add r0, r0, 0 #PLUS min_x
add r1, r1, 0 #PLUS y_cur #my_y
lw r2, r1, 0
lw r3, r1, 2880
add r13, r3, 0
sub r3, r3, r2 #span
and r14, r14, 0
add r14, r14, 0x8000
lsl r14, r14, 16
div r3, r14, r3



#The below happens once per pixel

lsl r12, r0, 4 //I don't have to check my_x against 0 because 0 + tid%20 is the min
skip_ge r0, 640, skip_pixel //if guard on my_x >= 640
skip_ge r12, r13, skip_pixel //if guard on my_x >= right_x
skip_lt r12, r2, skip_pixel //if guard on my_x < left_x
skip_ge r1, 0, skip_pixel //if guard on my_y >= min(480, y_bottom) #ADD min(480, y_bottom)
skip_lt r1, 0, skip_pixel //if guard on my_y >= max(0, y_top) #ADD max(0, y_top)
lsl r6, r0, 4
sub r6, r6, r2 #dx
mul r6, r6, r3 #ratio
lsr r6, r6, 8
lsl r6, r6, 1
lsr r6, r6, 8 
and r7, r3, 0
add r7, r7, 1
lsl r7, r7, 16
sub r7, r7, r6 #1-ratio

lw r4, r1, 480 #l_z
lw r5, r1, 3360 #r_z
mul r4, r4, r7
mul r5, r5, r6
add r4, r4, r5 #pix_z
and r8, r8, 0
add r8, r8, 1280
mul r8, r8, 480
add r8, r8, r0
mul r9, r1, 640
add r8, r8, r9
lwg r9, r8, 0 #z_cur
skip_ge r4, r9, skip_pixel
swg r4, r8, 0 #z_buf = z_cur
lw r4, r1, 960 #l_w
lsr r9, r6, 8
lsr r10, r7, 8
lw r5, r1, 3840 #r_w
mul r4, r4, r10
mul r5, r5, r9
add r4, r4, r5 #1/pix_w
lsr r4, r4, 8
and r9, r9, 0
add r9, r9, 0x8000
lsl r9, r9, 16
div r4, r9, r4 #pix_w
and r12, r12, 0
#OPTIONAL
add r12, r12, 640
mul r12, r12, 480
add r11, r11, r12
#OR
# add r12, r12, 0
# add r12, r12, 0
# add r12, r12, 0
mul r11, r1, 640
add r11, r11, r0
add r12, r11, r12
lw r10, r1, 1440 #r_l
mul r10, r10, r7
lw r11, r1, 4320 #r_r
mul r11, r11, r6
add r10, r10, r11
lsr r10, r10, 16
mul r10, r10, r4
lsr r10, r10, 8
lsl r10, r10, 1
lsr r10, r10, 8 
lw r10, r10, 6000
swg r10, r12, 0, 8 #STORE THE TOP BYTE

lw r10, r1, 1920 #g_l
mul r10, r10, r7
lw r11, r1, 4800 #g_r
mul r11, r11, r6
add r10, r10, r11
lsr r10, r10, 16
mul r10, r10, r4
lsr r10, r10, 8
lsl r10, r10, 1
lsr r10, r10, 8 
lw r10, r10, 6000
swg r10, r12, 0, 4 #STORE THE THIRD BYTE

lw r10, r1, 2400 #b_l
mul r10, r10, r7
lw r11, r1, 5280 #b_r
mul r11, r11, r6
add r10, r10, r11
lsr r10, r10, 16
mul r10, r10, r4
lsr r10, r10, 8
lsl r10, r10, 1
lsr r10, r10, 8 
lw r10, r10, 6000
swg r10, r12, 0, 2 #STORE THE SECOND BYTE
skip_pixel:
add r0, r0, 20
