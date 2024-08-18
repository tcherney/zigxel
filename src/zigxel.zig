const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const event_manager = @import("event_manager.zig");
const utils = @import("utils.zig");
const texture = @import("texture.zig");

pub const Error = error{} || event_manager.Error || graphics.Error || std.time.Timer.Error || utils.Error;

pub const Zigxel = struct {
    renderer: graphics.Graphics = undefined,
    events: event_manager.EventManager = undefined,
    render_fn: ?*const fn () Error!void = null,
    render_thread: std.Thread = undefined,
    running: bool = false,
    frame_limit: u64 = 16_666_667,
    fps: f64 = 0.0,

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return Self{ .renderer = try graphics.Graphics.init(allocator), .events = event_manager.EventManager.init() };
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

    pub fn on_key_down(self: *Self, func: *const fn (event_manager.KEYS) void) void {
        self.events.key_down_callback = func;
    }

    pub fn on_key_up(self: *Self, func: *const fn (event_manager.KEYS) void) void {
        self.events.key_up_callback = func;
    }

    pub fn on_key_press(self: *Self, func: *const fn (event_manager.KEYS) void) void {
        self.events.key_press_callback = func;
    }

    pub fn on_render(self: *Self, func: *const fn () Error!void) void {
        self.render_fn = func;
    }
    //TODO expose render function pointer to put graphics on a different thread than game logic
};

var running: bool = true;
var my_x: usize = 5;
var my_y: usize = 5;
var zigxel: Zigxel = undefined;
var fps_buffer: [64]u8 = undefined;
var tex: texture.Texture(texture.ColorMode.color_256) = undefined;
pub fn on_key_press(key: event_manager.KEYS) void {
    //std.debug.print("{}\n", .{key});
    if (key == event_manager.KEYS.KEY_q) {
        running = false;
    } else if (key == event_manager.KEYS.KEY_a) {
        my_x -= 1;
    } else if (key == event_manager.KEYS.KEY_d) {
        my_x += 1;
    } else if (key == event_manager.KEYS.KEY_w) {
        my_y -= 1;
    } else if (key == event_manager.KEYS.KEY_s) {
        my_y += 1;
    }
}

pub fn on_render() Error!void {
    zigxel.renderer.set_bg(0, 0, 0);
    zigxel.renderer.draw_texture(tex);
    zigxel.renderer.draw_rect(60, 8, 2, 3, 0, 255, 255);
    zigxel.renderer.draw_rect(60, 8, 3, 1, 128, 75, 0);
    zigxel.renderer.draw_rect(95, 15, 2, 1, 255, 128, 0);
    zigxel.renderer.draw_rect(my_x, my_y, 1, 1, 255, 128, 255);
    try zigxel.renderer.draw_text(try std.fmt.bufPrint(&fps_buffer, "FPS:{d:.2}", .{zigxel.fps}), 30, 40, 0, 255, 0);
    try zigxel.renderer.flip();
}

test "engine" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try utils.gen_rand();
    tex = texture.Texture(texture.ColorMode.color_256).init(allocator);
    try tex.rect(50, 10, 5, 5, 255, 255, 0);
    for (0..tex.pixel_buffer.len) |i| {
        tex.pixel_buffer[i] = utils.rand.int(u8);
    }
    zigxel = try Zigxel.init(allocator);
    zigxel.on_key_press(on_key_press);
    zigxel.on_render(on_render);
    zigxel.set_fps(60);
    try zigxel.start();

    while (running) {
        // do game logic on seperate thread
        std.time.sleep(zigxel.frame_limit);
    }
    try zigxel.deinit();
}
