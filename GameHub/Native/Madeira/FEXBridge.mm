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

// Weak symbols that become strong when libFEXCore is force_loaded.
// These are intentionally minimal; full FEXBridge from Madeira requires FEX headers.
extern "C" {
    // Placeholder for future strong implementations from host libs
}

bool fex_initialize(void) {
    // Ensure JIT pool is available first (independent of FEXCore)
    if (!jit_test_mapping()) {
        fex_log("JIT dual-mapping test failed — enable JIT (StikDebug) before FEX");
        // Still continue; some paths init later
    }

    // Until libFEXCore.a provides a real implementation that overrides this,
    // we cannot claim FEX is ready. Return false so callers know.
    // When the real FEXBridge.mm from Madeira is linked with libFEXCore it
    // will provide the strong symbols.
    fex_log("fex_initialize: libFEXCore.a not linked — FEX translation unavailable");
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
    return -1;
}

void fex_set_log_callback(fex_log_callback_t callback) {
    g_fex_log_cb = callback;
}

int64_t fex_get_jit_write_offset(void) {
    // Query the dual-map pool created by JITAllocator
    // (real offset published when JIT region exists)
    extern int64_t jit_get_write_offset(void) __attribute__((weak));
    if (jit_get_write_offset) {
        return jit_get_write_offset();
    }
    return 0;
}
