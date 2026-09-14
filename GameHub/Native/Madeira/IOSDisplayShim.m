#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <pthread.h>
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

void madeira_display_set_layer(CAMetalLayer *layer) {
    pthread_mutex_lock(&g_lock);
    g_layer = layer;
    pthread_mutex_unlock(&g_lock);
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
static macdrv_metal_device my_create_metal_device(void) { return (macdrv_metal_device)(uintptr_t)0x1; }
static void my_release_metal_device(macdrv_metal_device d) { (void)d; }
static macdrv_metal_view my_view_create_metal_view(macdrv_view v, macdrv_metal_device d) {
    (void)d; return (macdrv_metal_view)v;
}
static macdrv_metal_layer my_view_get_metal_layer(macdrv_metal_view v) {
    (void)v;
    pthread_mutex_lock(&g_lock);
    CAMetalLayer *layer = g_layer;
    pthread_mutex_unlock(&g_lock);
    return (macdrv_metal_layer)layer;
}
static void my_view_release_metal_view(macdrv_metal_view v) { (void)v; }
static void my_on_main_thread(dispatch_block_t b) {
    if ([NSThread isMainThread]) b();
    else dispatch_sync(dispatch_get_main_queue(), b);
}
static void my_init_display_devices(BOOL force) { (void)force; }
static macdrv_window my_get_cocoa_window(HWND hwnd, BOOL require_on_screen) {
    (void)hwnd; (void)require_on_screen; return NULL;
}

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
