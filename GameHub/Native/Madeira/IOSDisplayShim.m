// IOSDisplayShim.m — iOS stand-in for Wine's mac driver, used by DXMT.
// Aligned with Madeira 97e2ce26 app/Madeira/IOSDisplayShim.m.
// DXMT looks up this API via dlsym(RTLD_DEFAULT, "macdrv_functions").
// `used` + visibility(default) are required so Release -dead_strip keeps the table.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include "IOSDisplayShim.h"

typedef struct macdrv_opaque_metal_device *macdrv_metal_device;
typedef struct macdrv_opaque_metal_view   *macdrv_metal_view;
typedef struct macdrv_opaque_metal_layer  *macdrv_metal_layer;
typedef struct macdrv_opaque_view         *macdrv_view;
typedef struct macdrv_opaque_window       *macdrv_window;
typedef struct opaque_HWND                *HWND;

struct macdrv_win_data {
    HWND hwnd;
    macdrv_window cocoa_window;
    macdrv_view cocoa_view;
    macdrv_view client_cocoa_view;
};

struct macdrv_functions_t {
    void (*macdrv_init_display_devices)(BOOL);
    struct macdrv_win_data *(*get_win_data)(HWND hwnd);
    void (*release_win_data)(struct macdrv_win_data *data);
    macdrv_window (*macdrv_get_cocoa_window)(HWND hwnd, BOOL require_on_screen);
    macdrv_metal_device (*macdrv_create_metal_device)(void);
    void (*macdrv_release_metal_device)(macdrv_metal_device d);
    macdrv_metal_view (*macdrv_view_create_metal_view)(macdrv_view v, macdrv_metal_device d);
    macdrv_metal_layer (*macdrv_view_get_metal_layer)(macdrv_metal_view v);
    void (*macdrv_view_release_metal_view)(macdrv_metal_view v);
    void (*on_main_thread)(dispatch_block_t b);
};

static CAMetalLayer *g_layer = nil;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static _Atomic uint64_t g_present_count = 0;

void madeira_display_set_layer(CAMetalLayer *layer) {
    pthread_mutex_lock(&g_lock);
    g_layer = layer;
    pthread_mutex_unlock(&g_lock);
    fprintf(stderr, "[madeira-display] layer registered %p drawable=%.0fx%.0f\n",
            (__bridge void *)layer,
            layer ? layer.drawableSize.width : 0,
            layer ? layer.drawableSize.height : 0);
}

void madeira_note_present(void) {
    atomic_fetch_add_explicit(&g_present_count, 1, memory_order_relaxed);
}

__attribute__((used, visibility("default")))
uint64_t madeira_get_present_count(void) {
    return atomic_load_explicit(&g_present_count, memory_order_relaxed);
}

static struct macdrv_win_data g_fake_win_data = {
    .hwnd = NULL,
    .cocoa_window = NULL,
    .cocoa_view = (macdrv_view)(uintptr_t)0x1,
    .client_cocoa_view = (macdrv_view)(uintptr_t)0x1,
};

static struct macdrv_win_data *my_get_win_data(HWND hwnd) {
    g_fake_win_data.hwnd = hwnd;
    g_fake_win_data.client_cocoa_view = (macdrv_view)hwnd;
    return &g_fake_win_data;
}

static void my_release_win_data(struct macdrv_win_data *data) { (void)data; }

static int madeira_desktop_mode(void) {
    static int desk = -1;
    if (desk < 0) {
        const char *d = getenv("MADEIRA_DESKTOP");
        desk = d && *d == '1';
    }
    return desk;
}

CAMetalLayer *winios_metal_layer_for_hwnd(void *hwnd) {
    (void)hwnd;
    pthread_mutex_lock(&g_lock);
    CAMetalLayer *layer = g_layer;
    pthread_mutex_unlock(&g_lock);
    return layer;
}

static macdrv_metal_device my_create_metal_device(void) {
    return (macdrv_metal_device)(uintptr_t)0x1;
}
static void my_release_metal_device(macdrv_metal_device d) { (void)d; }

static macdrv_metal_view my_view_create_metal_view(macdrv_view v, macdrv_metal_device d) {
    (void)d;
    CAMetalLayer *layer = nil;
    if (madeira_desktop_mode()) {
        layer = winios_metal_layer_for_hwnd((void *)v);
    } else {
        pthread_mutex_lock(&g_lock);
        layer = g_layer;
        pthread_mutex_unlock(&g_lock);
    }
    if (!layer) {
        NSLog(@"[madeira-display] view_create_metal_view called before layer registered hwnd=%p", (void *)v);
        return NULL;
    }
    fprintf(stderr, "[madeira-display] metal view hwnd=%p layer=%p\n", (void *)v, (__bridge void *)layer);
    return (macdrv_metal_view)CFBridgingRetain(layer);
}

static macdrv_metal_layer my_view_get_metal_layer(macdrv_metal_view v) {
    return (macdrv_metal_layer)v;
}

static void my_view_release_metal_view(macdrv_metal_view v) {
    if (v) CFBridgingRelease((CFTypeRef)v);
}

static void my_on_main_thread(dispatch_block_t b) {
    if ([NSThread isMainThread]) b();
    else dispatch_async(dispatch_get_main_queue(), b);
}

static void my_init_display_devices(BOOL force) { (void)force; }
static macdrv_window my_get_cocoa_window(HWND hwnd, BOOL require_on_screen) {
    (void)hwnd; (void)require_on_screen; return NULL;
}

__attribute__((used, visibility("default")))
struct macdrv_functions_t macdrv_functions = {
    .macdrv_init_display_devices = my_init_display_devices,
    .get_win_data = my_get_win_data,
    .release_win_data = my_release_win_data,
    .macdrv_get_cocoa_window = my_get_cocoa_window,
    .macdrv_create_metal_device = my_create_metal_device,
    .macdrv_release_metal_device = my_release_metal_device,
    .macdrv_view_create_metal_view = my_view_create_metal_view,
    .macdrv_view_get_metal_layer = my_view_get_metal_layer,
    .macdrv_view_release_metal_view = my_view_release_metal_view,
    .on_main_thread = my_on_main_thread,
};

__attribute__((used, visibility("default")))
struct macdrv_win_data *get_win_data(HWND hwnd) { return my_get_win_data(hwnd); }

__attribute__((used, visibility("default")))
void release_win_data(struct macdrv_win_data *data) { my_release_win_data(data); }

__attribute__((used, visibility("default")))
macdrv_metal_view macdrv_view_create_metal_view(macdrv_view v, macdrv_metal_device d) {
    return my_view_create_metal_view(v, d);
}

__attribute__((used, visibility("default")))
macdrv_metal_layer macdrv_view_get_metal_layer(macdrv_metal_view v) {
    return my_view_get_metal_layer(v);
}

__attribute__((used, visibility("default")))
void macdrv_view_release_metal_view(macdrv_metal_view v) {
    my_view_release_metal_view(v);
}
