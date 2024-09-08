const std = @import("std");
const utils = @import("utils.zig");
const Pixel = @import("image").Pixel;

//https://tomforsyth1000.github.io/papers/cellular_automata_for_physical_modelling.html
//https://blog.macuyiko.com/post/2017/an-exploration-of-cellular-automata-and-graph-based-game-systems-part-2.html
//https://blog.macuyiko.com/post/2020/an-exploration-of-cellular-automata-and-graph-based-game-systems-part-4.html

pub inline fn to_seconds(nano: u64) f64 {
    return @as(f64, @floatFromInt(nano)) / 1_000_000_000.0;
}

pub const PixelType = enum {
    Sand,
    Water,
    Empty,
    Wall,
    Oil,
    Rock,
};

pub inline fn pixel_at_x_y(x: i32, y: i32, pixels: []?*PhysicsPixel, width: u32, height: u32) bool {
    return if (x < 0 or x >= width or y < 0 or y >= height) false else if (pixels[@as(u32, @bitCast(y)) * width + @as(u32, @bitCast(x))] == null) false else pixels[@as(u32, @bitCast(y)) * width + @as(u32, @bitCast(x))].?.pixel_type != .Empty;
}

pub const SAND_COLOR = Pixel{ .r = 210, .g = 180, .b = 125 };
pub const WATER_COLOR = Pixel{ .r = 50, .g = 133, .b = 168 };
pub const EMPTY_COLOR = Pixel{ .r = 252, .g = 3, .b = 190 };
pub const WALL_COLOR = Pixel{ .r = 46, .g = 7, .b = 0 };
pub const OIL_COLOR = Pixel{ .r = 65, .g = 35, .b = 10 };
pub const ROCK_COLOR = Pixel{ .r = 50, .g = 50, .b = 50 };

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
    pixel_type: PixelType,
    dirty: bool = false,
    last_dir: i32 = undefined,
    density: f32,
    solid: bool,
    const Self = @This();
    pub fn init(pixel_type: PixelType, x: i32, y: i32) Self {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        var density: f32 = undefined;
        var solid: bool = undefined;
        switch (pixel_type) {
            .Sand => {
                std.debug.print("sand color\n", .{});
                const variation = utils.rand.intRangeAtMost(i16, -30, 30);
                r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(SAND_COLOR.r)))) + variation))));
                g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(SAND_COLOR.g)))) + variation))));
                b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(SAND_COLOR.b)))) + variation))));
                std.debug.print("{d} {d} {d}\n", .{ r, g, b });
                density = 3.0;
                solid = true;
            },
            .Water => {
                std.debug.print("water color\n", .{});
                const variation = utils.rand.intRangeAtMost(i16, -30, 30);
                r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(WATER_COLOR.r)))) + variation))));
                g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(WATER_COLOR.g)))) + variation))));
                b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(WATER_COLOR.b)))) + variation))));
                std.debug.print("{d} {d} {d}\n", .{ r, g, b });
                density = 1.0;
                solid = false;
            },
            .Empty => {
                r = EMPTY_COLOR.r;
                g = EMPTY_COLOR.g;
                b = EMPTY_COLOR.b;
                density = 0;
                solid = false;
            },
            .Wall => {
                r = WALL_COLOR.r;
                g = WALL_COLOR.g;
                b = WALL_COLOR.b;
                density = 10.0;
                solid = true;
            },
            .Oil => {
                std.debug.print("oil color\n", .{});
                const variation = utils.rand.intRangeAtMost(i16, -10, 10);
                r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(OIL_COLOR.r)))) + variation))));
                g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(OIL_COLOR.g)))) + variation))));
                b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(OIL_COLOR.b)))) + variation))));
                std.debug.print("{d} {d} {d}\n", .{ r, g, b });
                density = 0.5;
                solid = false;
            },
            .Rock => {
                std.debug.print("rock color\n", .{});
                const variation = utils.rand.intRangeAtMost(i16, -10, 10);
                r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(ROCK_COLOR.r)))) + variation))));
                g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(ROCK_COLOR.g)))) + variation))));
                b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(ROCK_COLOR.b)))) + variation))));
                std.debug.print("{d} {d} {d}\n", .{ r, g, b });
                density = 5.0;
                solid = true;
            },
        }
        return Self{ .x = x, .y = y, .pixel = Pixel{ .r = r, .g = g, .b = b }, .pixel_type = pixel_type, .last_dir = if (utils.rand.boolean()) -1 else 1, .solid = solid, .density = density };
    }

    inline fn swap_pixel(self: *Self, pixels: []?*PhysicsPixel, x: i32, y: i32, xlimit: u32, _: u32) void {
        const indx = @as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x));
        const self_indx = @as(u32, @bitCast(self.y)) * xlimit + @as(u32, @bitCast(self.x));
        const dir: i32 = if (x > self.x) 1 else if (x < self.x) -1 else self.last_dir;
        pixels[self_indx] = pixels[indx];
        if (pixels[self_indx] != null) {
            pixels[self_indx].?.*.x = self.x;
            pixels[self_indx].?.*.y = self.y;
            pixels[self_indx].?.*.last_dir = -dir;
        }
        pixels[indx] = self;
        self.x = x;
        self.y = y;
        self.dirty = true;
        self.last_dir = dir;
    }

    inline fn in_bounds(x: i32, y: i32, xlimit: u32, ylimit: u32) bool {
        return x >= 0 and @as(u32, @bitCast(x)) < xlimit and y >= 0 and @as(u32, @bitCast(y)) < ylimit;
    }

    fn sand_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        const first = self.last_dir;
        const second = -first;
        if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
        if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
        if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
    }

    fn rock_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
    }

    inline fn execute_move(self: *Self, pixels: []?*PhysicsPixel, x: i32, y: i32, xlimit: u32, ylimit: u32) bool {
        if (in_bounds(x, y, xlimit, ylimit)) {
            const indx: u32 = @as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x));
            if (!pixel_at_x_y(x, y, pixels, xlimit, ylimit)) {
                self.swap_pixel(pixels, x, y, xlimit, ylimit);
                return true;
            } else if (!pixels[indx].?.solid and ((pixels[indx].?.density > self.density and y <= self.y) or
                (pixels[indx].?.density < self.density and y > self.y)))
            {
                self.swap_pixel(pixels, x, y, xlimit, ylimit);
                return true;
            } else if (pixels[indx].?.density == self.density) {
                self.last_dir = -self.last_dir;
            }
        }
        return false;
    }

    fn fluid_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        const first = self.last_dir;
        const second = -first;
        if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
        if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
        if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
        if (!self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
    }

    // fn base_update(self: *Self, delta: u64, pixels: std.ArrayList(PhysicsPixel), xlimit: u32, ylimit: u32) void {
    //     _ = xlimit;
    //     self.vel.y += GRAVITY.y * to_seconds(delta);
    //     self.yf += self.vel.y * to_seconds(delta);
    //     self.xf += self.vel.x * to_seconds(delta);
    //     const diff = @as(i32, @intFromFloat(self.yf)) - self.y;
    //     for (0..@as(usize, @intCast(diff))) |_| {
    //         if (pixel_at_x_y(self.x, self.y + 1, pixels)) {
    //             self.yf = @as(f64, @floatFromInt(self.y));
    //             self.vel.y = 0;
    //             break;
    //         } else if (self.y + 1 >= ylimit) {
    //             break;
    //         } else {
    //             self.y += 1;
    //         }
    //     }
    // }

    pub fn update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        switch (self.pixel_type) {
            .Sand => {
                self.sand_update(pixels, xlimit, ylimit);
            },
            .Water => {
                self.fluid_update(pixels, xlimit, ylimit);
            },
            .Oil => {
                self.fluid_update(pixels, xlimit, ylimit);
            },
            .Rock => {
                self.rock_update(pixels, xlimit, ylimit);
            },
            else => {},
            //else => self.sand_update(pixels, xlimit, ylimit),
        }
    }
};
