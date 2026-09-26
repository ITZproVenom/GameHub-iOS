// IOSDisplayShim.h — bridges Wine/DXMT's expected macdrv_* driver API to
// an iOS CAMetalLayer handed in from Swift. Must stay compatible with
// Madeira 97e2ce26 winemetal_unix.c dlsym(RTLD_DEFAULT, "macdrv_functions").

#ifndef IOS_DISPLAY_SHIM_H
#define IOS_DISPLAY_SHIM_H

#ifdef __OBJC__
#import <QuartzCore/CAMetalLayer.h>
void madeira_display_set_layer(CAMetalLayer *layer);
CAMetalLayer *winios_metal_layer_for_hwnd(void *hwnd);
#else
void *winios_metal_layer_for_hwnd(void *hwnd);
#endif

#ifdef __cplusplus
extern "C" {
#endif
uint64_t madeira_get_present_count(void);
void madeira_note_present(void);
#ifdef __cplusplus
}
#endif

#endif
