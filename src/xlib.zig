const std = @import("std");
//TODO we may want to return to this idea, call everything from c then just build a wrapper around the event struct
// const c = @cImport({
//     @cInclude("X11/Xlib.h");
// });

pub const Display = struct {};
pub const Window = struct {};
//TODO might need to convert bool to int type
pub const XAnyEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
};
//TODO This might be wrong
pub const Time = u64;

pub const XKeyEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    keycode: u32,
    same_screen: bool,
};
pub const XEvent = struct {
    type: i32,
    xany: XAnyEvent,
    xkey: XKeyEvent,
    xbutton: XButtonEvent,
    xmotion: XMotionEvent,
    xcrossing: XCrossingEvent,
    xfocus: XFocusChangeEvent,
    xexpose: XExposeEvent,
    xgraphicsexpose: XGraphicsExposeEvent,
    xnoexpose: XNoExposeEvent,
    xvisibility: XVisibilityEvent,
    xcreatewindow: XCreateWindowEvent,
    xdestroywindow: XDestroyWindowEvent,
    xunmap: XUnmapEvent,
    xmap: XMapEvent,
    xmaprequest: XMapRequestEvent,
    xreparent: XReparentEvent,
    xconfigure: XConfigureEvent,
    xgravity: XGravityEvent,
    xresizerequest: XResizeRequestEvent,
    xconfigurerequest: XConfigureRequestEvent,
    xcirculate: XCirculateEvent,
    xcirculaterequest: XCirculateRequestEvent,
    xproperty: XPropertyEvent,
    xselectionclear: XSelectionClearEvent,
    xselectionrequest: XSelectionRequestEvent,
    xselection: XSelectionEvent,
    xcolormap: XColormapEvent,
    xclient: XClientMessageEvent,
    xmapping: XMappingEvent,
    xerror: XErrorEvent,
    xkeymap: XKeymapEvent,
    pad: [24]i32,
};

pub extern fn XOpenDisplay(display_name: ?[*:0]const u8) *Display;
pub extern fn XSelectInput(display: *Display, w: Window, event_mask: c_int) c_int;
pub extern fn XNextEvent(display: *Display, event_return: *XEvent) c_int;

//pub extern "C" fn XSelectInput(display: *Display, root_window: Window) i32;

test "open" {
    const display: *Display = XOpenDisplay(null);
    std.debug.print("function success\n", .{});
    std.debug.print("display {any}\n", .{display});
}
