const std = @import("std");
const engine = @import("engine.zig");
const utils = @import("utils.zig");
const image = @import("image");

pub const Error = error{} || image.Error || engine.Error || utils.Error;

pub const Game = struct {
    running: bool = true,
    e: engine.Engine(utils.ColorMode.color_true) = undefined,
    fps_buffer: [64]u8 = undefined,
    tex: engine.TextureTrue = undefined,
    allocator: std.mem.Allocator = undefined,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        self.tex.deinit();
    }
    pub fn on_key_press(self: *Self, key: engine.KEYS) void {
        //std.debug.print("{}\n", .{key});
        if (key == engine.KEYS.KEY_q) {
            self.running = false;
        } else if (key == engine.KEYS.KEY_a) {
            self.tex.x -= 1;
        } else if (key == engine.KEYS.KEY_d) {
            self.tex.x += 1;
        } else if (key == engine.KEYS.KEY_w) {
            self.tex.y -= 1;
        } else if (key == engine.KEYS.KEY_s) {
            self.tex.y += 1;
        }
    }

    pub fn on_render(self: *Self, _: u64) !void {
        self.e.renderer.set_bg(0, 0, 0);
        self.e.renderer.draw_rect(60, 8, 2, 3, 0, 255, 255);
        self.e.renderer.draw_rect(60, 8, 3, 1, 128, 75, 0);
        self.e.renderer.draw_rect(95, 15, 2, 1, 255, 128, 0);
        self.e.renderer.draw_texture(self.tex);
        try self.e.renderer.draw_text(try std.fmt.bufPrint(&self.fps_buffer, "FPS:{d:.2}", .{self.e.fps}), 30, 40, 0, 255, 0);
        try self.e.renderer.flip();
    }
    pub fn run(self: *Self) !void {
        try utils.gen_rand();
        self.tex = engine.TextureTrue.init(self.allocator);
        self.e = try engine.Engine(utils.ColorMode.color_true).init(self.allocator);
        var img = image.Image(image.JPEGImage){};
        try img.load("../img2ascii/tests/jpeg/cat.jpg", self.allocator);
        defer img.deinit();
        try self.tex.load_image(5, 5, img);
        try self.tex.gaussian_blur(3.0);
        try self.tex.scale(68, 45);
        //std.debug.print("{any}\n", .{tex.pixel_buffer});
        //std.debug.print("{d}\n", .{utils.rgb_256(255, 255, 255)});
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
