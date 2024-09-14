const std = @import("std");
const game_object = @import("game_object.zig");
const physics_pixel = @import("physics_pixel.zig");

pub const GameObject = game_object.GameObject;

const JUMPING_MAX = 10;

pub const Error = error{} || game_object.Error;

pub const Player = struct {
    jumping: bool = false,
    left: bool = false,
    right: bool = false,
    jumping_duration: u32 = 0,
    allocator: std.mem.Allocator,
    go: GameObject,
    const Self = @This();
    pub fn init(x: i32, y: i32, w_width: u32, tex: *game_object.Texture, allocator: std.mem.Allocator) Error!Self {
        return Self{
            .allocator = allocator,
            .go = try GameObject.init(x, y, w_width, tex, allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.go.deinit();
    }

    pub fn move_left(self: *Self) void {
        self.left = true;
        self.right = false;
    }

    pub fn move_right(self: *Self) void {
        self.right = true;
        self.left = false;
    }

    pub fn stop_move_left(self: *Self) void {
        self.left = false;
    }

    pub fn stop_move_right(self: *Self) void {
        self.right = false;
    }

    pub fn jump(self: *Self) void {
        self.jumping = true;
        self.jumping_duration = 0;
    }

    fn check_left_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        const x = 0;
        for (0..self.go.bounds.height) |y| {
            if (physics_pixel.pixel_at_x_y(self.go.pixels[y * self.go.bounds.width + x].x - 1, self.go.pixels[y * self.go.bounds.width + x].y, pixels, xlimit, ylimit)) {
                return true;
            }
        }
        return false;
    }

    fn check_bottom_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        const y = self.go.bounds.height - 1;
        for (0..self.go.bounds.width) |x| {
            if (physics_pixel.pixel_at_x_y(self.go.pixels[y * self.go.bounds.width + x].x, self.go.pixels[y * self.go.bounds.width + x].y + 1, pixels, xlimit, ylimit)) {
                return true;
            }
        }
        return false;
    }

    fn check_right_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        const x = self.go.bounds.width - 1;
        for (0..self.go.bounds.height) |y| {
            if (physics_pixel.pixel_at_x_y(self.go.pixels[y * self.go.bounds.width + x].x + 1, self.go.pixels[y * self.go.bounds.width + x].y, pixels, xlimit, ylimit)) {
                return true;
            }
        }
        return false;
    }

    fn check_top_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        const y = 0;
        for (0..self.go.bounds.width) |x| {
            if (physics_pixel.pixel_at_x_y(self.go.pixels[y * self.go.bounds.width + x].x, self.go.pixels[y * self.go.bounds.width + x].y - 1, pixels, xlimit, ylimit)) {
                return true;
            }
        }
        return false;
    }

    pub fn update(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) void {
        if (self.jumping) {
            self.jumping_duration += 1;
            if (self.jumping_duration >= JUMPING_MAX) {
                self.jumping = false;
                self.jumping_duration = 0;
            }
        }
        if (self.jumping and self.left and !self.check_left_bounds(pixels, xlimit, ylimit) and !self.check_top_bounds(pixels, xlimit, ylimit)) {
            for (0..self.go.pixels.len) |i| {
                self.go.pixels[i].left_update(pixels, xlimit, ylimit);
                self.go.pixels[i].up_update(pixels, xlimit, ylimit);
                self.go.pixels[i].active = true;
                self.go.pixels[i].idle_turns = 0;
            }
        } else if (self.jumping and self.right and !self.check_right_bounds(pixels, xlimit, ylimit) and !self.check_top_bounds(pixels, xlimit, ylimit)) {
            var y: u32 = 0;
            while (y < self.go.bounds.height) : (y += 1) {
                var x: u32 = self.go.bounds.width - 1;
                while (x >= 0) : (x -= 1) {
                    self.go.pixels[y * self.go.bounds.width + x].right_update(pixels, xlimit, ylimit);
                    self.go.pixels[y * self.go.bounds.width + x].up_update(pixels, xlimit, ylimit);
                    self.go.pixels[y * self.go.bounds.width + x].active = true;
                    self.go.pixels[y * self.go.bounds.width + x].idle_turns = 0;
                    if (x == 0) {
                        break;
                    }
                }
            }
        } else if (self.jumping and !self.check_top_bounds(pixels, xlimit, ylimit)) {
            for (0..self.go.pixels.len) |i| {
                self.go.pixels[i].up_update(pixels, xlimit, ylimit);
                self.go.pixels[i].active = true;
                self.go.pixels[i].idle_turns = 0;
            }
        } else {
            if (self.left and !self.check_left_bounds(pixels, xlimit, ylimit)) {
                var y: u32 = self.go.bounds.height - 1;
                while (y >= 0) : (y -= 1) {
                    var x: u32 = 0;
                    while (x < self.go.bounds.width) : (x += 1) {
                        self.go.pixels[y * self.go.bounds.width + x].left_update(pixels, xlimit, ylimit);
                        self.go.pixels[y * self.go.bounds.width + x].active = true;
                        self.go.pixels[y * self.go.bounds.width + x].idle_turns = 0;
                    }
                    if (y == 0) {
                        break;
                    }
                }
            } else if (self.right and !self.check_right_bounds(pixels, xlimit, ylimit)) {
                var y: u32 = self.go.bounds.height - 1;
                while (y >= 0) : (y -= 1) {
                    var x: u32 = self.go.bounds.width - 1;
                    while (x >= 0) : (x -= 1) {
                        self.go.pixels[y * self.go.bounds.width + x].right_update(pixels, xlimit, ylimit);
                        self.go.pixels[y * self.go.bounds.width + x].active = true;
                        self.go.pixels[y * self.go.bounds.width + x].idle_turns = 0;
                        if (x == 0) {
                            break;
                        }
                    }
                    if (y == 0) {
                        break;
                    }
                }
            }
            if (!self.check_bottom_bounds(pixels, xlimit, ylimit)) {
                var y: u32 = self.go.bounds.height - 1;
                while (y >= 0) : (y -= 1) {
                    var x: u32 = self.go.bounds.width - 1;
                    while (x >= 0) : (x -= 1) {
                        self.go.pixels[y * self.go.bounds.width + x].down_update(pixels, xlimit, ylimit);
                        self.go.pixels[y * self.go.bounds.width + x].active = true;
                        self.go.pixels[y * self.go.bounds.width + x].idle_turns = 0;
                        if (x == 0) {
                            break;
                        }
                    }
                    if (y == 0) {
                        break;
                    }
                }
            }
        }
    }
};
