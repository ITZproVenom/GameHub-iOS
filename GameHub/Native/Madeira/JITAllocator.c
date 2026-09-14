#include "JITAllocator.h"
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <os/log.h>
#include <libkern/OSCacheControl.h>

#ifndef CS_DEBUGGED
#define CS_DEBUGGED 0x10000000
#endif
#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS 0
#endif
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

#define JIT_PAGE_SIZE 0x4000

struct JITRegion {
    void *rw_ptr;
    void *rx_ptr;
    size_t size;
    mach_port_t mem_entry;
};

static jit_log_callback_t g_log_callback = NULL;

void jit_set_log_callback(jit_log_callback_t callback) { g_log_callback = callback; }

static void jit_log(const char *fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (g_log_callback) g_log_callback(buf);
    os_log(OS_LOG_DEFAULT, "[JIT] %{public}s", buf);
    fprintf(stderr, "[JIT] %s\n", buf);
}

static size_t align_to_page(size_t size) {
    return (size + JIT_PAGE_SIZE - 1) & ~(JIT_PAGE_SIZE - 1);
}

JITRegion *jit_region_create(size_t size) {
    size = align_to_page(size);
    JITRegion *region = calloc(1, sizeof(JITRegion));
    if (!region) return NULL;
    region->size = size;
    region->mem_entry = MACH_PORT_NULL;
    mach_port_t task = mach_task_self();
    memory_object_size_t entry_size = (memory_object_size_t)size;
    mach_port_t mem_entry = MACH_PORT_NULL;
    kern_return_t kr = mach_make_memory_entry_64(
        task, &entry_size, 0,
        MAP_MEM_NAMED_CREATE | VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE,
        &mem_entry, MACH_PORT_NULL);
    if (kr != KERN_SUCCESS) { free(region); return NULL; }
    region->mem_entry = mem_entry;
    mach_vm_address_t rw_addr = 0;
    kr = vm_map(task, (vm_address_t *)&rw_addr, size, 0, VM_FLAGS_ANYWHERE, mem_entry, 0, FALSE,
                VM_PROT_READ | VM_PROT_WRITE, VM_PROT_READ | VM_PROT_WRITE, VM_INHERIT_DEFAULT);
    if (kr != KERN_SUCCESS) { mach_port_deallocate(task, mem_entry); free(region); return NULL; }
    region->rw_ptr = (void *)rw_addr;
    mach_vm_address_t rx_addr = 0;
    kr = vm_map(task, (vm_address_t *)&rx_addr, size, 0, VM_FLAGS_ANYWHERE, mem_entry, 0, FALSE,
                VM_PROT_READ | VM_PROT_EXECUTE,
                VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE, VM_INHERIT_DEFAULT);
    if (kr != KERN_SUCCESS) {
        vm_deallocate(task, (vm_address_t)region->rw_ptr, size);
        mach_port_deallocate(task, mem_entry);
        free(region);
        return NULL;
    }
    region->rx_ptr = (void *)rx_addr;
    jit_log("Dual-mapped JIT region size=%zu RW=%p RX=%p", size, region->rw_ptr, region->rx_ptr);
    return region;
}

bool jit_make_region_no_footprint(void *addr, size_t size, const char *label) {
    (void)addr; (void)size; (void)label;
    return false;
}

void jit_region_destroy(JITRegion *region) {
    if (!region) return;
    mach_port_t task = mach_task_self();
    if (region->rw_ptr) vm_deallocate(task, (vm_address_t)region->rw_ptr, region->size);
    if (region->rx_ptr) vm_deallocate(task, (vm_address_t)region->rx_ptr, region->size);
    if (region->mem_entry != MACH_PORT_NULL) mach_port_deallocate(task, region->mem_entry);
    free(region);
}

void *jit_region_rw_ptr(JITRegion *region) { return region ? region->rw_ptr : NULL; }
void *jit_region_rx_ptr(JITRegion *region) { return region ? region->rx_ptr : NULL; }
size_t jit_region_size(JITRegion *region) { return region ? region->size : 0; }

void jit_region_invalidate(JITRegion *region, size_t offset, size_t size) {
    if (!region || !region->rx_ptr) return;
    sys_icache_invalidate((char *)region->rx_ptr + offset, size);
}

void *jit_region_write(JITRegion *region, size_t offset, const void *code, size_t code_size) {
    if (!region || offset + code_size > region->size) return NULL;
    memcpy((char *)region->rw_ptr + offset, code, code_size);
    sys_icache_invalidate((char *)region->rx_ptr + offset, code_size);
    return (char *)region->rx_ptr + offset;
}

static void sigtrap_handler(int sig, siginfo_t *info, void *context) {
    (void)sig; (void)info;
    ucontext_t *uc = (ucontext_t *)context;
    uc->uc_mcontext->__ss.__pc += 4;
    uc->uc_mcontext->__ss.__x[0] = 0;
}

void jit_install_trap_handler(void) {
    if (jit_check_debugged()) return;
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = sigtrap_handler;
    sigaction(SIGTRAP, &sa, NULL);
}

__attribute__((noinline, optnone))
void *jit26_prepare_region(void *addr, size_t len) {
    register void *x0 __asm__("x0") = addr;
    register size_t x1 __asm__("x1") = len;
    __asm__ volatile("mov x16, #1\n brk #0xf00d\n" : "+r"(x0) : "r"(x1) : "x16", "memory");
    return x0;
}

__attribute__((noinline, optnone))
void jit26_detach(void) {
    __asm__ volatile("mov x16, #0\n brk #0xf00d\n" ::: "x16", "memory");
}

bool jit_check_debugged(void) {
    uint32_t flags = 0;
    if (csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) != 0) return false;
    return (flags & CS_DEBUGGED) != 0;
}
