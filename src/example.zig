const std = @import("std");
const engine = @import("engine.zig");
const utils = @import("utils.zig");
const image = @import("image");
const sprite = @import("sprite.zig");

pub const Error = error{} || image.Error || engine.Error || utils.Error;

pub const Game = struct {
    running: bool = true,
    e: engine.Engine(utils.ColorMode.color_true) = undefined,
    fps_buffer: [64]u8 = undefined,
    tex: engine.Texture = undefined,
    player: sprite.Sprite = undefined,
    allocator: std.mem.Allocator = undefined,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        self.tex.deinit();
        self.player.deinit();
    }
    pub fn on_key_press(self: *Self, key: engine.KEYS) void {
        //std.debug.print("{}\n", .{key});
        if (key == engine.KEYS.KEY_q) {
            self.running = false;
        } else if (key == engine.KEYS.KEY_a) {
            self.player.dest.x -= 1;
        } else if (key == engine.KEYS.KEY_d) {
            self.player.dest.x += 1;
        } else if (key == engine.KEYS.KEY_w) {
            self.player.dest.y -= 1;
        } else if (key == engine.KEYS.KEY_s) {
            self.player.dest.y += 1;
        }
    }

    pub fn on_render(self: *Self, _: u64) !void {
        self.e.renderer.set_bg(0, 0, 0);
        self.e.renderer.draw_rect(60, 8, 2, 3, 0, 255, 255);
        self.e.renderer.draw_rect(60, 8, 3, 1, 128, 75, 0);
        self.e.renderer.draw_rect(95, 15, 2, 1, 255, 128, 0);
        try self.e.renderer.draw_sprite(self.player);
        try self.e.renderer.draw_text(try std.fmt.bufPrint(&self.fps_buffer, "FPS:{d:.2}", .{self.e.fps}), 30, 40, 0, 255, 0);
        try self.e.renderer.flip();
    }
    pub fn run(self: *Self) !void {
        try utils.gen_rand();
        self.tex = engine.Texture.init(self.allocator);
        self.e = try engine.Engine(utils.ColorMode.color_true).init(self.allocator);
        // var img = image.Image(image.JPEGImage){};
        // try img.load("../img2ascii/tests/jpeg/cat.jpg", self.allocator);
        // defer img.deinit();
        // try self.tex.load_image(img);
        //try self.tex.gaussian_blur(3.0);
        //try self.tex.scale(68, 45);
        try self.tex.rect(50, 50, 255, 128, 0);
        self.player = try sprite.Sprite.init(self.allocator, .{ .x = 0, .y = 0, .width = 50, .height = 50 }, .{ .x = 5, .y = 5, .width = 100, .height = 35 }, self.tex);
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
