#ifndef JIT_ALLOCATOR_H
#define JIT_ALLOCATOR_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to a dual-mapped JIT region
typedef struct JITRegion JITRegion;

// Create a dual-mapped JIT region of the given size.
// Returns NULL on failure. Size is rounded up to page boundary.
JITRegion *jit_region_create(size_t size);

// Destroy a JIT region and unmap both views.
void jit_region_destroy(JITRegion *region);

/// Mark an already-mapped range jetsam-exempt (VM_LEDGER_FLAG_NO_FOOTPRINT).
bool jit_make_region_no_footprint(void *addr, size_t size, const char *label);

// Get the RW (writable) pointer. Write generated code here.
void *jit_region_rw_ptr(JITRegion *region);

// Get the RX (executable) pointer. Execute code from here.
void *jit_region_rx_ptr(JITRegion *region);

// Get the total size of the region.
size_t jit_region_size(JITRegion *region);

// Write code into the region at offset.
void *jit_region_write(JITRegion *region, size_t offset, const void *code, size_t code_size);

// Invalidate instruction cache for a range.
void jit_region_invalidate(JITRegion *region, size_t offset, size_t size);

// Returns true if CS_DEBUGGED / P_TRACED is set (JIT allowed).
bool jit_check_debugged(void);

// Install SIGBUS/SIGSEGV trap handler used by dual-map path.
void jit_install_trap_handler(void);

// Test that dual mapping works and RX pages have execute permission.
bool jit_test_mapping(void);

// Full JIT test. Returns 42 on success, -1 on failure, -2 if no debugger.
int64_t jit_test_execute(void);

// Strategy 2 only (debugger alloc).
int64_t jit_test_execute_strategy2(void);

// W^X probe for research / diagnostics.
void jit_wx_probe(void);

// Runtime RX->RW distance of the dual-mapped pool (for FEX / xtajit64).
int64_t jit_get_write_offset(void);

// Log callback
typedef void (*jit_log_callback_t)(const char *message);
void jit_set_log_callback(jit_log_callback_t callback);

#ifdef __cplusplus
}
#endif

#endif // JIT_ALLOCATOR_H
