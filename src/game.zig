const std = @import("std");
const engine = @import("engine.zig");
const utils = @import("utils.zig");
const image = @import("image");
const sprite = @import("sprite.zig");
const physic_pixel = @import("physics_pixel.zig");

pub const PhysicsPixel = physic_pixel.PhysicsPixel;
pub const Error = error{} || image.Error || engine.Error || utils.Error;

pub const Game = struct {
    running: bool = true,
    e: engine.Engine(utils.ColorMode.color_true) = undefined,
    fps_buffer: [64]u8 = undefined,
    placement_pixel: PhysicsPixel = undefined,
    pixels: std.ArrayList(PhysicsPixel) = undefined,
    allocator: std.mem.Allocator = undefined,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        self.pixels.deinit();
    }
    pub fn on_key_press(self: *Self, key: engine.KEYS) void {
        //std.debug.print("{}\n", .{key});
        if (key == engine.KEYS.KEY_q) {
            self.running = false;
        } else if (key == engine.KEYS.KEY_a) {
            self.placement_pixel.x -= 1;
        } else if (key == engine.KEYS.KEY_d) {
            self.placement_pixel.x += 1;
        } else if (key == engine.KEYS.KEY_w) {
            self.placement_pixel.y -= 1;
        } else if (key == engine.KEYS.KEY_s) {
            self.placement_pixel.y += 1;
        } else if (key == engine.KEYS.KEY_SPACE) {
            std.debug.print("placed \n", .{});
            self.pixels.append(PhysicsPixel.init(self.placement_pixel.x, self.placement_pixel.y, self.placement_pixel.pixel.r, self.placement_pixel.pixel.g, self.placement_pixel.pixel.b)) catch |err| {
                std.debug.print("{any}\n", .{err});
                self.running = false;
            };
        }
    }

    pub fn on_render(self: *Self, _: u64) !void {
        self.e.renderer.set_bg(0, 0, 0);
        for (self.pixels.items) |p| {
            self.e.renderer.draw_pixel(p.x, p.y, p.pixel);
        }
        self.e.renderer.draw_pixel(self.placement_pixel.x, self.placement_pixel.y, self.placement_pixel.pixel);
        try self.e.renderer.flip();
    }
    pub fn run(self: *Self) !void {
        //try utils.gen_rand();
        self.e = try engine.Engine(utils.ColorMode.color_true).init(self.allocator);
        self.placement_pixel = PhysicsPixel.init(0, 0, 0, 0, 255);
        self.pixels = std.ArrayList(PhysicsPixel).init(self.allocator);
        self.e.on_key_press(Self, on_key_press, self);
        self.e.on_render(Self, on_render, self);
        self.e.set_fps(60);
        try self.e.start();

        while (self.running) {
            // do game logic on seperate thread
            std.time.sleep(self.e.frame_limit);
        }
    }
};
