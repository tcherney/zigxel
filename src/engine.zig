const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const event_manager = @import("event_manager.zig");
const term = @import("term.zig");
const utils = @import("utils.zig");
const texture = @import("texture.zig");
const image = @import("image");

pub const EventManager = event_manager.EventManager;
pub const Graphics = graphics.Graphics;
pub const Texture256 = texture.Texture(utils.ColorMode.color_256);
pub const TextureTrue = texture.Texture(utils.ColorMode.color_true);
pub const KEYS = event_manager.KEYS;

pub const Error = error{} || event_manager.Error || graphics.Error || std.time.Timer.Error || utils.Error;

pub const RenderCallback = utils.CallbackError(u64);

pub fn Engine(comptime color_type: utils.ColorMode) type {
    return struct {
        renderer: Graphics(color_type) = undefined,
        events: EventManager = undefined,
        render_callback: ?RenderCallback = null,
        render_thread: std.Thread = undefined,
        running: bool = false,
        frame_limit: u64 = 16_666_667,
        fps: f64 = 0.0,
        window_changed: bool = false,
        window_change_size: term.Size = undefined,

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return Self{ .renderer = try Graphics(color_type).init(allocator), .events = EventManager.init() };
        }

        pub fn deinit(self: *Self) Error!void {
            self.stop();
            if (self.render_callback != null) {
                self.render_thread.join();
            }
            try self.renderer.deinit();
            try self.events.deinit();
        }

        pub fn window_change(self: *Self, coord: std.os.windows.COORD) void {
            self.window_changed = true;
            self.window_change_size = term.Size{ .width = @as(usize, @intCast(coord.X)), .height = @as(usize, @intCast(coord.Y)) };
        }

        fn render_loop(self: *Self) !void {
            var timer: std.time.Timer = try std.time.Timer.start();
            var elapsed: f64 = 0.0;
            var frames: u32 = 0;
            var delta: u64 = 0;
            while (self.running) {
                try self.render_callback.?.call(delta);
                // check window change
                if (self.window_changed) {
                    try self.renderer.size_change(self.window_change_size);
                    self.window_changed = false;
                }
                delta = timer.read();
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
            std.debug.print("Window size {d}x{d}\n", .{ self.renderer.terminal.size.width, self.renderer.terminal.size.height });
            self.events.window_change_callback = event_manager.WindowChangeCallback.init(Self, window_change, self);
            self.running = true;
            try self.events.start();
            if (self.render_callback) |_| {
                self.render_thread = try std.Thread.spawn(.{}, render_loop, .{self});
            }
        }

        pub fn on_key_down(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.events.key_down_callback = event_manager.KeyChangeCallback.init(CONTEXT_TYPE, func, context);
        }

        pub fn on_key_up(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.events.key_up_callback = event_manager.KeyChangeCallback.init(CONTEXT_TYPE, func, context);
        }

        pub fn on_key_press(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.events.key_press_callback = event_manager.KeyChangeCallback.init(CONTEXT_TYPE, func, context);
        }

        pub fn on_render(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.render_callback = RenderCallback.init(CONTEXT_TYPE, func, context);
        }
    };
}
