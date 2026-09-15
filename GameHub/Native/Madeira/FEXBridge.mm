// FEXBridge.mm - iOS-compatible FEX bridge for GameHub
// Provides the public API. Real FEXCore init occurs only when libFEXCore.a is linked.
// No fake success: fex_initialize returns false until the real library is present.

#include "FEXBridge.h"
#include "JITAllocator.h"
#include <stdio.h>
#include <string.h>

static fex_log_callback_t g_fex_log_cb = NULL;
static bool g_fex_ready = false;

static void fex_log(const char *msg) {
    if (g_fex_log_cb) g_fex_log_cb(msg);
    else fprintf(stderr, "[FEX] %s\n", msg);
}

extern "C" {
    // Weak hook: a later Madeira FEX host object can override by providing
    // a strong fex_core_probe() that returns non-zero when FEXCore is live.
    int fex_core_probe(void) __attribute__((weak));
}

bool fex_initialize(void) {
    if (!jit_test_mapping()) {
        fex_log("JIT dual-mapping test failed — enable JIT (StikDebug) before FEX");
    }

    if (fex_core_probe && fex_core_probe() != 0) {
        fex_log("fex_initialize: FEXCore probe succeeded");
        g_fex_ready = true;
        return true;
    }

    fex_log("fex_initialize: libFEXCore.a not providing fex_core_probe — FEX translation unavailable");
    g_fex_ready = false;
    return false;
}

void fex_shutdown(void) {
    g_fex_ready = false;
    fex_log("fex_shutdown");
}

int64_t fex_test_execute(void) {
    if (!g_fex_ready) {
        fex_log("fex_test_execute: FEX not initialized");
        return -1;
    }
    return jit_test_execute();
}

void fex_set_log_callback(fex_log_callback_t callback) {
    g_fex_log_cb = callback;
}

int64_t fex_get_jit_write_offset(void) {
    // C symbol from JITAllocator.c — must not use C++ linkage.
    return jit_get_write_offset();
}
