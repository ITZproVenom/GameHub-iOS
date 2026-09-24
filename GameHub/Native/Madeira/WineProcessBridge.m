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
static char *g_extra_args = NULL;
static char *g_env_block = NULL;

static void madeira_install_pe_runtime(NSFileManager *fm, NSString *prefix) {
    NSString *sys32 = [prefix stringByAppendingPathComponent:@"drive_c/windows/system32"];
    NSString *syswow = [prefix stringByAppendingPathComponent:@"drive_c/windows/syswow64"];
    [fm createDirectoryAtPath:sys32 withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:syswow withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *bundle = [[NSBundle mainBundle] bundlePath];
    NSArray<NSString *> *peRoots = @[
        [bundle stringByAppendingPathComponent:@"Runtime/arm64ec-windows"],
        [bundle stringByAppendingPathComponent:@"Runtime/aarch64-windows"],
        [bundle stringByAppendingPathComponent:@"Runtime"],
    ];

    NSUInteger copied = 0;
    for (NSString *root in peRoots) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:root isDirectory:&isDir] || !isDir) continue;
        NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *name in entries) {
            NSString *ext = name.pathExtension.lowercaseString;
            if (![ext isEqualToString:@"dll"] && ![ext isEqualToString:@"exe"] && ![ext isEqualToString:@"drv"]) {
                continue;
            }
            NSString *src = [root stringByAppendingPathComponent:name];
            NSString *dst = [sys32 stringByAppendingPathComponent:name];
            if ([fm fileExistsAtPath:dst]) {
                NSDictionary *sa = [fm attributesOfItemAtPath:src error:nil];
                NSDictionary *da = [fm attributesOfItemAtPath:dst error:nil];
                unsigned long long ss = [sa[NSFileSize] unsignedLongLongValue];
                unsigned long long ds = [da[NSFileSize] unsignedLongLongValue];
                if (ss == ds && ss > 0) continue;
                [fm removeItemAtPath:dst error:nil];
            }
            NSError *err = nil;
            if ([fm copyItemAtPath:src toPath:dst error:&err]) {
                copied++;
            } else if (err) {
                LOG("PE copy %{public}s failed: %{public}@", name, err);
            }
        }
    }

    NSString *nlsSrc = [bundle stringByAppendingPathComponent:@"Runtime/nls"];
    NSString *nlsDst = [prefix stringByAppendingPathComponent:@"nls"];
    if ([fm fileExistsAtPath:nlsSrc] && ![fm fileExistsAtPath:nlsDst]) {
        [fm copyItemAtPath:nlsSrc toPath:nlsDst error:nil];
    }

    NSString *dosdev = [prefix stringByAppendingPathComponent:@"dosdevices"];
    [fm createDirectoryAtPath:dosdev withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *zLink = [dosdev stringByAppendingPathComponent:@"z:"];
    [fm removeItemAtPath:zLink error:nil];
    [fm createSymbolicLinkAtPath:zLink
             withDestinationPath:[bundle stringByAppendingPathComponent:@"Runtime"]
                           error:nil];

    LOG("PE runtime installed into system32 (%lu files)", (unsigned long)copied);
}

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

        madeira_install_pe_runtime(fm, prefix);
    }
}
