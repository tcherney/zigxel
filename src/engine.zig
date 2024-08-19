const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const event_manager = @import("event_manager.zig");
const utils = @import("utils.zig");
const texture = @import("texture.zig");
const image = @import("image");

pub const EventManager = event_manager.EventManager;
pub const Graphics = graphics.Graphics;
pub const Texture256 = texture.Texture(texture.ColorMode.color_256);
pub const TextureTrue = texture.Texture(texture.ColorMode.color_true);
pub const KEYS = event_manager.KEYS;

pub const Error = error{} || event_manager.Error || graphics.Error || std.time.Timer.Error || utils.Error;

pub const Engine = struct {
    renderer: Graphics = undefined,
    events: EventManager = undefined,
    render_fn: ?*const fn () Error!void = null,
    render_thread: std.Thread = undefined,
    running: bool = false,
    frame_limit: u64 = 16_666_667,
    fps: f64 = 0.0,

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return Self{ .renderer = try Graphics.init(allocator), .events = EventManager.init() };
    }

    pub fn deinit(self: *Self) Error!void {
        self.stop();
        if (self.render_fn != null) {
            self.render_thread.join();
        }
        try self.renderer.deinit();
        try self.events.deinit();
    }

    fn render_loop(self: *Self) Error!void {
        var timer: std.time.Timer = try std.time.Timer.start();
        var elapsed: f64 = 0.0;
        var frames: u32 = 0;
        while (self.running) {
            try self.render_fn.?();
            const delta = timer.read();
            timer.reset();
            elapsed += @as(f64, @floatFromInt(delta)) / 1_000_000_000.0;
            frames += 1;
            //std.debug.print("elapsed {d}\n", .{elapsed});
            if (elapsed >= 1.0) {
                self.fps = @as(f64, @floatFromInt(frames)) / elapsed;
                //std.debug.print("fps {d}\n", .{self.fps});
                frames = 0;
                elapsed = 0.0;
            }
            const time_to_sleep: i64 = @as(i64, @bitCast(self.frame_limit)) - @as(i64, @bitCast(delta));
            //std.debug.print("time to sleep {d}\n", .{time_to_sleep});
            if (time_to_sleep > 0) {
                std.time.sleep(@as(u64, @bitCast(time_to_sleep)));
            }
        }
    }

    pub fn set_fps(self: *Self, fps: u64) void {
        self.frame_limit = 1_000_000_000 / fps;
        std.debug.print("{d}\n", .{self.frame_limit});
    }

    pub fn stop(self: *Self) void {
        self.running = false;
    }

    pub fn start(self: *Self) Error!void {
        self.running = true;
        try self.events.start();
        if (self.render_fn) |_| {
            self.render_thread = try std.Thread.spawn(.{}, render_loop, .{self});
        }
    }

    pub fn on_key_down(self: *Self, func: *const fn (KEYS) void) void {
        self.events.key_down_callback = func;
    }

    pub fn on_key_up(self: *Self, func: *const fn (KEYS) void) void {
        self.events.key_up_callback = func;
    }

    pub fn on_key_press(self: *Self, func: *const fn (KEYS) void) void {
        self.events.key_press_callback = func;
    }

    pub fn on_render(self: *Self, func: *const fn () Error!void) void {
        self.render_fn = func;
    }
};
