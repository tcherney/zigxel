const std = @import("std");
const utils = @import("utils.zig");
const Pixel = @import("image").Pixel;

pub const GRAVITY: Velocity = Velocity{ .x = 0, .y = 9.8 };

pub inline fn to_seconds(nano: u64) f64 {
    return @as(f64, @floatFromInt(nano)) / 1_000_000_000.0;
}

pub const PixelType = enum {
    Sand,
    Water,
};

pub inline fn pixel_at_x_y(x: i32, y: i32, pixels: std.ArrayList(PhysicsPixel)) bool {
    for (pixels.items) |p| {
        if (p.x == x and p.y == y) {
            return true;
        }
    }
    return false;
}

pub const Velocity = struct {
    x: f64,
    y: f64,
};

pub const SAND_COLOR = Pixel{ .r = 210, .g = 180, .b = 125 };

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
    xf: f64,
    yf: f64,
    vel: Velocity = Velocity{ .x = 0, .y = 0 },
    pixel_type: PixelType,
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
                // r = SAND_COLOR.r;
                // g = SAND_COLOR.g;
                // b = SAND_COLOR.b;
            },
            .Water => {},
        }
        return Self{ .x = x, .y = y, .xf = @floatFromInt(x), .yf = @floatFromInt(y), .pixel = Pixel{ .r = r, .g = g, .b = b }, .pixel_type = pixel_type };
    }

    // delta in nanoseconds
    pub fn update(self: *Self, delta: u64, pixels: std.ArrayList(PhysicsPixel), xlimit: u32, ylimit: u32) void {
        switch (self.pixel_type) {
            .Sand => {
                self.vel.y += GRAVITY.y * to_seconds(delta);
                self.yf += self.vel.y * to_seconds(delta);
                self.xf += self.vel.x * to_seconds(delta);
                const diff = @as(i32, @intFromFloat(self.yf)) - self.y;
                for (0..@as(usize, @intCast(diff))) |_| {
                    if (pixel_at_x_y(self.x, self.y + 1, pixels)) {
                        if (self.x - 1 >= 0 and !pixel_at_x_y(self.x - 1, self.y + 1, pixels)) {
                            self.x -= 1;
                            self.xf = @as(f64, @floatFromInt(self.x));
                        } else if (self.x + 1 <= xlimit and !pixel_at_x_y(self.x + 1, self.y + 1, pixels)) {
                            self.x += 1;
                            self.xf = @as(f64, @floatFromInt(self.x));
                        } else {
                            self.yf = @as(f64, @floatFromInt(self.y));
                            self.vel.y = 0;
                            break;
                        }
                    }
                    if (self.y + 1 >= ylimit) {
                        break;
                    } else {
                        self.y += 1;
                    }
                }
            },
            .Water => {},
        }
    }
};
