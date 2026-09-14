/* Weak stubs — overridden when Madeira static libs are linked. */
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "WineServerBridge.h"
#include "WineProcessBridge.h"
#include "FEXBridge.h"
#include "PrefixExtractor.h"

__attribute__((weak)) int wineserver_start(const char *prefix_path) {
    (void)prefix_path;
    fprintf(stderr, "[GameHub] wineserver_start: libwineserver.a not linked\n");
    return -1;
}
__attribute__((weak)) int wineserver_is_running(void) { return 0; }
__attribute__((weak)) void wineserver_stop(void) {}
__attribute__((weak)) void wineserver_inject_client_fd(int fd) { (void)fd; }
__attribute__((weak)) volatile int ws_log_quiet = 0;

__attribute__((weak)) int wine_process_start(const char *prefix_path) {
    (void)prefix_path;
    fprintf(stderr, "[GameHub] wine_process_start: Wine unix host not linked\n");
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

__attribute__((weak)) int madeira_extract_prefix_tgz(const char *tgz_path, const char *dest_dir) {
    (void)tgz_path; (void)dest_dir;
    fprintf(stderr, "[GameHub] madeira_extract_prefix_tgz: PrefixExtractor.o not linked\n");
    return -1;
}
