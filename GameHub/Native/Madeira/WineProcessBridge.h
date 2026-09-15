#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int wine_process_start(const char *prefix_path);
int wine_process_start_exe(const char *prefix_path, const char *exe_path);
int wine_process_is_running(void);
int madeira_write_continue_flag(void);

#ifdef __cplusplus
}
#endif
