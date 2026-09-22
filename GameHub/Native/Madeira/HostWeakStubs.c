/* Weak stubs for deep symbols expected from Madeira host static libs.
 * Public API (wineserver_start, wine_process_start, fex_*, madeira_extract_*)
 * is provided by WineServerBridge.m / WineProcessBridge.m / FEXBridge.mm /
 * PrefixExtractor.c.
 */
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#if defined(__APPLE__)
#include <libkern/OSCacheControl.h>
#endif

volatile int ws_log_quiet = 0;

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

__attribute__((weak)) void wineserver_inject_client_fd(int fd) {
    fprintf(stderr, "[GameHub] wineserver_inject_client_fd(%d): libwineserver.a not linked\n", fd);
}

__attribute__((weak)) void winios_freeze_watch_start(void) {
    fprintf(stderr, "[GameHub] winios_freeze_watch_start: Winios.m not linked\n");
}

/* Symbols pulled in when force-loading libntdll_unix.a on iOS. */
__attribute__((weak)) const char wine_build[] = "GameHub-iOS Madeira host";
__attribute__((weak)) volatile int winios_phase = 0;

__attribute__((weak)) void win32u_unix_lib_init(void) {
    fprintf(stderr, "[GameHub] win32u_unix_lib_init: libwin32u_unix.a not linked\n");
}

/* unixlib dispatch tables — empty so ntdll unixlib lookups fail closed. */
__attribute__((weak)) void *bcrypt_unix_call_funcs[] = { NULL };
__attribute__((weak)) void *crypt32_unix_call_funcs[] = { NULL };
__attribute__((weak)) void *dwrite_unix_call_funcs[] = { NULL };
__attribute__((weak)) void *secur32_unix_call_funcs[] = { NULL };

#if defined(__APPLE__)
void __clear_cache(void *start, void *end) {
    if (!start || !end || end <= start) return;
    sys_icache_invalidate(start, (size_t)((char *)end - (char *)start));
}
#endif
