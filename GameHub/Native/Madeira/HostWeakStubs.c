/* Weak stubs — overridden when Madeira static libs + real bridges are linked. */
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "WineServerBridge.h"
#include "WineProcessBridge.h"
#include "FEXBridge.h"
#include "PrefixExtractor.h"

/* ---- Public API (overridden by WineServerBridge.m / WineProcessBridge.m) ---- */

__attribute__((weak)) int wineserver_start(const char *prefix_path) {
    (void)prefix_path;
    fprintf(stderr, "[GameHub] wineserver_start: libwineserver.a / WineServerBridge not linked\n");
    return -1;
}
__attribute__((weak)) int wineserver_is_running(void) { return 0; }
__attribute__((weak)) void wineserver_stop(void) {}
__attribute__((weak)) void wineserver_inject_client_fd(int fd) { (void)fd; }
__attribute__((weak)) volatile int ws_log_quiet = 0;

__attribute__((weak)) int wine_process_start(const char *prefix_path) {
    (void)prefix_path;
    fprintf(stderr, "[GameHub] wine_process_start: libntdll_unix.a / WineProcessBridge not linked\n");
    return -1;
}
__attribute__((weak)) int wine_process_is_running(void) { return 0; }
__attribute__((weak)) int madeira_write_continue_flag(void) { return -1; }

__attribute__((weak)) bool fex_initialize(void) {
    fprintf(stderr, "[GameHub] fex_initialize: libFEXCore.a not linked\n");
    return false;
}
__attribute__((weak)) void fex_shutdown(void) {}
__attribute__((weak)) int64_t fex_test_execute(void) { return -1; }
__attribute__((weak)) void fex_set_log_callback(fex_log_callback_t callback) { (void)callback; }
__attribute__((weak)) int64_t fex_get_jit_write_offset(void) { return 0; }

/* PrefixExtractor.c provides a strong madeira_extract_prefix_tgz; keep weak fallback */
__attribute__((weak)) int madeira_extract_prefix_tgz(const char *tgz_path, const char *dest_dir) {
    (void)tgz_path; (void)dest_dir;
    fprintf(stderr, "[GameHub] madeira_extract_prefix_tgz: PrefixExtractor not linked\n");
    return -1;
}

/* ---- Symbols expected from host static libs (weak until force_load) ---- */

__attribute__((weak)) int wineserver_main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    fprintf(stderr, "[GameHub] wineserver_main: libwineserver.a not linked\n");
    return -1;
}

__attribute__((weak)) void wineserver_log_set_file(const char *path) { (void)path; }
__attribute__((weak)) void wineserver_set_nls_dir(const char *path) { (void)path; }
__attribute__((weak)) void ws_log(const char *fmt, ...) { (void)fmt; }

__attribute__((weak)) int foreground = 1;
__attribute__((weak)) int debug_level = 0;
__attribute__((weak)) volatile int g_wineserver_should_stop = 0;

__attribute__((weak)) void __wine_main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    fprintf(stderr, "[GameHub] __wine_main: libntdll_unix.a not linked\n");
}

__attribute__((weak)) void wine_log_set_file(const char *path) { (void)path; }
__attribute__((weak)) void wine_ui_log(const char *message) {
    if (message) fprintf(stderr, "%s\n", message);
}
