// DXMTBridge.m — iOS Metal presentation gate for the DXMT host path.
// Real D3D11→Metal translation lives in libdxmt_combined.a (winemetal unix).
// Presentation uses macdrv_functions exported by IOSDisplayShim.m.

#import "DXMTBridge.h"
#import "IOSDisplayShim.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <stdio.h>
#include <stdint.h>
#include <dlfcn.h>

static bool g_dxmt_ready = false;

__attribute__((weak)) int dxmt_host_probe(void) {
    void *self = dlopen(NULL, RTLD_LAZY);
    if (!self) return 0;
    static const char *names[] = {
        "dxmt_host_probe",
        "dxmt_initialize_device",
        "winemetal_unix_call",
        "dxmt_create_device",
        "macdrv_functions",
        "macdrv_view_get_metal_layer",
        NULL
    };
    int hits = 0;
    for (int i = 0; names[i]; i++) {
        if (dlsym(self, names[i])) hits++;
    }
    return hits > 0 ? 1 : 0;
}

bool dxmt_initialize(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        fprintf(stderr, "[DXMT] no Metal device\n");
        g_dxmt_ready = false;
        return false;
    }

    int probe = dxmt_host_probe ? dxmt_host_probe() : 0;
    CAMetalLayer *layer = winios_metal_layer_for_hwnd(NULL);
    uint64_t presents = madeira_get_present_count();
    fprintf(stderr, "[DXMT] init device=%s probe=%d layer=%p presents=%llu macdrv=%s\n",
            [[device name] UTF8String] ?: "?",
            probe,
            (__bridge void *)layer,
            (unsigned long long)presents,
            dlsym(RTLD_DEFAULT, "macdrv_functions") ? "exported" : "MISSING");

    g_dxmt_ready = (device != nil);
    return g_dxmt_ready;
}

void dxmt_shutdown(void) {
    g_dxmt_ready = false;
}

bool dxmt_is_ready(void) {
    return g_dxmt_ready;
}
