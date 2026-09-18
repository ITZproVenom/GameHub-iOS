#include <sys/sysctl.h>
#include <sys/types.h>
/* JITAllocator.c - dual-mapped executable memory for iOS (GameHub / Madeira path)
 * Implements vm_allocate + vm_remap RW/RX aliases used by FEX / xtajit64.
 * RX mapping requires CS_DEBUGGED (StikDebug / TrollStore JIT).
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
#include <libkern/OSCacheControl.h>

struct JITRegion {
    void *rw;
    void *rx;
    size_t size;
    int64_t write_offset;
};

static jit_log_callback_t g_jit_log = NULL;
static JITRegion *g_pool = NULL;
static pthread_mutex_t g_jit_lock = PTHREAD_MUTEX_INITIALIZER;
static int64_t g_write_offset = 0;

static void jlog(const char *msg) {
    if (g_jit_log) g_jit_log(msg);
    else fprintf(stderr, "[JIT] %s\n", msg);
}

static void jlogf(const char *fmt, ...) {
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    jlog(buf);
}

void jit_set_log_callback(jit_log_callback_t cb) { g_jit_log = cb; }

bool jit_check_debugged(void) {
#if defined(__APPLE__)
    const char *e = getenv("MADEIRA_JIT_READY");
    if (e && *e == '1') return true;
#endif
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
    jlog("jit_install_trap_handler: dual-map path active");
}

static size_t page_round(size_t size) {
    size_t page = (size_t)getpagesize();
    return (size + page - 1) & ~(page - 1);
}

static bool dual_map(size_t size, void **out_rw, void **out_rx) {
    mach_port_t task = mach_task_self();
    vm_address_t rw = 0;
    kern_return_t kr = vm_allocate(task, &rw, size, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        jlogf("vm_allocate RW failed: %d", kr);
        return false;
    }
    kr = vm_protect(task, rw, size, FALSE, VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        vm_deallocate(task, rw, size);
        jlogf("vm_protect RW failed: %d", kr);
        return false;
    }

    vm_address_t rx = 0;
    vm_prot_t cur = 0, max = 0;
    kr = vm_remap(task, &rx, size, 0, VM_FLAGS_ANYWHERE,
                  task, rw, FALSE, &cur, &max, VM_INHERIT_NONE);
    if (kr != KERN_SUCCESS) {
        vm_deallocate(task, rw, size);
        jlogf("vm_remap RX failed: %d (need CS_DEBUGGED)", kr);
        return false;
    }
    kr = vm_protect(task, rx, size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        vm_deallocate(task, rx, size);
        vm_deallocate(task, rw, size);
        jlogf("vm_protect RX failed: %d", kr);
        return false;
    }
    *out_rw = (void *)rw;
    *out_rx = (void *)rx;
    return true;
}

JITRegion *jit_region_create(size_t size) {
    size = page_round(size ? size : (size_t)getpagesize() * 16);
    void *rw = NULL, *rx = NULL;
    if (!dual_map(size, &rw, &rx)) return NULL;
    JITRegion *r = calloc(1, sizeof(*r));
    if (!r) {
        mach_port_t task = mach_task_self();
        vm_deallocate(task, (vm_address_t)rw, size);
        vm_deallocate(task, (vm_address_t)rx, size);
        return NULL;
    }
    r->rw = rw;
    r->rx = rx;
    r->size = size;
    r->write_offset = (int64_t)(uintptr_t)rw - (int64_t)(uintptr_t)rx;
    jlogf("jit_region_create size=%zu rw=%p rx=%p off=%lld", size, rw, rx, (long long)r->write_offset);
    return r;
}

void jit_region_destroy(JITRegion *region) {
    if (!region) return;
    mach_port_t task = mach_task_self();
    if (region->rw) vm_deallocate(task, (vm_address_t)region->rw, region->size);
    if (region->rx && region->rx != region->rw)
        vm_deallocate(task, (vm_address_t)region->rx, region->size);
    free(region);
}

void *jit_region_rw_ptr(JITRegion *region) { return region ? region->rw : NULL; }
void *jit_region_rx_ptr(JITRegion *region) { return region ? region->rx : NULL; }
size_t jit_region_size(JITRegion *region) { return region ? region->size : 0; }

void *jit_region_write(JITRegion *region, size_t offset, const void *code, size_t code_size) {
    if (!region || !code) return NULL;
    if (offset + code_size > region->size) return NULL;
    memcpy((uint8_t *)region->rw + offset, code, code_size);
    sys_icache_invalidate((uint8_t *)region->rx + offset, code_size);
    return (uint8_t *)region->rx + offset;
}

void jit_region_invalidate(JITRegion *region, size_t offset, size_t size) {
    if (!region) return;
    if (offset + size > region->size) return;
    sys_icache_invalidate((uint8_t *)region->rx + offset, size);
}

bool jit_make_region_no_footprint(void *addr, size_t size, const char *label) {
    (void)addr; (void)size; (void)label;
    return false;
}

static JITRegion *ensure_pool(void) {
    pthread_mutex_lock(&g_jit_lock);
    if (!g_pool) {
        g_pool = jit_region_create((size_t)getpagesize() * 256);
        if (g_pool) {
            g_write_offset = g_pool->write_offset;
            char env[32];
            snprintf(env, sizeof(env), "%lld", (long long)g_write_offset);
            setenv("MADEIRA_JIT_WRITE_OFFSET", env, 1);
        }
    }
    pthread_mutex_unlock(&g_jit_lock);
    return g_pool;
}

bool jit_test_mapping(void) {
    if (!jit_check_debugged()) {
        jlog("jit_test_mapping: CS_DEBUGGED not set");
        return false;
    }
    JITRegion *r = jit_region_create((size_t)getpagesize() * 4);
    if (!r) {
        jlog("jit_test_mapping: dual_map failed");
        return false;
    }
    /* ARM64: RET encoded as 0xD65F03C0 */
    uint32_t ret = 0xD65F03C0u;
    void *fn = jit_region_write(r, 0, &ret, sizeof(ret));
    jit_region_destroy(r);
    if (!fn) {
        jlog("jit_test_mapping: write failed");
        return false;
    }
    jlog("jit_test_mapping: dual-map + I-cache OK");
    return true;
}

int64_t jit_test_execute(void) {
    if (!jit_check_debugged()) return -2;
    JITRegion *r = jit_region_create((size_t)getpagesize());
    if (!r) return -1;
    /* mov w0, #42 ; ret */
    uint32_t code[2] = { 0x52800540u, 0xD65F03C0u };
    int (*fn)(void) = (int (*)(void))jit_region_write(r, 0, code, sizeof(code));
    int64_t rc = -1;
    if (fn) {
        rc = fn();
        jlogf("jit_test_execute returned %lld", (long long)rc);
    }
    jit_region_destroy(r);
    return rc == 42 ? 42 : -1;
}

int64_t jit_test_execute_strategy2(void) {
    return jit_test_execute();
}

void jit_wx_probe(void) {
    bool ok = jit_test_mapping();
    jlogf("jit_wx_probe: %s", ok ? "pass" : "fail");
}

int64_t jit_get_write_offset(void) {
    if (g_write_offset == 0) ensure_pool();
    return g_write_offset;
}
