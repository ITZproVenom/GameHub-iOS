// DXMTBridge.m — iOS Metal presentation gate for the DXMT host path.
// Real D3D11→Metal translation lives in libdxmt_combined.a (winemetal unix).
// This file only verifies the host Metal layer and reports whether the
// combined archive is linked.

#import "DXMTBridge.h"
#import "IOSDisplayShim.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <stdio.h>

static bool g_dxmt_ready = false;

__attribute__((weak)) int dxmt_host_probe(void) {
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
    if (probe != 0) {
        fprintf(stderr, "[DXMT] libdxmt_combined.a probe succeeded (device=%s)\n",
                [[device name] UTF8String] ?: "?");
    } else {
        fprintf(stderr, "[DXMT] Metal device present (%s); libdxmt_combined.a not providing dxmt_host_probe\n",
                [[device name] UTF8String] ?: "?");
    }

    /* Presentation still proceeds through madeira_display_set_layer /
     * winios_metal_layer_for_hwnd once Wine creates an HWND. */
    g_dxmt_ready = true;
    return true;
}

void dxmt_shutdown(void) {
    g_dxmt_ready = false;
}

bool dxmt_is_ready(void) {
    return g_dxmt_ready;
}
