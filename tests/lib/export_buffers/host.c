#include <stdint.h>
#include <stdio.h>
void  apply_gain(float *buf, int64_t n, float db);
float peak(const float *buf, int64_t n);
int main(void) {
    float b[4] = { 0.5f, -1.0f, 0.25f, 0.0f };
    apply_gain(b, 4, -6.0f);
    printf("%.6f %.6f %.6f %.6f peak=%.6f\n", b[0], b[1], b[2], b[3], peak(b, 4));
    apply_gain(b + 1, 2, 6.0f);
    printf("%.6f %.6f %.6f %.6f\n", b[0], b[1], b[2], b[3]);
    return 0;
}
