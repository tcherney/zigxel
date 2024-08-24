const std = @import("std");
const utils = @import("utils.zig");
const texture = @import("texture.zig");
const image = @import("image");

pub const Error = error{} || texture.Error || std.mem.Allocator.Error;
pub const Texture = texture.Texture;

pub const Sprite = struct {
    allocator: std.mem.Allocator,
    src: utils.Rectangle,
    dest: utils.Rectangle,
    tex: Texture,
    scaled_buffer: ?[]texture.Pixel = null,
    pub const Self = @This();
    pub fn init(allocator: std.mem.Allocator, src: utils.Rectangle, dest: utils.Rectangle, tex: Texture) Error!Sprite {
        var ret = Self{ .allocator = allocator, .src = src, .dest = dest, .tex = tex };
        if (src.width != dest.width or src.height != src.height) {
            try ret.scale_buffer();
        }
        return ret;
    }
    pub fn deinit(self: *Self) void {
        if (self.scaled_buffer != null) {
            self.allocator.free(self.scaled_buffer.?);
        }
    }
    pub fn scale_buffer(self: *Self) Error!void {
        if (self.scaled_buffer != null) {
            self.allocator.free(self.scaled_buffer.?);
        }

        var src_buffer: []texture.Pixel = undefined;
        var free_mem: bool = false;
        if (self.src.x == 0 and self.src.y == 0 and self.src.width == self.tex.width and self.src.height == self.tex.height) {
            src_buffer = self.tex.pixel_buffer;
        } else {
            src_buffer = try self.allocator.alloc(texture.Pixel, self.src.height * self.src.width);
            free_mem = true;
            var buffer_indx: usize = 0;
            for (@as(u32, @bitCast(self.src.y))..@as(u32, @bitCast(self.src.y)) + self.src.height) |i| {
                for (@as(u32, @bitCast(self.src.x))..@as(u32, @bitCast(self.src.x)) + self.src.width) |j| {
                    src_buffer[buffer_indx].r = self.tex.pixel_buffer[i * self.tex.width + j].r;
                    src_buffer[buffer_indx].g = self.tex.pixel_buffer[i * self.tex.width + j].g;
                    src_buffer[buffer_indx].b = self.tex.pixel_buffer[i * self.tex.width + j].b;
                    src_buffer[buffer_indx].a = self.tex.pixel_buffer[i * self.tex.width + j].a;
                    buffer_indx += 1;
                }
            }
        }

        const scaled_buffer = try image.ImageCore.init(self.allocator, self.src.width, self.src.height, src_buffer).nearest_neighbor(self.dest.width, self.dest.height);
        self.scaled_buffer = scaled_buffer;
        if (free_mem) {
            self.allocator.free(src_buffer);
        }
        std.debug.print("{any}\n", .{self.scaled_buffer});
    }
    pub fn set_src(self: *Self, src: utils.Rectangle) Error!void {
        self.src.x = src.x;
        self.src.y = src.y;
        self.src.height = src.height;
        self.src.width = src.width;
        if (src.width != self.dest.width and src.height != self.dest.height) {
            self.scale_buffer();
        }
    }
    pub fn set_dest(self: *Self, dest: utils.Rectangle) Error!void {
        self.dest.x = dest.x;
        self.dest.y = dest.y;
        self.dest.height = dest.height;
        self.dest.width = dest.width;
        if (dest.width != self.dest.width and dest.height != self.dest.height) {
            self.scale_buffer();
        }
    }
};
