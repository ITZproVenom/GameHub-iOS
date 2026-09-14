#ifndef FEX_BRIDGE_H
#define FEX_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool fex_initialize(void);
void fex_shutdown(void);
int64_t fex_test_execute(void);

typedef void (*fex_log_callback_t)(const char *message);
void fex_set_log_callback(fex_log_callback_t callback);
int64_t fex_get_jit_write_offset(void);

#ifdef __cplusplus
}
#endif

#endif
