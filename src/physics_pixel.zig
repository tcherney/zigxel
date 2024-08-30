const std = @import("std");
const utils = @import("utils.zig");
const Pixel = @import("image").Pixel;

pub const GRAVITY = 9.8;

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

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
    xf: f64,
    yf: f64,
    pixel_type: PixelType,
    const Self = @This();
    pub fn init(pixel_type: PixelType, x: i32, y: i32, r: u8, g: u8, b: u8) Self {
        return Self{ .x = x, .y = y, .xf = @floatFromInt(x), .yf = @floatFromInt(y), .pixel = Pixel{ .r = r, .g = g, .b = b }, .pixel_type = pixel_type };
    }

    // delta in nanoseconds
    pub fn update(self: *Self, delta: u64, pixels: std.ArrayList(PhysicsPixel), xlimit: u32, ylimit: u32) void {
        switch (self.pixel_type) {
            .Sand => {
                self.yf += GRAVITY * to_seconds(delta);
                const diff = @as(i32, @intFromFloat(self.yf)) - self.y;
                for (0..@as(usize, @intCast(diff))) |_| {
                    if (pixel_at_x_y(self.x, self.y + 1, pixels)) {
                        if (self.x - 1 >= 0 and !pixel_at_x_y(self.x - 1, self.y + 1, pixels)) {
                            self.x -= 1;
                        } else if (self.x + 1 <= xlimit and !pixel_at_x_y(self.x + 1, self.y + 1, pixels)) {
                            self.x += 1;
                        } else {
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
