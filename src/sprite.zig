const std = @import("std");
const utils = @import("utils.zig");
const texture = @import("texture.zig");

pub const Error = error{} || texture.Error;
pub const Texture = texture.Texture;

pub const Sprite = struct {
    allocator: std.mem.Allocator,
    src: utils.Rectangle,
    dest: utils.Rectangle,
    tex: Texture,
    pub const Self = @This();
    pub fn init(allocator: std.mem.Allocator, src: utils.Rectangle, dest: utils.Rectangle, tex: Texture) Sprite {
        return Self{ .allocator = allocator, .src = src, .dest = dest, .tex = tex };
    }
};
