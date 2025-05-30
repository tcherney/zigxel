const std = @import("std");
const builtin = @import("builtin");

pub const Xlib = if (builtin.os.tag == .linux) struct {
    display: ?*c._XDisplay,
    window: c_ulong,
    event: c.XEvent = undefined,
    event_type: EventType = undefined,

    pub fn init() Xlib {
        const display = c.XOpenDisplay(null);
        const window = c.XDefaultRootWindow(display);
        var res = c.XSelectInput(display, window, c.KeyPressMask | c.KeyReleaseMask);
        res = c.XMapWindow(display, window);
        res = c.XGrabKeyboard(display, window, 1, c.GrabModeAsync, c.GrabModeAsync, c.CurrentTime);
        return .{
            .display = display,
            .window = window,
        };
    }
    pub fn deinit(self: *Xlib) void {
        _ = c.XCloseDisplay(self.display);
    }
    //TODO add window and mouse event handling
    pub fn next_event(self: *Xlib) void {
        _ = c.XNextEvent(self.display, &self.event);
        self.event_type = @enumFromInt(self.event.type);
    }

    pub fn get_event_key(self: *Xlib) u8 {
        const keycode: u8 = @truncate(self.event.xkey.keycode);
        const sym = c.XKeycodeToKeysym(self.display, keycode, 0);
        return @intCast(sym&0xFF);
    }

    const c = @cImport({
        @cInclude("X11/Xlib.h");
    });
    //TODO define all constants for use in zig half (keycodes, event types, etc)
    pub const EventType = enum(c_int) {
        KeyPress = c.KeyPress,
        KeyRelease = c.KeyRelease,
    };
} else void;

test "C" {
    var xlib: Xlib = Xlib.init();
    var running: bool = true;
    std.debug.print("starting loop\n", .{});
    while (running) {
        xlib.next_event();
        std.debug.print("event type {any}\n", .{xlib.event.type});
        if (xlib.event.type == @intFromEnum(Xlib.EventType.KeyPress)) {
            std.debug.print("keycode {any}, key {c}\n", .{ xlib.event.xkey.keycode, xlib.get_event_key() });
            if (xlib.event.xkey.keycode == 0x09 or xlib.get_event_key() == 'q') {
                running = false;
            }
        }
    }
    xlib.deinit();
}
