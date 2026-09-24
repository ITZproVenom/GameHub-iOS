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
#include <dlfcn.h>

static bool g_dxmt_ready = false;

/* Prefer a strong symbol from libdxmt_combined.a. If the archive does not
 * export dxmt_host_probe, scan the process image for DXMT/winemetal symbols
 * so initialize reports whether the host translation objects actually linked. */
__attribute__((weak)) int dxmt_host_probe(void) {
    void *self = dlopen(NULL, RTLD_LAZY);
    if (!self) return 0;
    static const char *names[] = {
        "dxmt_host_probe",
        "dxmt_initialize_device",
        "winemetal_unix_call",
        "dxmt_create_device",
        "MTLCreateSystemDefaultDevice",
        NULL
    };
    int hits = 0;
    for (int i = 0; names[i]; i++) {
        if (dlsym(self, names[i])) hits++;
    }
    /* MTLCreateSystemDefaultDevice always exists on iOS; require another hit. */
    return hits > 1 ? 1 : 0;
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
