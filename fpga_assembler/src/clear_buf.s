barrier 16
cpu_store 8191, 1

barrier 16
and r0, r0, 0
lw r1, r0, 8191
add r0, r0, 640
mul r0, r0, 480
mul r0, r0, 0 #ADD BUFFER INDEX - r0 for first screen buf, r1 for second, r2, for z-buf
# add r0, r0, r15 #after this it's just the loop for 960 times
mul r2, r15, 80
div r2, r2, 80
add r0, r0, r2
swg r1, r0, 0
add r0, r0, 320