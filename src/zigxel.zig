const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const event_manager = @import("event_manager.zig");

pub const Zigxel = struct {
    g: graphics.Graphics = undefined,
    events: event_manager.EventManager = undefined,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{ .g = try graphics.Graphics.init(allocator), .events = event_manager.EventManager.init() };
    }

    pub fn deinit(self: *Self) !void {
        try self.g.deinit();
        try self.events.deinit();
    }

    pub fn start(self: *Self) !void {
        try self.events.start();
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
};

var running: bool = true;
var my_x: usize = 5;
var my_y: usize = 5;
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

test "engine" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var zigxel = try Zigxel.init(allocator);
    zigxel.on_key_press(on_key_press);
    try zigxel.start();
    const time_per_frame = 17_000_000;
    var now = std.time.nanoTimestamp();
    var end = std.time.nanoTimestamp();
    var delta = end - now;
    while (running) {
        now = std.time.nanoTimestamp();
        try zigxel.g.set_bg(0, 0, 0);
        try zigxel.g.draw_rect(50, 10, 5, 5, 255, 255, 0);
        try zigxel.g.draw_rect(60, 8, 2, 3, 0, 255, 255);
        try zigxel.g.draw_rect(60, 8, 3, 1, 128, 75, 0);
        try zigxel.g.draw_rect(95, 15, 2, 1, 255, 128, 0);
        try zigxel.g.draw_rect(my_x, my_y, 1, 1, 255, 128, 255);
        try zigxel.g.draw_text("hello world", 30, 40, 0, 255, 0);
        try zigxel.g.flip();
        end = std.time.nanoTimestamp();
        delta = end - now;
        //std.debug.print("{d}\n", .{delta});
        const time_to_sleep = time_per_frame - delta;
        if (time_to_sleep > 0) {
            std.time.sleep(@as(u64, @intCast(time_to_sleep)));
        }
    }
    try zigxel.deinit();
}
