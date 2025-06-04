const std = @import("std");
const builtin = @import("builtin");
pub const graphics = @import("graphics.zig");
pub const ascii_graphics = @import("ascii_graphics.zig");
const event_manager = @import("event_manager.zig");
const term = @import("term");
const common = @import("common");
const texture = @import("texture.zig");
const image = @import("image");

pub const EventManager = event_manager.EventManager;
pub const Graphics = graphics.Graphics;
pub const AsciiGraphics = ascii_graphics.AsciiGraphics;
pub const Texture = texture.Texture;
pub const KEYS = event_manager.KEYS;
pub const MouseEvent = event_manager.MouseEvent;
pub const WindowSize = event_manager.WindowSize;
pub const RenderCallback = common.CallbackError(u64, Error);
pub const Error = error{} || EventManager.Error || graphics.Error || std.time.Timer.Error || std.posix.GetRandomError;

pub const ENGINE_LOG = std.log.scoped(.engine);

pub fn Engine(comptime graphics_type: graphics.GraphicsType, comptime color_type: graphics.ColorMode) type {
    return struct {
        renderer: Renderer = undefined,
        events: EventManager = undefined,
        render_callback: ?RenderCallback = null,
        render_thread: std.Thread = undefined,
        running: bool = false,
        frame_limit: u64 = 16_666_667,
        fps: f64 = 0.0,
        window_changed: bool = false,
        window_change_size: term.Size = undefined,
        window_change_callback: ?event_manager.WindowChangeCallback = null,

        const Self = @This();
        pub const Renderer = switch (graphics_type) {
            .ascii => switch (color_type) {
                .color_256 => AsciiGraphics(.color_256),
                .color_true => AsciiGraphics(.color_true),
            },
            else => Graphics(graphics_type, color_type),
        };
        pub fn init(allocator: std.mem.Allocator, term_height_offset: usize) Error!Self {
            return Self{ .renderer = try Renderer.init(allocator), .events = EventManager.init(term_height_offset) };
        }

        pub fn deinit(self: *Self) Error!void {
            self.stop();
            if (self.render_callback != null) {
                self.render_thread.join();
            }
            try self.renderer.deinit();
            try self.events.deinit();
        }

        pub fn window_change(self: *Self, win_size: WindowSize) void {
            if (builtin.os.tag == .windows) {
                self.window_changed = true;
                self.window_change_size = term.Size{ .width = @as(usize, @intCast(win_size.width)), .height = @as(usize, @intCast(win_size.height)) };
            }
        }
        //TODO multithreaded rendering?? can split target texture into multiple parts
        fn render_loop(self: *Self) Error!void {
            var timer: std.time.Timer = try std.time.Timer.start();
            var elapsed: f64 = 0.0;
            var frames: u32 = 0;
            var delta: u64 = 0;
            while (self.running) {
                timer.reset();
                try self.render_callback.?.call(delta);
                // check window change
                if (builtin.os.tag != .windows) {
                    const check_size = try term.Term.get_Size(self.renderer.terminal.stdout.context.handle);
                    if (check_size.width != self.renderer.terminal.size.width or check_size.height * 2 != self.renderer.terminal.size.height) {
                        try self.renderer.size_change(check_size);
                    }
                }
                if (self.window_changed) {
                    try self.renderer.size_change(self.window_change_size);
                    if (self.window_change_callback != null) {
                        self.window_change_callback.?.call(.{ .width = @as(u32, @intCast(self.window_change_size.width)), .height = @as(u32, @intCast(self.window_change_size.height)) });
                    }
                    self.window_changed = false;
                }
                delta = timer.read();
                elapsed += @as(f64, @floatFromInt(delta)) / 1_000_000_000.0;
                frames += 1;
                //ENGINE_LOG.info("elapsed {d}\n", .{elapsed});
                if (elapsed >= 1.0) {
                    self.fps = @as(f64, @floatFromInt(frames)) / elapsed;
                    //ENGINE_LOG.info("fps {d}\n", .{self.fps});
                    frames = 0;
                    elapsed = 0.0;
                }
                const time_to_sleep: i64 = @as(i64, @bitCast(self.frame_limit)) - @as(i64, @bitCast(delta));
                //ENGINE_LOG.info("time to sleep {d}\n", .{time_to_sleep});
                if (time_to_sleep > 0) {
                    std.time.sleep(@as(u64, @bitCast(time_to_sleep)));
                }
            }
        }

        pub fn set_fps(self: *Self, fps: u64) void {
            self.frame_limit = 1_000_000_000 / fps;
            ENGINE_LOG.info("{d}\n", .{self.frame_limit});
        }

        pub fn stop(self: *Self) void {
            self.running = false;
        }

        pub fn start(self: *Self) Error!void {
            ENGINE_LOG.info("Window size {d}x{d}\n", .{ self.renderer.terminal.size.width, self.renderer.terminal.size.height });
            if (builtin.os.tag == .windows) {
                self.events.window_change_callback = event_manager.WindowChangeCallback.init(Self, window_change, self);
            }
            self.running = true;
            if (self.render_callback) |_| {
                self.render_thread = try std.Thread.spawn(.{}, render_loop, .{self});
            }
            try self.events.start();
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

        pub fn on_mouse_change(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.events.mouse_event_callback = event_manager.MouseChangeCallback.init(CONTEXT_TYPE, func, context);
        }
        pub fn on_window_change(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.window_change_callback = event_manager.WindowChangeCallback.init(CONTEXT_TYPE, func, context);
        }

        pub fn on_render(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
            self.render_callback = RenderCallback.init(CONTEXT_TYPE, func, context);
        }
    };
}
