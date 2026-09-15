/* Weak stubs for deep symbols expected from Madeira host static libs.
 * Public API (wineserver_start, wine_process_start, fex_*, madeira_extract_*)
 * is provided by WineServerBridge.m / WineProcessBridge.m / FEXBridge.mm /
 * PrefixExtractor.c.
 *
 * Strong symbols here are only those the IPA-copied Madeira bridges reference
 * that are otherwise provided by libwineserver.a / Winios.m when those are linked.
 */
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

/* Defined here (strong) so Swift MadeiraBootSequence can set ws_log_quiet
 * even when the Madeira wineserver archive is not linked. */
volatile int ws_log_quiet = 0;

/* Weak definition so FEXBridge.mm can probe FEXCore without a hard link error. */
__attribute__((weak)) int fex_core_probe(void) {
    return 0;
}

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

__attribute__((weak)) void __wine_main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    fprintf(stderr, "[GameHub] __wine_main: libntdll_unix.a not linked\n");
}

__attribute__((weak)) void wine_log_set_file(const char *path) { (void)path; }
__attribute__((weak)) void wine_ui_log(const char *message) {
    if (message) fprintf(stderr, "%s\n", message);
}

__attribute__((weak)) uint64_t IosCbEntryLog[8] = {0};
__attribute__((weak)) uint64_t IosFfsBypassLog[8] = {0};
__attribute__((weak)) volatile uint64_t g_madeira_thr_count[16] = {0};
__attribute__((weak)) volatile uint64_t g_madeira_hot_count[64] = {0};
__attribute__((weak)) volatile uint64_t g_madeira_syscall_count[32] = {0};
__attribute__((weak)) volatile int g_madeira_ios_host = 1;

/* IPA workflow copies Madeira WineProcessBridge.m / IOSDisplayShim.m which
 * call these. Real implementations live in libwineserver.a and Winios.m;
 * weak fallbacks keep the unsigned IPA linking when those archives are absent. */
__attribute__((weak)) void wineserver_inject_client_fd(int fd) {
    fprintf(stderr, "[GameHub] wineserver_inject_client_fd(%d): libwineserver.a not linked\n", fd);
}

__attribute__((weak)) void winios_freeze_watch_start(void) {
    fprintf(stderr, "[GameHub] winios_freeze_watch_start: Winios.m not linked\n");
}

#ifdef __APPLE__
/* Return type is CAMetalLayer* in ObjC; void* is ABI-compatible here. */
__attribute__((weak)) void *winios_metal_layer_for_hwnd(void *hwnd) {
    (void)hwnd;
    return NULL;
}
#endif
