// IOSDisplayShim.h — bridges Wine/DXMT's expected macdrv_* driver API to
// an iOS CAMetalLayer handed in from Swift.

#ifndef IOS_DISPLAY_SHIM_H
#define IOS_DISPLAY_SHIM_H

#ifdef __OBJC__
#import <QuartzCore/CAMetalLayer.h>
void madeira_display_set_layer(CAMetalLayer *layer);
#endif

#endif
