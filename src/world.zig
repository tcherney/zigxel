pub const texture = @import("texture.zig");
pub const common = @import("common");
pub const physic_pixel = @import("physics_pixel.zig");
pub const std = @import("std");
pub const builtin = @import("builtin");

pub const Texture = texture.Texture;
pub const PhysicsPixel = physic_pixel.PhysicsPixel;
const WASM = builtin.os.tag == .emscripten;
pub const World = struct {
    tex: Texture,
    bounds: common.Rectangle,
    viewport: common.Rectangle = undefined,
    allocator: std.mem.Allocator,
    pixels: std.ArrayList(?*PhysicsPixel),
    const Self = @This();
    pub const Error = error{} || Texture.Error || std.mem.Allocator.Error;
    pub const Biome = enum { desert };
    pub fn init(w_width: u32, w_height: u32, v_width: u32, v_height: u32, allocator: std.mem.Allocator) Error!Self {
        var world_tex = Texture.init(allocator);
        try world_tex.rect(w_width, w_height, 0, 0, 0, 255);
        return Self{
            .tex = world_tex,
            .bounds = common.Rectangle{
                .x = 0,
                .y = 0,
                .height = world_tex.height,
                .width = world_tex.width,
            },
            .viewport = common.Rectangle{
                .x = 0,
                .y = 0,
                .width = v_width,
                .height = v_height,
            },
            .allocator = allocator,
            .pixels = std.ArrayList(?*PhysicsPixel).init(allocator),
        };
    }
    pub fn generate(self: *Self, biome: Biome) Error!void {
        for (0..self.tex.width * self.tex.height) |_| {
            try self.pixels.append(null);
        }
        const BASE_HEIGHT = 10;
        switch (biome) {
            .desert => {
                for (0..BASE_HEIGHT) |i| {
                    for (0..self.tex.width) |j| {
                        const indx = i * self.tex.width + j;
                        const i_i32 = if (WASM) @as(i32, @bitCast(i)) else @as(i32, @intCast(@as(i64, @bitCast(i))));
                        const j_i32 = if (WASM) @as(i32, @bitCast(j)) else @as(i32, @intCast(@as(i64, @bitCast(j))));
                        self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
                        self.pixels.items[indx].?.* = PhysicsPixel.init(.Sand, j_i32, i_i32);
                    }
                }
            },
        }
    }

    pub fn print(self: *Self) Error!void {
        try texture.image_core.write_BMP(self.allocator, self.tex.pixel_buffer, self.tex.width, self.tex.height, "world.bmp");
    }

    pub fn deinit(self: *Self) void {
        self.tex.deinit();
        for (0..self.pixels.items.len) |i| {
            if (self.pixels.items[i] != null and !self.pixels.items[i].?.managed) {
                self.allocator.destroy(self.pixels.items[i].?);
            }
        }
        self.pixels.deinit();
    }
};
