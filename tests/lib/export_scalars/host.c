#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

float   gain_sample(float x, float db);
int32_t add_i32(int32_t a, int32_t b);
uint8_t mix_u8(uint8_t a, uint8_t b);
bool    is_loud(double x);
void   *same_handle(void *p);
void    ping(void);

int main(void) {
    int probe = 0;
    printf("gain_sample(0.5, -6) = %.6f\n", gain_sample(0.5f, -6.0f));
    printf("add_i32(40, 2) = %d, add_i32(-5, 3) = %d\n", add_i32(40, 2), add_i32(-5, 3));
    printf("mix_u8(0x3c, 0xa5) = 0x%02x\n", mix_u8(0x3c, 0xa5));
    printf("is_loud(0.7) = %d, is_loud(0.1) = %d\n", is_loud(0.7), is_loud(0.1));
    printf("same_handle round-trips = %d\n", same_handle(&probe) == &probe);
    ping();
    fflush(stdout);
    return 0;
}
