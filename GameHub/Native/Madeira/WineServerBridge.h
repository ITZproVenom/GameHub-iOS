// WineServerBridge.h - Run Wine's wineserver as a thread on iOS
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int wineserver_start(const char *prefix_path);
int wineserver_is_running(void);
void wineserver_stop(void);
void wineserver_inject_client_fd(int fd);
extern volatile int ws_log_quiet;

#ifdef __cplusplus
}
#endif
