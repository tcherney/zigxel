const std = @import("std");
const builtin = @import("builtin");

pub const Xlib = if (builtin.os.tag == .linux) struct {
    display: ?*c._XDisplay,
    window: c_ulong,
    event: c.XEvent = undefined,
    event_type: EventType = undefined,
    mouse_state: MouseState = undefined,
    pub const Error = error{InvalidEvent};
    pub const MouseState = struct {
        x: i32,
        y: i32,
        //TODO might need to fiddle with these types
        button_state: c_uint,
        pub const ButtonState = enum(c_uint) {
            Button1MotionMask = c.Button1MotionMask,
            Button2MotionMask = c.Button2MotionMask,
            Button3MotionMask = c.Button3MotionMask,
            Button4MotionMask = c.Button4MotionMask,
            Button5MotionMask = c.Button5MotionMask,
            Button1Mask = c.Button1Mask,
            Button2Mask = c.Button2Mask,
            Button3Mask = c.Button3Mask,
            Button4Mask = c.Button4Mask,
            Button5Mask = c.Button5Mask,
            ShiftMask = c.ShiftMask,
            LockMask = c.LockMask,
            ControlMask = c.ControlMask,
            Mod1Mask = c.Mod1Mask,
            Mod2Mask = c.Mod2Mask,
            Mod3Mask = c.Mod3Mask,
            Mod4Mask = c.Mod4Mask,
            Mod5Mask = c.Mod5Mask,
            Button1 = c.Button1,
            Button2 = c.Button2,
            Button3 = c.Button3,
            Button4 = c.Button4,
            Button5 = c.Button5,
        };
    };
    pub fn init() Xlib {
        const display = c.XOpenDisplay(null);
        const window = c.XDefaultRootWindow(display);
        var res = c.XSelectInput(display, window, c.KeyPressMask | c.KeyReleaseMask | c.ResizeRedirectMask | c.ButtonPressMask | c.ButtonReleaseMask | c.PointerMotionMask);
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
        switch (self.event_type) {
            .ButtonPress, .ButtonRelease => {
                //TODO may need to math these to get proper coordinates with root values
                self.mouse_state.x = self.event.xbutton.x;
                self.mouse_state.y = self.event.xbutton.y;
                self.mouse_state.button_state = self.event.xbutton.state;
            },
            .MotionNotify => {
                self.mouse_state.x = self.event.xmotion.x;
                self.mouse_state.y = self.event.xmotion.y;
                self.mouse_state.button_state = self.event.xmotion.state;
            },
            else => {},
        }
    }

    pub fn is_button_state(self: *Xlib, button_state: MouseState.ButtonState) Error!bool {
        if (self.event_type != .ButtonPress and self.event_type != .ButtonRelease and self.event_type != .MotionNotify) {
            return Error.InvalidEvent;
        }
        const mask = @intFromEnum(button_state);
        return (self.mouse_state.button_state & mask) != 0;
    }

    pub fn get_event_key(self: *Xlib) Error!u8 {
        if (self.event_type != .KeyPress and self.event_type != .KeyRelease) {
            return Error.InvalidEvent;
        }
        const keycode: u8 = @truncate(self.event.xkey.keycode);
        const sym = c.XKeycodeToKeysym(self.display, keycode, 0);
        return @intCast(sym & 0xFF);
    }

    const c = @cImport({
        @cInclude("X11/Xlib.h");
    });
    //TODO define all constants for use in zig half (keycodes, event types, etc)
    pub const EventType = enum(c_int) {
        KeyPress = c.KeyPress,
        KeyRelease = c.KeyRelease,
        ButtonPress = c.ButtonPres,
        ButtonRelease = c.ButtonRelease,
        MotionNotify = c.MotionNotify,
        ResizeRequest = c.ResizeRequest,
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
