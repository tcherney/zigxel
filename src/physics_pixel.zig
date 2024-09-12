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
    Wood,
    Ice,
    Plant,
    Explosive,
    Object,
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
pub const WOOD_COLOR = Pixel{ .r = 97, .g = 69, .b = 47 };
pub const ICE_COLOR = Pixel{ .r = 160, .g = 205, .b = 230 };
pub const PLANT_COLOR = Pixel{ .r = 45, .g = 160, .b = 45 };
pub const EXPLOSIVE_COLOR = Pixel{ .r = 235, .g = 200, .b = 60 };

const Properties = struct {
    color: Pixel,
    solid: bool,
    max_duration: u32,
    density: f32,
    speed: u32,
    piercing: bool,
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
    .speed = 1,
    .piercing = false,
};

const WATER_PROPERTIES: Properties = Properties{
    .color = .{ .r = WATER_COLOR.r, .g = WATER_COLOR.g, .b = WATER_COLOR.b },
    .solid = false,
    .max_duration = 0,
    .density = 1.0,
    .speed = 1,
    .piercing = false,
};

const EMPTY_PROPERTIES: Properties = Properties{
    .color = .{ .r = EMPTY_COLOR.r, .g = EMPTY_COLOR.g, .b = EMPTY_COLOR.b },
    .solid = false,
    .max_duration = 0,
    .density = 0,
    .speed = 1,
    .piercing = false,
};

const WALL_PROPERTIES: Properties = Properties{
    .color = .{ .r = WALL_COLOR.r, .g = WALL_COLOR.g, .b = WALL_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 10.0,
    .speed = 1,
    .piercing = false,
};

const OIL_PROPERTIES: Properties = Properties{
    .color = .{ .r = OIL_COLOR.r, .g = OIL_COLOR.g, .b = OIL_COLOR.b },
    .solid = false,
    .max_duration = 0,
    .density = 0.5,
    .speed = 1,
    .piercing = false,
};

const ROCK_PROPERTIES: Properties = Properties{
    .color = .{ .r = ROCK_COLOR.r, .g = ROCK_COLOR.g, .b = ROCK_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 5.0,
    .speed = 1,
    .piercing = false,
};

const STEAM_PROPERTIES: Properties = Properties{
    .color = .{ .r = STEAM_COLOR.r, .g = STEAM_COLOR.g, .b = STEAM_COLOR.b },
    .solid = false,
    .max_duration = 125,
    .density = 0.1,
    .speed = 1,
    .piercing = false,
};

const FIRE_PROPERTIES: Properties = Properties{
    .color = .{ .r = FIRE_COLOR.r, .g = FIRE_COLOR.g, .b = FIRE_COLOR.b },
    .solid = false,
    .max_duration = 100,
    .density = 0.1,
    .speed = 1,
    .piercing = false,
};

const LAVA_PROPERTIES: Properties = Properties{
    .color = .{ .r = LAVA_COLOR.r, .g = LAVA_COLOR.g, .b = LAVA_COLOR.b },
    .solid = false,
    .max_duration = 300,
    .density = 2.0,
    .speed = 1,
    .piercing = false,
};

const WOOD_PROPERTIES: Properties = Properties{
    .color = .{ .r = WOOD_COLOR.r, .g = WOOD_COLOR.g, .b = WOOD_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 8.0,
    .speed = 1,
    .piercing = false,
};

const ICE_PROPERTIES: Properties = Properties{
    .color = .{ .r = ICE_COLOR.r, .g = ICE_COLOR.g, .b = ICE_COLOR.b },
    .solid = true,
    .max_duration = 300,
    .density = 0.4,
    .speed = 1,
    .piercing = false,
};

const PLANT_PROPERTIES: Properties = Properties{
    .color = .{ .r = PLANT_COLOR.r, .g = PLANT_COLOR.g, .b = PLANT_COLOR.b },
    .solid = true,
    .max_duration = 0,
    .density = 5.0,
    .speed = 1,
    .piercing = false,
};

const EXPLOSIVE_PROPERTIES: Properties = Properties{
    .color = .{ .r = EXPLOSIVE_COLOR.r, .g = EXPLOSIVE_COLOR.g, .b = EXPLOSIVE_COLOR.b },
    .solid = false,
    .max_duration = 30,
    .density = 0.1,
    .speed = 10,
    .piercing = true,
};

const OBJECT_PROPERTIES: Properties = Properties{
    .color = .{ .r = 255, .g = 255, .b = 255 },
    .solid = true,
    .max_duration = 0,
    .density = 10,
    .speed = 1,
    .piercing = false,
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
            .Wood => {
                std.debug.print("wood color\n", .{});
                properties = WOOD_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Ice => {
                std.debug.print("ice color\n", .{});
                properties = ICE_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Plant => {
                std.debug.print("plant color\n", .{});
                properties = PLANT_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Explosive => {
                std.debug.print("explosive color\n", .{});
                properties = EXPLOSIVE_PROPERTIES;
                color = properties.vary_color(10);
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
            .Object => {
                std.debug.print("object color\n", .{});
                properties = OBJECT_PROPERTIES;
                color = properties.color;
                std.debug.print("{d} {d} {d}\n", .{ color.r, color.g, color.b });
            },
        }
        return Self{ .x = x, .y = y, .pixel = Pixel{ .r = color.r, .g = color.g, .b = color.b }, .pixel_type = pixel_type, .last_dir = if (utils.rand.boolean()) -1 else 1, .properties = properties };
    }

    pub fn set_color(self: *Self, r: u8, g: u8, b: u8) void {
        self.pixel = .{ .r = r, .g = g, .b = b };
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
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Wood) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Oil) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Steam) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Wood) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = self.properties.vary_color(10);
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Oil) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Fire) {
            pixel.properties = STEAM_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Steam;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Ice) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Ice) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Plant) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Plant) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Plant) {
            self.properties = PLANT_PROPERTIES;
            self.duration = 0;
            self.pixel_type = .Plant;
            self.pixel = self.properties.vary_color(10);
        } else if (self.pixel_type == .Plant and pixel.pixel_type == .Water) {
            pixel.properties = PLANT_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Plant;
            pixel.pixel = pixel.properties.vary_color(10);
        } else if (self.pixel_type == .Explosive and pixel.pixel_type != .Empty and pixel.pixel_type != .Explosive and pixel.pixel_type != .Steam) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
        }
    }

    fn rock_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
    }

    inline fn execute_move(self: *Self, pixels: []?*PhysicsPixel, x: i32, y: i32, xlimit: u32, ylimit: u32) bool {
        if (in_bounds(x, y, xlimit, ylimit)) {
            const indx: u32 = @as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x));
            if (!pixel_at_x_y(x, y, pixels, xlimit, ylimit) or self.properties.piercing) {
                self.swap_pixel(pixels, x, y, xlimit, ylimit);
                return true;
            } else if (!pixels[indx].?.properties.solid and ((pixels[indx].?.properties.density > self.properties.density and y <= self.y) or
                (pixels[indx].?.properties.density < self.properties.density and y > self.y)))
            {
                self.swap_pixel(pixels, x, y, xlimit, ylimit);
                return true;
            } else if (pixels[indx].?.properties.density == self.properties.density) {
                self.last_dir = -self.last_dir;
            }
        }
        return false;
    }

    fn react_with_neighbors(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        var x: i32 = self.x - 1;
        var y: i32 = self.y - 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        x += 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        x += 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        y += 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        x -= 2;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        y += 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        x += 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
        x += 1;
        if (in_bounds(x, y, xlimit, ylimit)) {
            if (pixels[@as(u32, @bitCast(y)) * xlimit + @as(u32, @bitCast(x))]) |p| {
                if (p.pixel_type != .Empty) {
                    self.reaction(p);
                }
            }
        }
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

    fn fire_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        const first = self.last_dir;
        const second = -first;
        const direction = utils.rand.intRangeAtMost(u8, 0, 7);
        switch (direction) {
            0 => {
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                _ = self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit);
            },
            1 => {
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
            },
            2 => {
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
            },
            3 => {
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
            },
            4 => {
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
            },
            5 => {
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
            },
            6 => {
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
            },
            7 => {
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y + 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + first, self.y - 1, xlimit, ylimit)) return;
                if (self.execute_move(pixels, self.x + second, self.y - 1, xlimit, ylimit)) return;
            },
            else => unreachable,
        }
    }

    //TODO RIGID BODIES maybe box2d?
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
                } else if (self.pixel_type == .Ice) {
                    self.properties = WATER_PROPERTIES;
                    self.duration = 0;
                    self.pixel_type = .Water;
                    self.pixel = self.properties.vary_color(10);
                } else {
                    self.pixel_type = PixelType.Empty;
                }
            }
        }
        for (0..self.properties.speed) |_| {
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
                    self.fire_update(pixels, xlimit, ylimit);
                },
                .Ice => {
                    self.sand_update(pixels, xlimit, ylimit);
                },
                .Explosive => {
                    self.fire_update(pixels, xlimit, ylimit);
                },
                .Object => {
                    self.rock_update(pixels, xlimit, ylimit);
                },
                else => {},
            }
            self.react_with_neighbors(pixels, xlimit, ylimit);
        }
    }
};
