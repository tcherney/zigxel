const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
});

pub const Display = struct {};

pub extern fn XOpenDisplay(display_name: ?[*:0]const u8) *Display;

//pub extern "C" fn XSelectInput(display: *Display, root_window: Window) i32;

test "open" {
    const display: *Display = XOpenDisplay(null);
    std.debug.print("function success\n", .{});
    std.debug.print("display {any}\n", .{display});
}
