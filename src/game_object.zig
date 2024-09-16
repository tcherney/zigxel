const std = @import("std");
const physics_pixel = @import("physics_pixel.zig");
const texture = @import("texture.zig");

pub const Texture = texture.Texture;
pub const PhysicsPixel = physics_pixel.PhysicsPixel;

pub const Error = error{} || texture.Error || std.mem.Allocator.Error;

const JUMPING_MAX = 10;

pub const GameObject = struct {
    jumping: bool = false,
    left: bool = false,
    right: bool = false,
    jumping_duration: u32 = 0,
    tex: *Texture,
    pixels: []*PhysicsPixel,
    allocator: std.mem.Allocator,
    status: Status = .Wet,
    background_buffer: BackgroundBuffer,
    pixel_map: std.AutoHashMap(u32, bool),
    wet_pixels: u32 = 0,
    pub const Status = enum {
        Wet,
        None,
    };
    pub const BackgroundBuffer = struct {
        status: Status = .None,
        a: []texture.Pixel,
    };
    const Self = @This();
    pub fn init(x: i32, y: i32, w_width: u32, tex: *Texture, allocator: std.mem.Allocator) Error!Self {
        var pixel_list: std.ArrayList(*PhysicsPixel) = std.ArrayList(*PhysicsPixel).init(allocator);
        var x_pix: i32 = x;
        var y_pix: i32 = y;
        for (0..tex.pixel_buffer.len) |i| {
            if (tex.pixel_buffer[i].a != null and tex.pixel_buffer[i].a.? > 0) {
                try pixel_list.append(try allocator.create(PhysicsPixel));
                const indx = pixel_list.items.len - 1;
                pixel_list.items[indx].* = PhysicsPixel.init(physics_pixel.PixelType.Object, x_pix, y_pix);
                pixel_list.items[indx].set_color(tex.pixel_buffer[i].r, tex.pixel_buffer[i].g, tex.pixel_buffer[i].b, tex.pixel_buffer[i].a);
                pixel_list.items[indx].managed = true;
            }

            x_pix += 1;
            if (@as(u32, @bitCast(x_pix)) >= (@as(u32, @bitCast(x)) + tex.width) or @as(u32, @bitCast(x_pix)) >= w_width) {
                x_pix = x;
                y_pix += 1;
            }
        }
        const pixels = try pixel_list.toOwnedSlice();
        var pixel_map: std.AutoHashMap(u32, bool) = std.AutoHashMap(u32, bool).init(allocator);
        for (pixels) |p| {
            try pixel_map.put(@as(u32, @bitCast(p.y)) * w_width + @as(u32, @bitCast(p.x)), true);
        }

        return Self{ .tex = tex, .pixels = pixels, .pixel_map = pixel_map, .allocator = allocator, .background_buffer = .{ .status = .None, .a = try allocator.alloc(texture.Pixel, pixels.len) } };
    }

    pub fn on_object_reaction(self: *Self, pixel_type: physics_pixel.PixelType) void {
        if (pixel_type == .Water) {
            self.wet_pixels += 1;
        }
    }

    pub fn add_sim(self: *Self, pixels: []?*PhysicsPixel, w_width: u32) void {
        for (0..self.pixels.len) |i| {
            const indx: u32 = @as(u32, @bitCast(self.pixels[i].y)) * w_width + @as(u32, @bitCast(self.pixels[i].x));
            if (indx > 0 and indx < pixels.len) {
                self.pixels[i].on_object_reaction(Self, on_object_reaction, self);
                pixels[indx] = self.pixels[i];
            }
        }
    }

    pub fn move_left(self: *Self) void {
        self.left = true;
        self.right = false;
    }

    pub fn move_right(self: *Self) void {
        self.right = true;
        self.left = false;
    }

    pub fn stop_move_left(self: *Self) void {
        self.left = false;
    }

    pub fn stop_move_right(self: *Self) void {
        self.right = false;
    }

    pub fn jump(self: *Self) void {
        self.jumping = true;
        self.jumping_duration = 0;
    }

    fn check_left_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        for (self.pixels) |p| {
            if (p.y < 0 or p.x - 1 < 0) {
                return true;
            }
            const indx = @as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x - 1));
            if (!physics_pixel.PhysicsPixel.in_bounds(p.x - 1, p.y, xlimit, ylimit) or (self.pixel_map.get(indx) == null and (physics_pixel.pixel_at_x_y(p.x - 1, p.y, pixels, xlimit, ylimit) and pixels[indx].?.properties.solid))) {
                return true;
            }
        }
        return false;
    }

    fn check_bottom_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        for (self.pixels) |p| {
            if (p.y + 1 < 0 or p.x < 0) {
                return true;
            }
            const indx = @as(u32, @bitCast(p.y + 1)) * xlimit + @as(u32, @bitCast(p.x));
            if (!physics_pixel.PhysicsPixel.in_bounds(p.x, p.y + 1, xlimit, ylimit) or (self.pixel_map.get(indx) == null and (physics_pixel.pixel_at_x_y(p.x, p.y + 1, pixels, xlimit, ylimit) and pixels[indx].?.properties.solid))) {
                return true;
            }
        }
        return false;
    }

    fn check_right_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        for (self.pixels) |p| {
            if (p.y < 0 or p.x + 1 < 0) {
                return true;
            }
            const indx = @as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x + 1));
            if (!physics_pixel.PhysicsPixel.in_bounds(p.x + 1, p.y, xlimit, ylimit) or (self.pixel_map.get(indx) == null and (physics_pixel.pixel_at_x_y(p.x + 1, p.y, pixels, xlimit, ylimit) and pixels[indx].?.properties.solid))) {
                return true;
            }
        }
        return false;
    }

    fn check_top_bounds(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) bool {
        for (self.pixels) |p| {
            if (p.y - 1 < 0 or p.x < 0) {
                continue;
            }
            const indx = @as(u32, @bitCast(p.y - 1)) * xlimit + @as(u32, @bitCast(p.x));
            if (!physics_pixel.PhysicsPixel.in_bounds(p.x, p.y - 1, xlimit, ylimit) or (self.pixel_map.get(indx) == null and (physics_pixel.pixel_at_x_y(p.x, p.y - 1, pixels, xlimit, ylimit) and pixels[indx].?.properties.solid))) {
                return true;
            }
        }
        return false;
    }

    pub fn draw(self: *Self, graphics: anytype, dest: ?Texture) void {
        switch (self.status) {
            .Wet => {
                if (self.background_buffer.status != .Wet) {
                    self.background_buffer.status = .Wet;
                    var water_properties = physics_pixel.WATER_PROPERTIES;
                    for (0..self.background_buffer.a.len) |i| {
                        const w_color = water_properties.vary_color(10);
                        self.background_buffer.a[i] = .{ .r = w_color.r, .g = w_color.g, .b = w_color.b };
                    }
                }

                for (self.pixels, 0..self.pixels.len) |p, i| {
                    const temp = p.pixel.a;
                    p.pixel.a = 128;
                    graphics.draw_pixel_bg(p.x, p.y, p.pixel, dest, self.background_buffer.a[i].r, self.background_buffer.a[i].g, self.background_buffer.a[i].b, true);
                    p.pixel.a = temp;
                }
            },
            .None => {
                for (self.pixels) |p| {
                    graphics.draw_pixel_bg(p.x, p.y, p.pixel, dest, 0, 0, 0, false);
                }
            },
        }
    }

    pub fn update(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) Error!void {
        self.wet_pixels = 0;
        if (self.jumping) {
            self.jumping_duration += 1;
            if (self.jumping_duration >= JUMPING_MAX) {
                self.jumping = false;
                self.jumping_duration = 0;
            }
        }
        if (self.jumping and self.left and !self.check_left_bounds(pixels, xlimit, ylimit) and !self.check_top_bounds(pixels, xlimit, ylimit)) {
            for (0..self.pixels.len) |i| {
                if (self.pixels[i].pixel_type != .Object) {
                    continue;
                }
                self.pixels[i].left_update(pixels, xlimit, ylimit);
                self.pixels[i].up_update(pixels, xlimit, ylimit);
                self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                self.pixels[i].active = true;
                self.pixels[i].idle_turns = 0;
            }
            self.pixel_map.clearRetainingCapacity();
            for (self.pixels) |p| {
                try self.pixel_map.put(@as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x)), true);
            }
        } else if (self.jumping and self.right and !self.check_right_bounds(pixels, xlimit, ylimit) and !self.check_top_bounds(pixels, xlimit, ylimit)) {
            for (0..self.pixels.len) |i| {
                if (self.pixels[i].pixel_type != .Object) {
                    continue;
                }
                self.pixels[i].up_update(pixels, xlimit, ylimit);
                self.pixels[i].active = true;
                self.pixels[i].idle_turns = 0;
            }
            var i: usize = self.pixels.len - 1;
            while (i >= 0) : (i -= 1) {
                if (self.pixels[i].pixel_type != .Object) {
                    if (i == 0) break;
                    continue;
                }
                self.pixels[i].right_update(pixels, xlimit, ylimit);
                self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                self.pixels[i].active = true;
                self.pixels[i].idle_turns = 0;
                if (i == 0) break;
            }
            self.pixel_map.clearRetainingCapacity();
            for (self.pixels) |p| {
                try self.pixel_map.put(@as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x)), true);
            }
        } else if (self.jumping and !self.check_top_bounds(pixels, xlimit, ylimit)) {
            for (0..self.pixels.len) |i| {
                if (self.pixels[i].pixel_type != .Object) {
                    continue;
                }
                self.pixels[i].up_update(pixels, xlimit, ylimit);
                self.pixels[i].active = true;
                self.pixels[i].idle_turns = 0;
            }
            self.pixel_map.clearRetainingCapacity();
            for (self.pixels) |p| {
                try self.pixel_map.put(@as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x)), true);
            }
        } else if (!self.jumping) {
            if (self.left and !self.check_left_bounds(pixels, xlimit, ylimit)) {
                for (0..self.pixels.len) |i| {
                    if (self.pixels[i].pixel_type != .Object) {
                        continue;
                    }
                    self.pixels[i].left_update(pixels, xlimit, ylimit);
                    self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                }
                self.pixel_map.clearRetainingCapacity();
                for (self.pixels) |p| {
                    try self.pixel_map.put(@as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x)), true);
                }
            } else if (self.right and !self.check_right_bounds(pixels, xlimit, ylimit)) {
                var i: usize = self.pixels.len - 1;
                while (i >= 0) : (i -= 1) {
                    if (self.pixels[i].pixel_type != .Object) {
                        if (i == 0) break;
                        continue;
                    }
                    self.pixels[i].right_update(pixels, xlimit, ylimit);
                    self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                    if (i == 0) break;
                }
                self.pixel_map.clearRetainingCapacity();
                for (self.pixels) |p| {
                    try self.pixel_map.put(@as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x)), true);
                }
            }
            if (!self.check_bottom_bounds(pixels, xlimit, ylimit)) {
                var i: usize = self.pixels.len - 1;
                while (i >= 0) : (i -= 1) {
                    if (self.pixels[i].pixel_type != .Object) {
                        if (i == 0) break;
                        continue;
                    }
                    self.pixels[i].down_update(pixels, xlimit, ylimit);
                    self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                    if (i == 0) break;
                }
                self.pixel_map.clearRetainingCapacity();
                for (self.pixels) |p| {
                    try self.pixel_map.put(@as(u32, @bitCast(p.y)) * xlimit + @as(u32, @bitCast(p.x)), true);
                }
            } else {
                for (0..self.pixels.len) |i| {
                    if (self.pixels[i].pixel_type != .Object) {
                        continue;
                    }
                    self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                }
            }
        }
        if (self.wet_pixels >= self.pixels.len / 2) {
            self.status = .Wet;
        } else {
            self.status = .None;
        }
    }

    pub fn deinit(self: *Self) void {
        for (0..self.pixels.len) |i| {
            self.allocator.destroy(self.pixels[i]);
        }
        self.allocator.free(self.pixels);
        self.allocator.free(self.background_buffer.a);
        self.pixel_map.deinit();
    }
};
