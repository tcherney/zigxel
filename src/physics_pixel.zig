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
};

pub inline fn pixel_at_x_y(x: i32, y: i32, pixels: []?*PhysicsPixel, width: u32, height: u32) bool {
    return if (x < 0 or x >= width or y < 0 or y >= height) false else pixels[@as(u32, @bitCast(y)) * width + @as(u32, @bitCast(x))] != null;
}

pub const SAND_COLOR = Pixel{ .r = 210, .g = 180, .b = 125 };
pub const WATER_COLOR = Pixel{ .r = 50, .g = 133, .b = 168 };

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
    pixel_type: PixelType,
    dirty: bool = false,
    last_dir: i32 = undefined,
    const Self = @This();
    pub fn init(pixel_type: PixelType, x: i32, y: i32) Self {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        switch (pixel_type) {
            .Sand => {
                std.debug.print("sand color\n", .{});
                const variation = utils.rand.intRangeAtMost(i16, -30, 30);
                r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(SAND_COLOR.r)))) + variation))));
                g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(SAND_COLOR.g)))) + variation))));
                b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(SAND_COLOR.b)))) + variation))));
                std.debug.print("{d} {d} {d}\n", .{ r, g, b });
            },
            .Water => {
                std.debug.print("water color\n", .{});
                const variation = utils.rand.intRangeAtMost(i16, -30, 30);
                r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(WATER_COLOR.r)))) + variation))));
                g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(WATER_COLOR.g)))) + variation))));
                b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(WATER_COLOR.b)))) + variation))));
                std.debug.print("{d} {d} {d}\n", .{ r, g, b });
            },
        }
        return Self{ .x = x, .y = y, .pixel = Pixel{ .r = r, .g = g, .b = b }, .pixel_type = pixel_type, .last_dir = if (utils.rand.boolean()) -1 else 1 };
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
        if (in_bounds(self.x, self.y + 1, xlimit, ylimit) and !pixel_at_x_y(self.x, self.y + 1, pixels, xlimit, ylimit)) {
            self.swap_pixel(pixels, self.x, self.y + 1, xlimit, ylimit);
        } else if (in_bounds(self.x + first, self.y + 1, xlimit, ylimit) and !pixel_at_x_y(self.x + first, self.y + 1, pixels, xlimit, ylimit)) {
            self.swap_pixel(pixels, self.x + first, self.y + 1, xlimit, ylimit);
        } else if (in_bounds(self.x + second, self.y + 1, xlimit, ylimit) and !pixel_at_x_y(self.x + second, self.y + 1, pixels, xlimit, ylimit)) {
            self.swap_pixel(pixels, self.x + second, self.y + 1, xlimit, ylimit);
        }
    }

    fn water_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        const first = self.last_dir;
        const second = -first;
        if (in_bounds(self.x, self.y + 1, xlimit, ylimit) and !pixel_at_x_y(self.x, self.y + 1, pixels, xlimit, ylimit)) {
            self.swap_pixel(pixels, self.x, self.y + 1, xlimit, ylimit);
        } else if (in_bounds(self.x + first, self.y + 1, xlimit, ylimit) and !pixel_at_x_y(self.x + first, self.y + 1, pixels, xlimit, ylimit)) {
            self.swap_pixel(pixels, self.x + first, self.y + 1, xlimit, ylimit);
        } else if (in_bounds(self.x + second, self.y + 1, xlimit, ylimit) and !pixel_at_x_y(self.x + second, self.y + 1, pixels, xlimit, ylimit)) {
            self.swap_pixel(pixels, self.x + second, self.y + 1, xlimit, ylimit);
        } else {
            if (in_bounds(self.x + first, self.y, xlimit, ylimit) and !pixel_at_x_y(self.x + first, self.y, pixels, xlimit, ylimit)) {
                self.swap_pixel(pixels, self.x + first, self.y, xlimit, ylimit);
            } else {
                self.last_dir = -self.last_dir;
            }
        }
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
                self.water_update(pixels, xlimit, ylimit);
            },
            //else => self.sand_update(pixels, xlimit, ylimit),
        }
    }
};
