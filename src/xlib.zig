const std = @import("std");
const builtin = @import("builtin");

const XLIB_LOG = std.log.scoped(.xlib);

pub const Error = error{InvalidEvent};

pub const Xlib = if (builtin.os.tag == .linux) struct {
    display: ?*c._XDisplay,
    window: c_ulong,
    event: c.XEvent = undefined,
    event_type: EventType = undefined,
    child_width: u32 = undefined,
    child_height: u32 = undefined,
    child_border_width: u32 = undefined,
    last_child: c_ulong = 0,
    pointer_grabbed: bool = false,
    mouse_state: MouseState = .{
        .x = 0,
        .y = 0,
        .button1 = false,
        .button2 = false,
        .button3 = false,
        .button4 = false,
        .button5 = false,
    },
    pub const MouseState = struct {
        x: i32,
        y: i32,
        button1: bool,
        button2: bool,
        button3: bool,
        button4: bool,
        button5: bool,
        pub const ButtonMask = enum(c_uint) {
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
            _,
        };
    };
    pub fn init() Xlib {
        const display = c.XOpenDisplay(null);
        const window = c.XDefaultRootWindow(display);
        var res = c.XSelectInput(display, window, c.KeyPressMask | c.KeyReleaseMask | c.ResizeRedirectMask);
        res = c.XMapWindow(display, window);
        res = c.XGrabKeyboard(display, window, 1, c.GrabModeAsync, c.GrabModeAsync, c.CurrentTime);
        //res = c.XGrabButton(display, c.AnyButton, c.AnyModifier, window, 0, c.ButtonPressMask | c.ButtonReleaseMask | c.ButtonMotionMask, c.GrabModeSync, c.GrabModeAsync, 0, 0);
        res = c.XGrabPointer(display, window, 0, c.ButtonPressMask | c.ButtonReleaseMask | c.PointerMotionMask, c.GrabModeSync, c.GrabModeAsync, 0, 0, c.CurrentTime);
        return .{
            .display = display,
            .window = window,
            .last_child = window,
        };
    }
    pub fn deinit(self: *Xlib) void {
        _ = c.XCloseDisplay(self.display);
    }
    fn process_coords(self: *Xlib) void {
        var root_return: c_ulong = undefined;
        var child_return: c_ulong = undefined;
        var root_x: c_int = undefined;
        var root_y: c_int = undefined;
        var child_x: c_int = undefined;
        var child_y: c_int = undefined;
        var mask: c_uint = undefined;
        //this allows us to grab the window the click occured in
        _ = c.XQueryPointer(self.display, self.window, &root_return, &child_return, &root_x, &root_y, &child_x, &child_y, &mask);
        XLIB_LOG.info("x: {d}, y: {d}, x_root: {d}, y_root: {d}\n", .{ child_x, child_y, root_x, root_y });
        if (self.last_child != 0 and self.last_child != child_return) {
            //TODO ungrab pointer
        } else {
            self.last_child = child_return;
            //now we have coordinates relative to the child window the event happened in
            _ = c.XQueryPointer(self.display, self.last_child, &root_return, &self.last_child, &root_x, &root_y, &child_x, &child_y, &mask);
            XLIB_LOG.info("x: {d}, y: {d}, x_root: {d}, y_root: {d}\n", .{ child_x, child_y, root_x, root_y });
            self.mouse_state.x = child_x;
            self.mouse_state.y = child_y;
            XLIB_LOG.info("{any}\n", .{self.event.xbutton});
            //grab dimensions of window we clicked in
            var depth_return: c_uint = undefined;
            //TODO this can apparently error need to handle it
            _ = c.XGetGeometry(self.display, self.last_child, &root_return, &root_x, &root_y, &self.child_width, &self.child_height, &self.child_border_width, &depth_return);
            XLIB_LOG.info("width: {d}, height: {d}, border: {d}\n", .{ self.child_width, self.child_height, self.child_border_width });
            //_ = c.XSendEvent(self.display, self.last_child, 0, c.ButtonPressMask | c.ButtonReleaseMask, &self.event);
        }
    }
    //TODO add window and mouse event handling
    pub fn next_event(self: *Xlib) void {
        //TODO establish child window
        // use this window to then subscribe to pointer events
        // if we detect a click outside of this window we unsubscribe until the window is clicked in again
        _ = c.XAllowEvents(self.display, c.SyncPointer, c.CurrentTime);
        _ = c.XAllowEvents(self.display, c.ReplayPointer, c.CurrentTime);
        _ = c.XSendEvent(self.display, self.last_child, 0, c.ButtonPressMask | c.ButtonReleaseMask, &self.event);
        _ = c.XSync(self.display, 0);
        _ = c.XNextEvent(self.display, &self.event);
        self.event_type = @enumFromInt(self.event.type);
        switch (self.event_type) {
            .ButtonPress, .ButtonRelease => {
                self.process_coords();
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
                // _ = c.XUngrabPointer(self.display, self.event.xbutton.time);
                // _ = c.XAllowEvents(self.display, c.ReplayPointer, self.event.xbutton.time);
                // _ = c.XSync(self.display, 0);
                // _ = c.XGrabPointer(self.display, self.window, 1, c.ButtonPressMask | c.ButtonReleaseMask | c.PointerMotionMask, c.GrabModeAsync, c.GrabModeAsync, 0, 0, c.CurrentTime);
            },
            .MotionNotify => {
                XLIB_LOG.info("Motion\n", .{});
                self.process_coords();
            },
            .ResizeRequest => {
                XLIB_LOG.info("Resize {any}\n", .{self.event.xresizerequest});
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
    pub const EventType = enum(c_int) { KeyPress = c.KeyPress, KeyRelease = c.KeyRelease, ButtonPress = c.ButtonPress, ButtonRelease = c.ButtonRelease, MotionNotify = c.MotionNotify, ResizeRequest = c.ResizeRequest, _ };
} else void;

test "C" {
    var xlib: Xlib = Xlib.init();
    var running: bool = true;
    XLIB_LOG.info("starting loop\n", .{});
    while (running) {
        xlib.next_event();
        XLIB_LOG.info("event type {any}\n", .{xlib.event.type});
        if (xlib.event.type == @intFromEnum(Xlib.EventType.KeyPress)) {
            XLIB_LOG.info("keycode {any}, key {c}\n", .{ xlib.event.xkey.keycode, xlib.get_event_key() });
            if (xlib.event.xkey.keycode == 0x09 or xlib.get_event_key() == 'q') {
                running = false;
            }
        }
    }
    xlib.deinit();
}
