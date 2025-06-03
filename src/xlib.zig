const std = @import("std");
const builtin = @import("builtin");

pub const Xlib = if (builtin.os.tag == .linux) struct {
    display: ?*c._XDisplay,
    window: c_ulong,
    event: c.XEvent = undefined,
    event_type: EventType = undefined,
    y_offset: i32,
    x_offset: i32,
    mouse_state: MouseState = .{
        .x = 0,
        .y = 0,
        .button1 = false,
        .button2 = false,
        .button3 = false,
        .button4 = false,
        .button5 = false,
    },
    pub const Error = error{InvalidEvent};
    pub const MouseState = struct {
        x: i32,
        y: i32,
        button1: bool,
        button2: bool,
        button3: bool,
        button4: bool,
        button5: bool,
        pub const ButtonMask = enum(c_uint) {
            // Button1MotionMask = c.Button1MotionMask,
            // Button2MotionMask = c.Button2MotionMask,
            // Button3MotionMask = c.Button3MotionMask,
            // Button4MotionMask = c.Button4MotionMask,
            // Button5MotionMask = c.Button5MotionMask,
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
        };
        pub const Button = enum(c_uint) {
            None = 0,
            Button1 = c.Button1,
            Button2 = c.Button2,
            Button3 = c.Button3,
            Button4 = c.Button4,
            Button5 = c.Button5,
        };
    };
    pub fn init(x_offset: i32, y_offset: i32) Xlib {
        const display = c.XOpenDisplay(null);
        const window = c.XDefaultRootWindow(display);
        var res = c.XSelectInput(display, window, c.KeyPressMask | c.KeyReleaseMask | c.ResizeRedirectMask | c.PointerMotionMask);
        res = c.XMapWindow(display, window);
        res = c.XGrabKeyboard(display, window, 1, c.GrabModeAsync, c.GrabModeAsync, c.CurrentTime);
        res = c.XGrabButton(display, c.Button1, c.AnyModifier, window, 0, c.ButtonPressMask | c.ButtonReleaseMask | c.ButtonMotionMask | c.PointerMotionMask, c.GrabModeAsync, c.GrabModeAsync, 0, 0);
        return .{
            .display = display,
            .window = window,
            .x_offset = x_offset,
            .y_offset = y_offset,
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
                var root_return: c_ulong = undefined;
                var child_return: c_ulong = undefined;
                var root_x: c_int = undefined;
                var root_y: c_int = undefined;
                var x: c_int = undefined;
                var y: c_int = undefined;
                var mask: c_uint = undefined;
                //this allows us to grab the window the click occured in
                _ = c.XQueryPointer(self.display, self.window, &root_return, &child_return, &root_x, &root_y, &x, &y, &mask);
                std.debug.print("x: {d}, y: {d}, x_root: {d}, y_root: {d}\n", .{ x, y, root_x, root_y });
                //now we have coordinates relative to the child window the event happened in
                _ = c.XQueryPointer(self.display, child_return, &root_return, &child_return, &root_x, &root_y, &x, &y, &mask);
                std.debug.print("x: {d}, y: {d}, x_root: {d}, y_root: {d}\n", .{ x, y, root_x, root_y });
                //TODO we will need to offset the y due to the title bar of the terminal
                self.mouse_state.x = x - self.x_offset;
                self.mouse_state.y = y - self.y_offset;
                std.debug.print("{any}\n", .{self.event.xbutton});
                std.debug.print("x: {d}, y: {d}, x_root: {d}, y_root: {d}\n", .{ self.event.xbutton.x, self.event.xbutton.y, self.event.xbutton.x_root, self.event.xbutton.y_root });
                const button_changed: MouseState.Button = @enumFromInt(self.event.xbutton.button);
                switch (button_changed) {
                    .Button1 => {
                        self.mouse_state.button1 = !((self.event.xbutton.state & @intFromEnum(MouseState.ButtonMask.Button1Mask) != 0));
                    },
                    .Button2 => {
                        self.mouse_state.button2 = !((self.event.xbutton.state & @intFromEnum(MouseState.ButtonMask.Button2Mask) != 0));
                    },
                    .Button3 => {
                        self.mouse_state.button3 = !((self.event.xbutton.state & @intFromEnum(MouseState.ButtonMask.Button3Mask) != 0));
                    },
                    .Button4 => {
                        self.mouse_state.button4 = !((self.event.xbutton.state & @intFromEnum(MouseState.ButtonMask.Button4Mask) != 0));
                    },
                    .Button5 => {
                        self.mouse_state.button5 = !((self.event.xbutton.state & @intFromEnum(MouseState.ButtonMask.Button5Mask) != 0));
                    },
                    else => {
                        //TODO
                    },
                }
            },
            .MotionNotify => {
                std.debug.print("Motion\n", .{});
                self.mouse_state.x = self.event.xmotion.x;
                self.mouse_state.y = self.event.xmotion.y;
            },
            else => {},
        }
    }

    //TODO revisit this to handle modifer presses
    pub fn is_mod_pressed(self: *Xlib, button_state: MouseState.ButtonMask) Error!bool {
        if (self.event_type != .ButtonPress and self.event_type != .ButtonRelease and self.event_type != .MotionNotify) {
            return Error.InvalidEvent;
        }
        var state: c_uint = undefined;
        if (self.event_type == .ButtonPress or self.event_type == .ButtonRelease) {
            state = self.event.xbutton.state;
        } else if (self.event_type == .MotionNotify) {
            state = self.event.xmotion.state;
        }
        const mask = @intFromEnum(button_state);
        return (state & mask) != 0;
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
        ButtonPress = c.ButtonPress,
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
