#include <stdint.h>
#include <stdio.h>
void lowpass(float *buf, int64_t n, float *state, int64_t sn, float fs, float fc, float q);
int main(void) {
    // a 1 kHz-ish square wave at 48 kHz, processed (a) in one call and (b) in 4 blocks with carried state
    float one[64], blk[64], s1[2] = {0, 0}, s2[2] = {0, 0};
    for (int i = 0; i < 64; i++) one[i] = blk[i] = ((i / 24) % 2) ? -0.8f : 0.8f;
    lowpass(one, 64, s1, 2, 48000.0f, 2000.0f, 0.707f);
    for (int b = 0; b < 4; b++) lowpass(blk + 16 * b, 16, s2, 2, 48000.0f, 2000.0f, 0.707f);
    int same = 1;
    for (int i = 0; i < 64; i++) if (one[i] != blk[i]) same = 0;
    printf("y[0]=%.6f y[10]=%.6f y[30]=%.6f y[63]=%.6f\n", one[0], one[10], one[30], one[63]);
    printf("blocked == continuous: %s\n", same ? "yes" : "NO");
    return 0;
}
