const std = @import("std");
const utils = @import("utils.zig");
const Pixel = @import("image").Pixel;

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
    const Self = @This();
    pub fn init(x: i32, y: i32, r: u8, g: u8, b: u8) Self {
        return Self{ .x = x, .y = y, .pixel = Pixel{ .r = r, .g = g, .b = b } };
    }
};
