// WineProcessBridge.m - iOS-compatible Wine process bootstrap for GameHub
// Adapted from Madeira 97e2ce26. Calls strong __wine_main when libntdll_unix is linked;
// otherwise logs clearly and returns failure (no fake success).

#import <Foundation/Foundation.h>
#import <os/log.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
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

extern void __wine_main(int argc, char *argv[]) __attribute__((weak));
extern void wine_log_set_file(const char *path) __attribute__((weak));
extern void wineserver_inject_client_fd(int fd) __attribute__((weak));
extern void winios_freeze_watch_start(void) __attribute__((weak));

static pthread_t g_wine_thread;
static volatile int g_wine_running = 0;
static char *g_prefix_path = NULL;
static char *g_exe_winpath = NULL;

void madeira_seed_prefix_if_needed(const char *prefix_path) {
    @autoreleasepool {
        if (!prefix_path) return;
        NSString *prefix = [NSString stringWithUTF8String:prefix_path];
        NSString *stamp = [prefix stringByAppendingPathComponent:@".update-timestamp"];
        NSFileManager *fm = [NSFileManager defaultManager];

        [fm createDirectoryAtPath:prefix withIntermediateDirectories:YES attributes:nil error:nil];

        if (![fm fileExistsAtPath:stamp]) {
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
        /* DXMT is the D3D11/12 → Metal path. Prefer it over wined3d. */
        setenv("WINEDLLOVERRIDES", "d3d11,dxgi,d3d12,d3d10,d3d10_1,d3d10core=n,b", 1);
        setenv("DXMT_CONFIG", "d3d11.presentInterval=0", 1);

        {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
            NSMutableArray<NSString *> *dllDirs = [NSMutableArray array];
            NSArray<NSString *> *candidates = @[
                [bundlePath stringByAppendingPathComponent:@"Runtime/arm64ec-windows"],
                [bundlePath stringByAppendingPathComponent:@"Runtime/aarch64-windows"],
                [bundlePath stringByAppendingPathComponent:@"Runtime"],
                bundlePath,
            ];
            for (NSString *p in candidates) {
                if ([fm fileExistsAtPath:p]) {
                    [dllDirs addObject:p];
                }
            }
            NSString *joined = [dllDirs componentsJoinedByString:@":"];
            setenv("WINEDLLPATH", joined.UTF8String, 1);
            LOG("WINEDLLPATH=%{public}s", joined.UTF8String);
        }

        {
            /* Activate the audio session so Madeira's RemoteIO path can open. */
            NSError *audioErr = nil;
            AVAudioSession *session = [AVAudioSession sharedInstance];
            [session setCategory:AVAudioSessionCategoryPlayback
                            mode:AVAudioSessionModeDefault
                         options:AVAudioSessionCategoryOptionMixWithOthers
                           error:&audioErr];
            [session setActive:YES error:&audioErr];
            if (audioErr) {
                LOG("AVAudioSession: %{public}@", audioErr);
            }
        }

        {
            int64_t off = fex_get_jit_write_offset();
            if (off != 0) {
                char buf[32];
                snprintf(buf, sizeof(buf), "%lld", (long long)off);
                setenv("MADEIRA_JIT_WRITE_OFFSET", buf, 1);
            }
        }

        if (winios_freeze_watch_start) {
            winios_freeze_watch_start();
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

        const char *target = (g_exe_winpath && g_exe_winpath[0]) ? g_exe_winpath : "explorer.exe";
        char *argv[] = { "wine", (char *)target, NULL };
        int argc = 2;

        LOG("Calling __wine_main (%{public}s) ...", target);
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

static int wine_process_start_common(const char *prefix_path) {
    if (g_wine_running) {
        LOG("Wine process already running");
        return 0;
    }
    if (!prefix_path) return -1;

    if (g_prefix_path) free(g_prefix_path);
    g_prefix_path = strdup(prefix_path);

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

int wine_process_start(const char *prefix_path) {
    return wine_process_start_common(prefix_path);
}

int wine_process_start_exe(const char *prefix_path, const char *exe_path) {
    if (g_exe_winpath) {
        free(g_exe_winpath);
        g_exe_winpath = NULL;
    }
    if (exe_path && exe_path[0]) {
        g_exe_winpath = strdup(exe_path);
        LOG("wine_process_start_exe target=%{public}s", exe_path);
    }
    return wine_process_start_common(prefix_path);
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
