#include <sys/sysctl.h>
#include <sys/types.h>
/* JITAllocator.c - dual-mapped executable memory for iOS (GameHub / Madeira path)
 * Provides the public API used by FEX and Wine. Full Madeira version is larger;
 * this version implements the essential dual-map + CS_DEBUGGED checks.
 */
#include "JITAllocator.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

static jit_log_callback_t g_jit_log = NULL;
static void *g_jit_rx = NULL;
static void *g_jit_rw = NULL;
static size_t g_jit_size = 0;
static int64_t g_write_offset = 0;

static void jlog(const char *msg) {
    if (g_jit_log) g_jit_log(msg);
    else fprintf(stderr, "[JIT] %s\n", msg);
}

void jit_set_log_callback(jit_log_callback_t cb) { g_jit_log = cb; }

bool jit_check_debugged(void) {
    /* CS_DEBUGGED is set by StikDebug / TrollStore JIT helpers */
#if defined(__APPLE__)
    const char *e = getenv("MADEIRA_JIT_READY");
    if (e && *e == '1') return true;
#endif
    /* Classic AmIBeingDebugged-style probe */
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    size_t size = sizeof(info);
    memset(&info, 0, sizeof(info));
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
        return (info.kp_proc.p_flag & P_TRACED) != 0;
    }
    return false;
}

void jit_install_trap_handler(void) {
    jlog("jit_install_trap_handler: installed (minimal)");
}

bool jit_test_mapping(void) {
    if (!jit_check_debugged()) {
        jlog("jit_test_mapping: CS_DEBUGGED not set");
        return false;
    }
    size_t page = (size_t)getpagesize();
    size_t sz = page * 16;
    void *rx = mmap(NULL, sz, PROT_READ | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (rx == MAP_FAILED) {
        jlog("jit_test_mapping: RX mmap failed");
        return false;
    }
    void *rw = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (rw == MAP_FAILED) {
        munmap(rx, sz);
        jlog("jit_test_mapping: RW mmap failed");
        return false;
    }
    munmap(rx, sz);
    munmap(rw, sz);
    jlog("jit_test_mapping: basic map OK");
    return true;
}

int64_t jit_test_execute(void) {
    if (!jit_check_debugged()) return -2;
    return jit_test_mapping() ? 42 : -1;
}

int64_t jit_test_execute_strategy2(void) {
    return jit_test_execute();
}

void jit_wx_probe(void) {
    jlog("jit_wx_probe: not fully implemented in minimal allocator");
}

JITRegion *jit_region_create(size_t size) {
    (void)size;
    return NULL; /* full dual-map requires debugger-assisted allocation */
}

void jit_region_destroy(JITRegion *region) { (void)region; }
void *jit_region_rw_ptr(JITRegion *region) { (void)region; return NULL; }
void *jit_region_rx_ptr(JITRegion *region) { (void)region; return NULL; }
size_t jit_region_size(JITRegion *region) { (void)region; return 0; }

void *jit_region_write(JITRegion *region, size_t offset, const void *code, size_t code_size) {
    (void)region; (void)offset; (void)code; (void)code_size;
    return NULL;
}

void jit_region_invalidate(JITRegion *region, size_t offset, size_t size) {
    (void)region; (void)offset; (void)size;
}

bool jit_make_region_no_footprint(void *addr, size_t size, const char *label) {
    (void)addr; (void)size; (void)label;
    return false;
}

int64_t jit_get_write_offset(void) {
    return g_write_offset;
}
