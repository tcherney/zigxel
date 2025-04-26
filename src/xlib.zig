const std = @import("std");
//TODO we may want to return to this idea, call everything from c then just build a wrapper around the event struct
// const c = @cImport({
//     @cInclude("X11/Xlib.h");
// });

pub const Display = struct {};
pub const Window = struct {};
pub const XEvent = struct {};

pub extern fn XOpenDisplay(display_name: ?[*:0]const u8) *Display;
pub extern fn XSelectInput(display: *Display, w: Window, event_mask: c_int) c_int;
pub extern fn XNextEvent(display: *Display, event_return: *XEvent) c_int;

//pub extern "C" fn XSelectInput(display: *Display, root_window: Window) i32;

test "open" {
    const display: *Display = XOpenDisplay(null);
    std.debug.print("function success\n", .{});
    std.debug.print("display {any}\n", .{display});
}
