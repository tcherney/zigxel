const std = @import("std");
const utils = @import("utils.zig");
const Pixel = @import("image").Pixel;

//https://tomforsyth1000.github.io/papers/cellular_automata_for_physical_modelling.html
//https://blog.macuyiko.com/post/2017/an-exploration-of-cellular-automata-and-graph-based-game-systems-part-2.html
//https://blog.macuyiko.com/post/2020/an-exploration-of-cellular-automata-and-graph-based-game-systems-part-4.html

pub inline fn to_seconds(nano: u64) f64 {
    return @as(f64, @floatFromInt(nano)) / 1_000_000_000.0;
}

const PHYSICS_PIXEL_LOG = std.log.scoped(.physics_pixel);
pub const ObjectReactionCallback = utils.Callback(PixelType);
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

pub const SAND_COLOR = Pixel.init(210, 180, 125, null);
pub const WATER_COLOR = Pixel.init(50, 133, 168, null);
pub const EMPTY_COLOR = Pixel.init(252, 3, 190, null);
pub const WALL_COLOR = Pixel.init(46, 7, 0, null);
pub const OIL_COLOR = Pixel.init(65, 35, 10, null);
pub const ROCK_COLOR = Pixel.init(50, 50, 50, null);
pub const STEAM_COLOR = Pixel.init(190, 230, 229, null);
pub const FIRE_COLOR = Pixel.init(245, 57, 36, null);
pub const LAVA_COLOR = Pixel.init(133, 34, 32, null);
pub const WOOD_COLOR = Pixel.init(97, 69, 47, null);
pub const ICE_COLOR = Pixel.init(160, 205, 230, null);
pub const PLANT_COLOR = Pixel.init(45, 160, 45, null);
pub const EXPLOSIVE_COLOR = Pixel.init(235, 200, 60, null);

const Properties = struct {
    color: Pixel,
    solid: bool,
    max_duration: u32,
    density: f32,
    speed: u32,
    piercing: bool,
    pub fn vary_color(self: *Properties, variance: i16) Pixel {
        const variation = utils.rand.intRangeAtMost(i16, -variance, variance);
        return Pixel.init(
            @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(self.color.get_r())))) + variation)))),
            @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(self.color.get_g())))) + variation)))),
            @as(u8, @intCast(@as(u16, @bitCast(@as(i16, @bitCast(@as(u16, @intCast(self.color.get_b())))) + variation)))),
            null,
        );
    }
};

pub const SAND_PROPERTIES: Properties = Properties{
    .color = Pixel.init(SAND_COLOR.get_r(), SAND_COLOR.get_g(), SAND_COLOR.get_b(), null),
    .solid = true,
    .max_duration = 0,
    .density = 3.0,
    .speed = 1,
    .piercing = false,
};

pub const WATER_PROPERTIES: Properties = Properties{
    .color = Pixel.init(WATER_COLOR.get_r(), WATER_COLOR.get_g(), WATER_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 0,
    .density = 1.0,
    .speed = 1,
    .piercing = false,
};

pub const EMPTY_PROPERTIES: Properties = Properties{
    .color = Pixel.init(EMPTY_COLOR.get_r(), EMPTY_COLOR.get_g(), EMPTY_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 0,
    .density = 0,
    .speed = 1,
    .piercing = false,
};

pub const WALL_PROPERTIES: Properties = Properties{
    .color = Pixel.init(WALL_COLOR.get_r(), WALL_COLOR.get_g(), WALL_COLOR.get_b(), null),
    .solid = true,
    .max_duration = 0,
    .density = 10.0,
    .speed = 1,
    .piercing = false,
};

pub const OIL_PROPERTIES: Properties = Properties{
    .color = Pixel.init(OIL_COLOR.get_r(), OIL_COLOR.get_g(), OIL_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 0,
    .density = 0.5,
    .speed = 1,
    .piercing = false,
};

pub const ROCK_PROPERTIES: Properties = Properties{
    .color = Pixel.init(ROCK_COLOR.get_r(), ROCK_COLOR.get_g(), ROCK_COLOR.get_b(), null),
    .solid = true,
    .max_duration = 0,
    .density = 5.0,
    .speed = 1,
    .piercing = false,
};

pub const STEAM_PROPERTIES: Properties = Properties{
    .color = Pixel.init(STEAM_COLOR.get_r(), STEAM_COLOR.get_g(), STEAM_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 125,
    .density = 0.1,
    .speed = 1,
    .piercing = false,
};

pub const FIRE_PROPERTIES: Properties = Properties{
    .color = Pixel.init(FIRE_COLOR.get_r(), FIRE_COLOR.get_g(), FIRE_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 100,
    .density = 0.1,
    .speed = 1,
    .piercing = false,
};

pub const LAVA_PROPERTIES: Properties = Properties{
    .color = Pixel.init(LAVA_COLOR.get_r(), LAVA_COLOR.get_g(), LAVA_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 300,
    .density = 2.0,
    .speed = 1,
    .piercing = false,
};

pub const WOOD_PROPERTIES: Properties = Properties{
    .color = Pixel.init(WOOD_COLOR.get_r(), WOOD_COLOR.get_g(), WOOD_COLOR.get_b(), null),
    .solid = true,
    .max_duration = 0,
    .density = 8.0,
    .speed = 1,
    .piercing = false,
};

pub const ICE_PROPERTIES: Properties = Properties{
    .color = Pixel.init(ICE_COLOR.get_r(), ICE_COLOR.get_g(), ICE_COLOR.get_b(), null),
    .solid = true,
    .max_duration = 300,
    .density = 0.4,
    .speed = 1,
    .piercing = false,
};

pub const PLANT_PROPERTIES: Properties = Properties{
    .color = Pixel.init(PLANT_COLOR.get_r(), PLANT_COLOR.get_g(), PLANT_COLOR.get_b(), null),
    .solid = true,
    .max_duration = 0,
    .density = 5.0,
    .speed = 1,
    .piercing = false,
};

pub const EXPLOSIVE_PROPERTIES: Properties = Properties{
    .color = Pixel.init(EXPLOSIVE_COLOR.get_r(), EXPLOSIVE_COLOR.get_g(), EXPLOSIVE_COLOR.get_b(), null),
    .solid = false,
    .max_duration = 30,
    .density = 0.1,
    .speed = 10,
    .piercing = true,
};

pub const OBJECT_PROPERTIES: Properties = Properties{
    .color = Pixel.init(255, 255, 255, null),
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
    active: bool = true,
    idle_turns: u32 = 0,
    updated: bool = false,
    managed: bool = false,
    object_reaction_callback: ?ObjectReactionCallback = null,
    const Self = @This();
    pub fn init(pixel_type: PixelType, x: i32, y: i32) Self {
        var properties: Properties = undefined;
        var color: Pixel = undefined;
        switch (pixel_type) {
            .Sand => {
                properties = SAND_PROPERTIES;
                color = properties.vary_color(15);
            },
            .Water => {
                properties = WATER_PROPERTIES;
                color = properties.vary_color(15);
            },
            .Empty => {
                properties = EMPTY_PROPERTIES;
                color = properties.color;
            },
            .Wall => {
                properties = WALL_PROPERTIES;
                color = properties.color;
            },
            .Oil => {
                properties = OIL_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Rock => {
                properties = ROCK_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Steam => {
                properties = STEAM_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Lava => {
                properties = LAVA_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Fire => {
                properties = FIRE_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Wood => {
                properties = WOOD_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Ice => {
                properties = ICE_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Plant => {
                properties = PLANT_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Explosive => {
                properties = EXPLOSIVE_PROPERTIES;
                color = properties.vary_color(10);
            },
            .Object => {
                properties = OBJECT_PROPERTIES;
                color = properties.color;
            },
        }
        return Self{ .x = x, .y = y, .pixel = Pixel.init(color.get_r(), color.get_g(), color.get_b(), null), .pixel_type = pixel_type, .last_dir = if (utils.rand.boolean()) -1 else 1, .properties = properties };
    }

    pub fn set_color(self: *Self, r: u8, g: u8, b: u8, a: u8) void {
        self.pixel = Pixel.init(r, g, b, a);
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
            pixels[self_indx].?.*.active = true;
            pixels[self_indx].?.*.idle_turns = 0;
        }
        pixels[indx] = self;
        self.x = x;
        self.y = y;
        self.updated = true;
        self.dirty = true;
        self.last_dir = dir;
    }

    pub inline fn in_bounds(x: i32, y: i32, xlimit: u32, ylimit: u32) bool {
        return x >= 0 and @as(u32, @bitCast(x)) < xlimit and y >= 0 and @as(u32, @bitCast(y)) < ylimit;
    }

    pub fn left_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        _ = self.execute_move(pixels, self.x - 1, self.y, xlimit, ylimit);
    }

    pub fn right_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        _ = self.execute_move(pixels, self.x + 1, self.y, xlimit, ylimit);
    }

    pub fn up_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        _ = self.execute_move(pixels, self.x, self.y - 1, xlimit, ylimit);
    }

    pub fn down_update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        _ = self.execute_move(pixels, self.x, self.y + 1, xlimit, ylimit);
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
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Wood) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Oil) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Steam) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Wood) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = self.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Oil) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Fire) {
            pixel.properties = STEAM_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Steam;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Ice) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Ice) {
            pixel.properties = WATER_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Water;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Fire and pixel.pixel_type == .Plant) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Lava and pixel.pixel_type == .Plant) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Water and pixel.pixel_type == .Plant) {
            self.properties = PLANT_PROPERTIES;
            self.duration = 0;
            self.pixel_type = .Plant;
            self.pixel = self.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Plant and pixel.pixel_type == .Water) {
            pixel.properties = PLANT_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Plant;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Explosive and pixel.pixel_type != .Empty and pixel.pixel_type != .Explosive and pixel.pixel_type != .Steam) {
            pixel.properties = FIRE_PROPERTIES;
            pixel.duration = 0;
            pixel.pixel_type = .Fire;
            pixel.pixel = pixel.properties.vary_color(10);
            self.updated = true;
            pixel.active = true;
            self.active = true;
            self.idle_turns = 0;
            pixel.idle_turns = 0;
        } else if (self.pixel_type == .Object and pixel.pixel_type != .Object) {
            if (self.object_reaction_callback) |func| {
                func.call(pixel.pixel_type);
            }
        }
    }

    pub fn on_object_reaction(self: *Self, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
        self.object_reaction_callback = ObjectReactionCallback.init(CONTEXT_TYPE, func, context);
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
            } else if ((!pixels[indx].?.properties.solid and ((pixels[indx].?.properties.density > self.properties.density and y <= self.y) or
                (pixels[indx].?.properties.density < self.properties.density and y > self.y))) or (self.pixel_type == .Object and !pixels[indx].?.properties.solid and pixels[indx].?.properties.density <= self.properties.density))
            {
                self.swap_pixel(pixels, x, y, xlimit, ylimit);
                return true;
            } else if (pixels[indx].?.properties.density == self.properties.density) {
                self.last_dir = -self.last_dir;
            }
        }
        return false;
    }

    pub fn react_with_neighbors(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
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

    pub fn update(self: *Self, pixels: []?*PhysicsPixel, xlimit: u32, ylimit: u32) void {
        if (self.active) {
            self.updated = false;
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
                self.updated = true;
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
                    else => {},
                }
                self.react_with_neighbors(pixels, xlimit, ylimit);
            }
            if (self.updated) {
                self.active = true;
                self.idle_turns = 0;
            }
        }
        //TODO figure out better way to sleep pixels
        self.idle_turns += 1;
        if (self.idle_turns >= 25) {
            self.idle_turns = 0;
            self.active = !self.active;
        }
    }
};
