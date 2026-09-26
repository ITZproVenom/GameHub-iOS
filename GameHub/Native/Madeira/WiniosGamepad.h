/* Host controller snapshot shared with win32u. Madeira Converter Exception. */
#ifndef WINIOS_GAMEPAD_H
#define WINIOS_GAMEPAD_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
#define WINIOS_GAMEPAD_MAX 4
struct winios_gamepad {
    uint32_t packet;
    uint16_t buttons;
    uint8_t left_trigger, right_trigger;
    int16_t lx, ly, rx, ry;
    uint8_t connected;
    uint8_t reserved[3];
};

void winios_gamepad_set_state(int index, const struct winios_gamepad *state);
int winios_gamepad_get_state(int index, struct winios_gamepad *out);
#ifdef __cplusplus
}
#endif
#endif
