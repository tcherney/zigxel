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
    pub const Biome = enum { desert, forest };
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

    pub fn resize(self: *Self, w_width: u32, w_height: u32, v_width: u32, v_height: u32) Error!void {
        self.tex.deinit();
        self.tex = Texture.init(self.allocator);
        try self.tex.rect(w_width, w_height, 0, 0, 0, 255);
        self.bounds = common.Rectangle{
            .x = 0,
            .y = 0,
            .height = self.tex.height,
            .width = self.tex.width,
        };
        self.viewport = common.Rectangle{
            .x = 0,
            .y = 0,
            .width = v_width,
            .height = v_height,
        };
        var new_pixels: std.ArrayList(?*PhysicsPixel) = std.ArrayList(?*PhysicsPixel).init(self.allocator);
        for (0..self.tex.width * self.tex.height) |i| {
            if (i < self.pixels.items.len) {
                if (self.pixels.items[i] != null) {
                    self.pixels.items[i].?.active = true;
                }
                try new_pixels.append(self.pixels.items[i]);
            } else {
                try new_pixels.append(null);
            }
        }
        const pixels_to_delete = if (WASM) @as(i32, @bitCast(self.pixels.items.len)) - @as(i32, @bitCast(new_pixels.items.len)) else @as(i64, @bitCast(self.pixels.items.len)) - @as(i64, @bitCast(new_pixels.items.len));
        if (pixels_to_delete > 0) {
            for (new_pixels.items.len..self.pixels.items.len) |i| {
                if (self.pixels.items[i] != null) {
                    self.allocator.destroy(self.pixels.items[i].?);
                }
            }
        }
        self.pixels.deinit();
        self.pixels = new_pixels;
    }

    pub fn add_pixel(self: *Self, x: u32, y: u32, p_type: physic_pixel.PixelType) Error!void {
        const indx = y * self.tex.width + x;
        if (indx > self.pixels.items.len) return;
        const y_i32 = @as(i32, @bitCast(y));
        const x_i32 = @as(i32, @bitCast(x));
        if (self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
        }
        self.pixels.items[indx].?.* = PhysicsPixel.init(p_type, x_i32, y_i32);
    }

    fn build_tree(self: *Self, x: usize, y: usize) Error!void {
        const HEIGHT = 5;
        var i: usize = y;
        while (i > y - HEIGHT - 1) : (i -= 1) {
            try self.add_pixel(@intCast(x), @intCast(i), .Wood);
        }
        for (y - HEIGHT - 2..y - HEIGHT + 2) |k| {
            const x_start = if (x < 2) 0 else x - 2;
            for (x_start..x_start + 2) |j| {
                const chance = common.rand.intRangeAtMost(usize, 0, 1);
                if (chance == 0) {
                    try self.add_pixel(@intCast(j), @intCast(k), .Plant);
                    // const plant = common.rand.boolean();
                    // if (plant) {
                    //     try self.add_pixel(@intCast(j), @intCast(k), .Plant);
                    // } else {
                    //     try self.add_pixel(@intCast(j), @intCast(k), .Wood);
                    // }
                }
            }
        }
        if (x > 0) try self.add_pixel(@intCast(x - 1), @intCast(y - HEIGHT - 1), .Plant);
        try self.add_pixel(@intCast(x), @intCast(y - HEIGHT), .Plant);
        try self.add_pixel(@intCast(x), @intCast(y - HEIGHT - 2), .Plant);
        try self.add_pixel(@intCast(x + 1), @intCast(y - HEIGHT - 1), .Plant);
    }
    pub fn generate(self: *Self, biome: Biome) Error!void {
        for (0..self.tex.width * self.tex.height) |_| {
            try self.pixels.append(null);
        }
        const BASE_HEIGHT = 10;
        switch (biome) {
            .desert => {
                for (0..self.tex.width) |j| {
                    const variation = common.rand.intRangeAtMost(usize, 2, BASE_HEIGHT);
                    const start_y = self.tex.height - 1;
                    const end_y = start_y - variation;
                    //std.debug.print("start {any} end {any}\n", .{ start_y, end_y });
                    var missing_pixels: u32 = 0;
                    var i: usize = start_y;
                    while (i > end_y) : (i -= 1) {
                        const should_add = common.rand.intRangeAtMost(usize, 0, 9);
                        if (should_add > 0) {
                            try self.add_pixel(@intCast(j), @intCast(i), .Sand);
                        } else {
                            missing_pixels += 1;
                        }
                    }
                    if (common.rand.intRangeAtMost(usize, 0, 5) == 0) try self.build_tree(j, end_y + missing_pixels);
                }
            },
            .forest => {
                for (0..self.tex.width) |j| {
                    const variation = common.rand.intRangeAtMost(usize, 2, BASE_HEIGHT);
                    const start_y = self.tex.height - 1;
                    const end_y = start_y - variation;
                    //std.debug.print("start {any} end {any}\n", .{ start_y, end_y });
                    var missing_pixels: u32 = 0;
                    var i: usize = start_y;
                    while (i > end_y) : (i -= 1) {
                        const should_add = common.rand.intRangeAtMost(usize, 0, 9);
                        if (should_add > 0) {
                            try self.add_pixel(@intCast(j), @intCast(i), .Plant);
                        } else {
                            missing_pixels += 1;
                        }
                    }
                    if (common.rand.intRangeAtMost(usize, 0, 5) == 0) try self.build_tree(j, end_y + missing_pixels);
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
