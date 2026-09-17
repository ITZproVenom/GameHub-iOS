#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int wine_process_start(const char *prefix_path);
int wine_process_start_exe(const char *prefix_path, const char *exe_path);
int wine_process_is_running(void);
int madeira_write_continue_flag(void);

/* extra_args: space-separated argv after the executable (may be NULL).
 * env_block: newline-separated KEY=VAL pairs (may be NULL). */
void wine_process_configure(const char *extra_args, const char *env_block);

#ifdef __cplusplus
}
#endif
