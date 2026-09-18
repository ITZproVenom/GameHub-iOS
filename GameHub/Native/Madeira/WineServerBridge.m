// WineServerBridge.m - Run Wine's wineserver as a thread on iOS
// Vendored from Madeira 97e2ce26e6dc9e4a38976f3b5deb9272d64558eb for GameHub-iOS.

#import <Foundation/Foundation.h>
#import <os/log.h>
#import <sys/stat.h>
#import <pthread.h>
#import <stdarg.h>
#import <fcntl.h>
#import <unistd.h>

#include "WineServerBridge.h"
#include <sys/time.h>

static FILE *g_ws_bridge_log = NULL;
static pthread_mutex_t g_ws_bridge_log_mutex = PTHREAD_MUTEX_INITIALIZER;

static void wine_log_msg_impl(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void wine_log_msg_impl(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    os_log(OS_LOG_DEFAULT, "%s", buf);
    extern void wine_ui_log(const char *message);
    wine_ui_log(buf);
    pthread_mutex_lock(&g_ws_bridge_log_mutex);
    if (g_ws_bridge_log) {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        struct tm tm;
        localtime_r(&tv.tv_sec, &tm);
        fprintf(g_ws_bridge_log, "[%02d:%02d:%02d.%03d] %s\n",
                tm.tm_hour, tm.tm_min, tm.tm_sec, (int)(tv.tv_usec/1000), buf);
        fflush(g_ws_bridge_log);
    }
    pthread_mutex_unlock(&g_ws_bridge_log_mutex);
}

#define wine_log_msg(fmt, ...) wine_log_msg_impl("[Wine] " fmt, ##__VA_ARGS__)

extern int wineserver_main(int argc, char *argv[]);
extern void wineserver_log_set_file(const char *path);
extern void wineserver_set_nls_dir(const char *path);

void fatal_error( const char *err, ... ) {
    va_list args;
    char buf[1024];
    va_start(args, err);
    vsnprintf(buf, sizeof(buf), err, args);
    va_end(args);
    wine_log_msg_impl("[Wine] FATAL: %s", buf);
    pthread_exit(NULL);
}

extern int foreground;
extern int debug_level;

volatile int g_wineserver_should_stop = 0;

static pthread_t g_wineserver_thread;
static volatile int g_wineserver_running = 0;
static char *g_prefix_path = NULL;

static void *wineserver_thread_func(void *arg) {
    (void)arg;
    @autoreleasepool {
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *logPath = [docs stringByAppendingPathComponent:@"madeira-log.txt"];
        pthread_mutex_lock(&g_ws_bridge_log_mutex);
        if (g_ws_bridge_log) fclose(g_ws_bridge_log);
        g_ws_bridge_log = fopen(logPath.UTF8String, "a");
        pthread_mutex_unlock(&g_ws_bridge_log_mutex);
        wineserver_log_set_file(logPath.UTF8String);

        {
            int logfd = open(logPath.UTF8String, O_WRONLY | O_CREAT | O_APPEND, 0644);
            if (logfd >= 0) {
                dup2(logfd, STDERR_FILENO);
                close(logfd);
            }
        }

        extern void ws_log(const char *fmt, ...);
        ws_log("[wineserver-bridge] ws_log test - log file set up OK");

        wine_log_msg("Wineserver thread started");

        setenv("WINEPREFIX", g_prefix_path, 1);
        setenv("HOME", g_prefix_path, 1);

        wine_log_msg("WINEPREFIX=%s", g_prefix_path);
        mkdir(g_prefix_path, 0755);

        NSString *nlsDir = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"nls"];
        NSString *nlsRuntime = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Runtime/nls"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:nlsRuntime]) {
            nlsDir = nlsRuntime;
        }
        wineserver_set_nls_dir(nlsDir.UTF8String);
        wine_log_msg("NLS dir=%s", nlsDir.UTF8String);

        foreground = 1;

        char *argv[] = { "wineserver", "--foreground", NULL };
        int argc = 2;

        wine_log_msg("Calling wineserver_main...");
        int ret = wineserver_main(argc, argv);
        wine_log_msg("wineserver_main returned: %d", ret);

        g_wineserver_running = 0;
    }
    return NULL;
}

int wineserver_start(const char *prefix_path) {
    if (g_wineserver_running) {
        wine_log_msg("Wineserver already running");
        return 0;
    }

    if (g_prefix_path) free(g_prefix_path);
    g_prefix_path = strdup(prefix_path);

    wine_log_msg("Starting wineserver with prefix: %s", prefix_path);

    {
        extern void madeira_seed_prefix_if_needed(const char *prefix_path);
        madeira_seed_prefix_if_needed(prefix_path);
    }

    g_wineserver_running = 1;
    g_wineserver_should_stop = 0;

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE, 0);

    int ret = pthread_create(&g_wineserver_thread, &attr, wineserver_thread_func, NULL);
    pthread_attr_destroy(&attr);
    if (ret != 0) {
        wine_log_msg("Failed to create wineserver thread: %d", ret);
        g_wineserver_running = 0;
        return -1;
    }

    wine_log_msg("Wineserver thread created");
    return 0;
}

int wineserver_is_running(void) {
    return g_wineserver_running;
}

void wineserver_stop(void) {
    wine_log_msg("Wineserver stop requested");
    g_wineserver_should_stop = 1;
    pthread_t t = g_wineserver_thread;
    if (t) {
        wine_log_msg("Joining wineserver thread...");
        pthread_join(t, NULL);
        wine_log_msg("Wineserver thread joined");
        g_wineserver_thread = NULL;
    }
    g_wineserver_running = 0;
}
