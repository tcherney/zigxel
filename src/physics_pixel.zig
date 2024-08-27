const std = @import("std");
const utils = @import("utils.zig");
const Pixel = @import("image").Pixel;

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
};
