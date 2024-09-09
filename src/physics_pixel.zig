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
    Steam,
    Fire,
    Lava,
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
pub const STEAM_COLOR = Pixel{ .r = 190, .g = 230, .b = 229 };
pub const FIRE_COLOR = Pixel{ .r = 245, .g = 57, .b = 36 };
pub const LAVA_COLOR = Pixel{ .r = 133, .g = 34, .b = 32 };

const Properties = struct {
    color: Pixel,
    solid: bool,
    max_duration: u32,
    density: f32,
    pub fn vary_color(self: *Properties, variance: i16) Pixel {
        const variation = utils.rand.intRangeAtMost(i16, -variance, variance);
        return Pixel{
            .r = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(self.color.r)))) + variation)))),
            .g = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(self.color.g)))) + variation)))),
            .b = @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(self.color.b)))) + variation)))),
        };
    }
};

const SAND_PROPERTIES: Properties = Properties{
    .color = .{ .r = SAND_COLOR.r, .g = SAND_COLOR.g, .b = SAND_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 3.0,
};

const WATER_PROPERTIES: Properties = Properties{
    .color = .{ .r = WATER_COLOR.r, .g = WATER_COLOR.g, .b = WATER_COLOR.b },
    .solid = false,
    .max_duration = 0,
    .density = 1.0,
};

const EMPTY_PROPERTIES: Properties = Properties{
    .color = .{ .r = EMPTY_COLOR.r, .g = EMPTY_COLOR.g, .b = EMPTY_COLOR.b },
    .solid = false,
    .max_duration = 0,
    .density = 0,
};

const WALL_PROPERTIES: Properties = Properties{
    .color = .{ .r = WALL_COLOR.r, .g = WALL_COLOR.g, .b = WALL_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 10.0,
};

const OIL_PROPERTIES: Properties = Properties{
    .color = .{ .r = OIL_COLOR.r, .g = OIL_COLOR.g, .b = OIL_COLOR.b },
    .solid = false,
    .max_duration = 0,
    .density = 0.5,
};

const ROCK_PROPERTIES: Properties = Properties{
    .color = .{ .r = ROCK_COLOR.r, .g = ROCK_COLOR.g, .b = ROCK_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 5.0,
};

const STEAM_PROPERTIES: Properties = Properties{
    .color = .{ .r = STEAM_COLOR.r, .g = STEAM_COLOR.g, .b = STEAM_COLOR.b },
    .solid = false,
    .max_duration = 125,
    .density = 0.1,
};

const FIRE_PROPERTIES: Properties = Properties{
    .color = .{ .r = FIRE_COLOR.r, .g = FIRE_COLOR.g, .b = FIRE_COLOR.b },
    .solid = false,
    .max_duration = 100,
    .density = 0.1,
};

const LAVA_PROPERTIES: Properties = Properties{
    .color = .{ .r = LAVA_COLOR.r, .g = LAVA_COLOR.g, .b = LAVA_COLOR.b },
    .solid = false,
    .max_duration = 300,
    .density = 2.0,
};

pub const PhysicsPixel = struct {
    pixel: Pixel = undefined,
    x: i32,
    y: i32,
    pixel_type: PixelType,
    dirty: bool = false,
    last_dir: i32 = undefined,
    properties: Properties,
    duration: u32 = 0,
    const Self = @This();
    pub fn init(pixel_type: PixelType, x: i32, y: i32) Self {
        var properties: Properties = undefined;
        var color: Pixel = undefined;
        switch (pixel_type) {
            .Sand => {
                std.debug.print("sand color\n", .{});
                properties = SAND_PROPERTIES;
                color = properties.vary_color(15);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Water => {
                std.debug.print("water color\n", .{});
                properties = WATER_PROPERTIES;
                color = properties.vary_color(15);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Empty => {
                properties = EMPTY_PROPERTIES;
                color = properties.color;
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Wall => {
                properties = WALL_PROPERTIES;
                color = properties.color;
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Oil => {
                std.debug.print("oil color\n", .{});
                properties = OIL_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Rock => {
                std.debug.print("rock color\n", .{});
                properties = ROCK_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Steam => {
                std.debug.print("steam color\n", .{});
                properties = STEAM_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Lava => {
                std.debug.print("lava color\n", .{});
                properties = LAVA_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Fire => {
                std.debug.print("fire color\n", .{});
                properties = FIRE_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
        }
        return Self{ .x = x, .y = y, .pixel = Pixel{ .r = color.r, .g = color.g, .b = color.b }, .pixel_type = pixel_type, .last_dir = if (utils.rand.boolean()) -1 else 1, .properties = properties };
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

    fn reaction(self: *Self, pixel: *PhysicsPixel) void {
        if (self.pixel_type == .Lava and pixel.pixel_type == .Water) {
            pixel.properties = STEAM_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Steam;
            pixel.pixel = pixel.properties.vary_color(10);
            self.properties = ROCK_PROPERTIES;
            self.duration = 0;
            self.pixel_type = .Rock;
            self.pixel = self.properties.vary_color(10);
        }
        // else if (self.pixel_type == .Lava and pixel.pixel_type == .Wood) {
        //     pixel.properties = FIRE_PROPERTIES;
        //     pixel.duration = 0;
        //     pixel.pixel_type = .Fire;
        //     pixel.pixel = pixel.properties.vary_color(10);
        // }
        else if (self.pixel_type == .Lava and pixel.pixel_type == .Oil) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Steam) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
        }
        // else if (self.pixel_type == .Fire and pixel.pixel_type == .Wood) {
        //     pixel.properties = FIRE_PROPERTIES;
        //     pixel.duration = 0;
        //     pixel.pixel_type = .Fire;
        //     pixel.pixel = self.properties.vary_color(10);
        // }
        else if (self.pixel_type == .Fire and pixel.pixel_type == .Oil) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Fire) {
            pixel.properties = STEAM_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Steam;
            pixel.pixel = pixel.properties.vary_color(10);
        }
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
            } else if (!pixels[indx].?.properties.solid and ((pixels[indx].?.properties.density > self.properties.density and y <= self.y) or
                (pixels[indx].?.properties.density < self.properties.density and y > self.y)))
            {
                self.reaction(pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))].?);
                self.swap_pixel(pixels, x, y, xlimit, ylimit);
                return true;
            } else if (pixels[indx].?.properties.density == self.properties.density) {
                self.reaction(pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))].?);
                self.last_dir = -self.last_dir;
            } else {
                self.reaction(pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))].?);
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
        _ = self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit);
    }

    fn gas_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        const first = self.last_dir;
        const second = -first;
        if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
        if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
        if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
        _ = self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit);
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
        if (self.properties.max_duration > 0) {
            self.duration += 1;
            if (self.duration >= self.properties.max_duration) {
                if (self.pixel_type == .Fire) {
                    self.properties = STEAM_PROPERTIES;
                    self.duration = 0;
                    self.pixel_type = .Steam;
                    self.pixel = self.properties.vary_color(10);
                } else if (self.pixel_type == .Lava) {
                    self.properties = ROCK_PROPERTIES;
                    self.duration = 0;
                    self.pixel_type = .Rock;
                    self.pixel = self.properties.vary_color(10);
                } else {
                    self.pixel_type = PixelType.Empty;
                }
            }
        }
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
            .Steam => {
                self.gas_update(pixels, xlimit, ylimit);
            },
            .Lava => {
                self.fluid_update(pixels, xlimit, ylimit);
            },
            .Fire => {
                if (utils.rand.boolean()) {
                    self.gas_update(pixels, xlimit, ylimit);
                } else {
                    self.fluid_update(pixels, xlimit, ylimit);
                }
            },
            else => {},
            //else => self.sand_update(pixels, xlimit, ylimit),
        }
    }
};
