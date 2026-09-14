// WineProcessBridge.m - iOS-compatible Wine process bootstrap for GameHub
// Adapted from Madeira 97e2ce26. Calls strong __wine_main when libntdll_unix is linked;
// otherwise logs clearly and returns failure (no fake success).

#import <Foundation/Foundation.h>
#import <os/log.h>
#import <pthread.h>
#import <unistd.h>
#import <fcntl.h>
#import <sys/socket.h>
#import <setjmp.h>
#import <stdlib.h>
#import <errno.h>
#import <dirent.h>
#import <sys/stat.h>
#import <limits.h>
#import <string.h>

#include "WineProcessBridge.h"
#include "WineServerBridge.h"
#include "PrefixExtractor.h"
#include "FEXBridge.h"

_Thread_local jmp_buf wine_ios_exit_jmpbuf;
_Thread_local volatile int wine_ios_exit_code = 0;
_Thread_local pthread_t wine_ios_main_thread;
_Thread_local int wine_ios_exit_initialized = 0;

static os_log_t wine_proc_log(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.gamehub.emulator", "wine-proc"); });
    return log;
}

#define LOG(fmt, ...) os_log(wine_proc_log(), "[WineProc] " fmt, ##__VA_ARGS__)

// Strong symbol when libntdll_unix.a is force_loaded; weak stub otherwise.
extern void __wine_main(int argc, char *argv[]) __attribute__((weak));
extern void wine_log_set_file(const char *path) __attribute__((weak));

static pthread_t g_wine_thread;
static volatile int g_wine_running = 0;
static char *g_prefix_path = NULL;

void madeira_seed_prefix_if_needed(const char *prefix_path) {
    @autoreleasepool {
        if (!prefix_path) return;
        NSString *prefix = [NSString stringWithUTF8String:prefix_path];
        NSString *stamp = [prefix stringByAppendingPathComponent:@".update-timestamp"];
        NSFileManager *fm = [NSFileManager defaultManager];

        [fm createDirectoryAtPath:prefix withIntermediateDirectories:YES attributes:nil error:nil];

        if (![fm fileExistsAtPath:stamp]) {
            // Prefer Runtime/ subdir (force-embedded by IPA packaging)
            NSString *tgz = [[NSBundle mainBundle] pathForResource:@"prefix-template" ofType:@"tar.gz" inDirectory:@"Runtime"];
            if (!tgz) tgz = [[NSBundle mainBundle] pathForResource:@"prefix-template" ofType:@"tar.gz"];
            if (!tgz) {
                LOG("prefix-template.tar.gz missing from bundle!");
            } else {
                LOG("Seeding prefix from %{public}s", tgz.UTF8String);
                if (madeira_extract_prefix_tgz(tgz.UTF8String, prefix_path) != 0) {
                    LOG("prefix extraction FAILED");
                } else {
                    LOG("prefix seeded to %{public}s", prefix_path);
                    [@"seeded" writeToFile:stamp atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
            }
        }

        // (Re)create dosdevices/c: -> ../drive_c
        NSString *dosdev = [prefix stringByAppendingPathComponent:@"dosdevices"];
        [fm createDirectoryAtPath:dosdev withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *cLink = [dosdev stringByAppendingPathComponent:@"c:"];
        [fm removeItemAtPath:cLink error:nil];
        [fm createSymbolicLinkAtPath:cLink withDestinationPath:@"../drive_c" error:nil];
    }
}

static void *wine_process_thread(void *arg) {
    @autoreleasepool {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        LOG("Wine process thread started");

        madeira_seed_prefix_if_needed(g_prefix_path);

        setenv("WINEPREFIX", g_prefix_path, 1);
        setenv("HOME", g_prefix_path, 1);
        setenv("WINELOADERNOEXEC", "1", 1);

        {
            NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
            NSString *rt = [bundlePath stringByAppendingPathComponent:@"Runtime"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:rt]) {
                setenv("WINEDLLPATH", rt.UTF8String, 1);
                LOG("WINEDLLPATH=%{public}s", rt.UTF8String);
            } else {
                setenv("WINEDLLPATH", bundlePath.UTF8String, 1);
                LOG("WINEDLLPATH=%{public}s (no Runtime/)", bundlePath.UTF8String);
            }
        }

        // Publish JIT write offset for xtajit64 if FEX is present
        {
            int64_t off = fex_get_jit_write_offset();
            if (off != 0) {
                char buf[32];
                snprintf(buf, sizeof(buf), "%lld", (long long)off);
                setenv("MADEIRA_JIT_WRITE_OFFSET", buf, 1);
            }
        }

        if (__wine_main == NULL) {
            LOG("FATAL: __wine_main is NULL — libntdll_unix.a not linked. Cannot start Wine process.");
            g_wine_running = 0;
            return NULL;
        }

        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *logPath = [docs stringByAppendingPathComponent:@"madeira-wine.log"];
        if (wine_log_set_file) {
            wine_log_set_file(logPath.UTF8String);
        }

        char *argv[] = { "wine", "explorer.exe", NULL };
        int argc = 2;

        LOG("Calling __wine_main (explorer.exe) ...");
        wine_ios_exit_initialized = 1;
        wine_ios_main_thread = pthread_self();
        if (setjmp(wine_ios_exit_jmpbuf) == 0) {
            __wine_main(argc, argv);
        }
        LOG("__wine_main returned / longjmp exit_code=%d", wine_ios_exit_code);
        g_wine_running = 0;
    }
    return NULL;
}

int wine_process_start(const char *prefix_path) {
    if (g_wine_running) {
        LOG("Wine process already running");
        return 0;
    }
    if (!prefix_path) return -1;

    if (g_prefix_path) free(g_prefix_path);
    g_prefix_path = strdup(prefix_path);

    // Ensure wineserver is up first
    if (wineserver_is_running() == 0) {
        LOG("wineserver not running — starting it");
        if (wineserver_start(prefix_path) != 0) {
            LOG("wineserver_start failed");
            return -1;
        }
        for (int i = 0; i < 50; i++) {
            if (wineserver_is_running()) break;
            usleep(50000);
        }
        if (!wineserver_is_running()) {
            LOG("wineserver never became ready");
            return -1;
        }
    }

    g_wine_running = 1;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE, 0);
    int ret = pthread_create(&g_wine_thread, &attr, wine_process_thread, NULL);
    pthread_attr_destroy(&attr);
    if (ret != 0) {
        LOG("pthread_create wine_process failed: %d", ret);
        g_wine_running = 0;
        return -1;
    }
    LOG("Wine process thread created");
    return 0;
}

int wine_process_is_running(void) {
    return g_wine_running;
}

int madeira_write_continue_flag(void) {
    if (!g_prefix_path) return -1;
    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:g_prefix_path];
        path = [path stringByAppendingPathComponent:@"drive_c/madeira-continue.flag"];
        return [@"1" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil] ? 0 : -1;
    }
}
