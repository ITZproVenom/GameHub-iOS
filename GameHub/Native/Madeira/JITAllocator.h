#ifndef JIT_ALLOCATOR_H
#define JIT_ALLOCATOR_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct JITRegion JITRegion;

JITRegion *jit_region_create(size_t size);
void jit_region_destroy(JITRegion *region);
bool jit_make_region_no_footprint(void *addr, size_t size, const char *label);
void *jit_region_rw_ptr(JITRegion *region);
void *jit_region_rx_ptr(JITRegion *region);
size_t jit_region_size(JITRegion *region);
void *jit_region_write(JITRegion *region, size_t offset, const void *code, size_t code_size);
void jit_region_invalidate(JITRegion *region, size_t offset, size_t size);
bool jit_check_debugged(void);
void jit_install_trap_handler(void);
void *jit26_prepare_region(void *addr, size_t len);
void jit26_detach(void);

typedef void (*jit_log_callback_t)(const char *message);
void jit_set_log_callback(jit_log_callback_t callback);

#ifdef __cplusplus
}
#endif

#endif
