// FEXBridge.mm - iOS-compatible FEX bridge for GameHub
// Real FEXCore init occurs when libFEXCore.a is linked and provides fex_core_probe.
// Dual-map JIT pool is always prepared when CS_DEBUGGED is present.

#include "FEXBridge.h"
#include "JITAllocator.h"
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>

static fex_log_callback_t g_fex_log_cb = NULL;
static bool g_fex_ready = false;

static void fex_log(const char *msg) {
    if (g_fex_log_cb) g_fex_log_cb(msg);
    else fprintf(stderr, "[FEX] %s\n", msg);
}

extern "C" {
    int fex_core_probe(void) __attribute__((weak));
    int64_t jit_get_write_offset(void);
    int64_t jit_test_execute(void);
    bool jit_test_mapping(void);
}

static int probe_fex_symbols(void) {
    if (fex_core_probe && fex_core_probe() != 0) return 1;
    /* Host archives sometimes export C wrappers rather than fex_core_probe. */
    static const char *names[] = {
        "fex_core_probe",
        "FEXCore_CreateContext",
        "fex_create_context",
        "FEX_ContextCreate",
        NULL
    };
    void *self = dlopen(NULL, RTLD_LAZY);
    if (!self) return 0;
    for (int i = 0; names[i]; i++) {
        if (dlsym(self, names[i])) {
            fex_log("found FEX host symbol");
            return 1;
        }
    }
    return 0;
}

bool fex_initialize(void) {
    if (!jit_check_debugged()) {
        fex_log("fex_initialize: JIT not enabled");
        g_fex_ready = false;
        return false;
    }

    if (!jit_test_mapping()) {
        fex_log("JIT dual-mapping test failed — enable JIT (StikDebug) before FEX");
        g_fex_ready = false;
        return false;
    }

    (void)jit_get_write_offset();

    if (probe_fex_symbols()) {
        fex_log("fex_initialize: FEXCore present, dual-map pool ready");
        g_fex_ready = true;
        return true;
    }

    fex_log("fex_initialize: libFEXCore.a not providing probe symbols — FEX translation unavailable");
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
    return jit_get_write_offset();
}
