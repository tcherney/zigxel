const std = @import("std");
const utils = @import("utils.zig");
const texture = @import("texture.zig");
const image = @import("image");

pub const Texture = texture.Texture;

pub const Sprite = struct {
    allocator: std.mem.Allocator,
    src: utils.Rectangle,
    dest: utils.Rectangle,
    tex: *Texture,
    scaled_buffer: ?[]texture.Pixel = null,
    pub const Self = @This();
    pub const Error = error{OutOfBounds} || Texture.Error || std.mem.Allocator.Error;
    pub fn init(allocator: std.mem.Allocator, src: ?utils.Rectangle, dest: ?utils.Rectangle, tex: *Texture) Error!Sprite {
        var src_rect: utils.Rectangle = undefined;
        var dest_rect: utils.Rectangle = undefined;
        if (src == null) {
            src_rect = utils.Rectangle{ .x = 0, .y = 0, .width = tex.width, .height = tex.height };
        } else {
            src_rect = src.?;
        }
        if (dest == null) {
            dest_rect = utils.Rectangle{ .x = 0, .y = 0, .width = tex.width, .height = tex.height };
        } else {
            dest_rect = dest.?;
        }
        if (src_rect.x > tex.width or src_rect.y > tex.height or src_rect.width > tex.width or src_rect.height > tex.height) {
            return Error.OutOfBounds;
        }
        var ret = Self{ .allocator = allocator, .src = src_rect, .dest = dest_rect, .tex = tex };
        if (src_rect.width != dest_rect.width or src_rect.height != dest_rect.height) {
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
                    src_buffer[buffer_indx].v = self.tex.pixel_buffer[i * self.tex.width + j].v;
                    buffer_indx += 1;
                }
            }
        }

        const scaled_buffer = try image.ImageCore.init(self.allocator, self.src.width, self.src.height, src_buffer).nearest_neighbor(self.dest.width, self.dest.height);
        self.scaled_buffer = scaled_buffer;
        if (free_mem) {
            self.allocator.free(src_buffer);
        }
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
