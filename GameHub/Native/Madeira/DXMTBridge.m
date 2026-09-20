// DXMTBridge.m — iOS Metal presentation gate for the DXMT host path.
// Real D3D11→Metal translation lives in libdxmt_combined.a (winemetal unix).
// This file verifies the host Metal layer and reports whether the
// combined archive is linked.

#import "DXMTBridge.h"
#import "IOSDisplayShim.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <stdio.h>
#include <stdint.h>

static bool g_dxmt_ready = false;

__attribute__((weak)) int dxmt_host_probe(void) {
    return 0;
}

__attribute__((weak)) uint64_t madeira_get_present_count(void) {
    return 0;
}

bool dxmt_initialize(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        fprintf(stderr, "[DXMT] no Metal device\n");
        g_dxmt_ready = false;
        return false;
    }

    int probe = 0;
    if (dxmt_host_probe) {
        probe = dxmt_host_probe();
    }
    CAMetalLayer *layer = winios_metal_layer_for_hwnd(NULL);
    uint64_t presents = madeira_get_present_count ? madeira_get_present_count() : 0;
    if (probe != 0) {
        fprintf(stderr, "[DXMT] libdxmt_combined.a probe succeeded (device=%s layer=%p presents=%llu)\n",
                [[device name] UTF8String] ?: "?", (__bridge void *)layer,
                (unsigned long long)presents);
    } else {
        fprintf(stderr, "[DXMT] Metal device present (%s); libdxmt_combined.a probe=0 layer=%p presents=%llu\n",
                [[device name] UTF8String] ?: "?", (__bridge void *)layer,
                (unsigned long long)presents);
    }

    /* Presentation proceeds through madeira_display_set_layer /
     * winios_metal_layer_for_hwnd once Wine creates an HWND. */
    g_dxmt_ready = (device != nil);
    return g_dxmt_ready;
}

void dxmt_shutdown(void) {
    g_dxmt_ready = false;
}

bool dxmt_is_ready(void) {
    return g_dxmt_ready;
}
