const std = @import("std");
const utils = @import("utils.zig");
const physics_pixel = @import("physics_pixel.zig");
const texture = @import("texture.zig");

pub const Texture = texture.Texture;
pub const PhysicsPixel = physics_pixel.PhysicsPixel;

pub const Error = error{} || texture.Error || utils.Error;

pub const GameObject = struct {
    tex: *Texture,
    pixels: []*PhysicsPixel,
    allocator: std.mem.Allocator,
    bounds: utils.Rectangle,
    status: Status = .None,
    pub const Status = enum {
        Wet,
        None,
    };
    const Self = @This();
    pub fn init(x: i32, y: i32, w_width: u32, tex: *Texture, allocator: std.mem.Allocator) Error!Self {
        var pixels: []*PhysicsPixel = try allocator.alloc(*PhysicsPixel, tex.pixel_buffer.len);
        var x_pix: i32 = x;
        var y_pix: i32 = y;
        for (0..pixels.len) |i| {
            pixels[i] = try allocator.create(PhysicsPixel);
            pixels[i].* = PhysicsPixel.init(physics_pixel.PixelType.Object, x_pix, y_pix);
            pixels[i].set_color(tex.pixel_buffer[i].r, tex.pixel_buffer[i].g, tex.pixel_buffer[i].b);
            pixels[i].managed = true;
            x_pix += 1;
            if (@as(u32, @bitCast(x_pix)) >= (@as(u32, @bitCast(x)) + tex.width) or @as(u32, @bitCast(x_pix)) >= w_width) {
                x_pix = x;
                y_pix += 1;
            }
        }
        return Self{
            .tex = tex,
            .pixels = pixels,
            .allocator = allocator,
            .bounds = .{ .x = x, .y = y, .width = tex.width, .height = tex.height },
        };
    }

    //TODO add status effects, wet/hot/onfire

    pub fn add_sim(self: *Self, pixels: []?*PhysicsPixel, w_width: u32) void {
        for (0..self.pixels.len) |i| {
            const indx: u32 = @as(u32, @bitCast(self.pixels[i].y)) * w_width + @as(u32, @bitCast(self.pixels[i].x));
            if (indx > 0 and indx < pixels.len) {
                pixels[indx] = self.pixels[i];
            }
        }
    }

    pub fn deinit(self: *Self) void {
        for (0..self.pixels.len) |i| {
            self.allocator.destroy(self.pixels[i]);
        }
        self.allocator.free(self.pixels);
    }
};
