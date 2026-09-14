/* Weak stubs for deep symbols expected from Madeira host static libs.
 * Public API (wineserver_start, wine_process_start, fex_*, madeira_extract_*)
 * is now provided by the strong implementations in WineServerBridge.m /
 * WineProcessBridge.m / FEXBridge.mm / PrefixExtractor.c.
 */
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

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
/* g_wineserver_should_stop is defined strongly in WineServerBridge.m */

__attribute__((weak)) void __wine_main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    fprintf(stderr, "[GameHub] __wine_main: libntdll_unix.a not linked\n");
}

__attribute__((weak)) void wine_log_set_file(const char *path) { (void)path; }
__attribute__((weak)) void wine_ui_log(const char *message) {
    if (message) fprintf(stderr, "%s\n", message);
}

/* Optional FEX-related counters / logs that FEXCore may reference */
__attribute__((weak)) uint64_t IosCbEntryLog[8] = {};
__attribute__((weak)) uint64_t IosFfsBypassLog[8] = {};
__attribute__((weak)) volatile uint64_t g_madeira_thr_count[16] = {};
__attribute__((weak)) volatile uint64_t g_madeira_hot_count[64] = {};
__attribute__((weak)) volatile uint64_t g_madeira_syscall_count[32] = {};
__attribute__((weak)) volatile int g_madeira_ios_host = 1;
