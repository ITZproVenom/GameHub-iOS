#ifndef DXMT_BRIDGE_H
#define DXMT_BRIDGE_H

#include <stdbool.h>

#ifdef __OBJC__
#import <QuartzCore/CAMetalLayer.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Returns true when a Metal device is present and a presentation layer is bound.
 * Does not fake a running D3D11 swapchain. */
bool dxmt_initialize(void);
void dxmt_shutdown(void);
bool dxmt_is_ready(void);

/* Weak-overridable probe provided by libdxmt_combined.a when that archive
 * actually contains the unix/Metal objects. Default (this translation unit)
 * returns 0. */
int dxmt_host_probe(void);

#ifdef __cplusplus
}
#endif

#endif
