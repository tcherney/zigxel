const std = @import("std");
const physics_pixel = @import("physics_pixel.zig");
const texture = @import("texture.zig");

pub const PixelRenderer = @import("pixel_renderer.zig").PixelRenderer;
pub const Texture = texture.Texture;
pub const PhysicsPixel = physics_pixel.PhysicsPixel;

const JUMPING_MAX = 10;

pub const GameObject = struct {
    jumping: bool = false,
    left: bool = false,
    right: bool = false,
    jumping_duration: u32 = 0,
    tex: *Texture,
    pixels: []*PhysicsPixel,
    allocator: std.mem.Allocator,
    status: Status = .None,
    background_buffer: BackgroundBuffer,
    pixel_map: std.AutoHashMap(u32, bool),
    wet_pixels: u32 = 0,
    hot_pixels: u32 = 0,
    pub const Error = error{} || Texture.Error || std.mem.Allocator.Error;
    pub const Status = enum {
        Wet,
        Hot,
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
            if (tex.pixel_buffer[i].get_a() != 0) {
                try pixel_list.append(try allocator.create(PhysicsPixel));
                const indx = pixel_list.items.len - 1;
                pixel_list.items[indx].* = PhysicsPixel.init(physics_pixel.PixelType.Object, x_pix, y_pix);
                pixel_list.items[indx].set_color(tex.pixel_buffer[i].get_r(), tex.pixel_buffer[i].get_g(), tex.pixel_buffer[i].get_b(), tex.pixel_buffer[i].get_a());
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
        } else if (pixel_type == .Fire or pixel_type == .Lava) {
            self.hot_pixels += 1;
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
            if (p.pixel_type != .Object) continue;
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
            if (p.pixel_type != .Object) continue;
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
            if (p.pixel_type != .Object) continue;
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
            if (p.pixel_type != .Object) continue;
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

    //TODO MORE STATUS EFFECTS
    pub fn draw(self: *Self, renderer: *PixelRenderer, dest: ?Texture) void {
        switch (self.status) {
            .Wet => {
                if (self.background_buffer.status != .Wet) {
                    self.background_buffer.status = .Wet;
                    var water_properties = physics_pixel.WATER_PROPERTIES;
                    for (0..self.background_buffer.a.len) |i| {
                        const w_color = water_properties.vary_color(10);
                        self.background_buffer.a[i].v = w_color.v;
                    }
                }

                for (self.pixels, 0..self.pixels.len) |p, i| {
                    if (p.pixel_type == .Object) {
                        const temp = p.pixel.get_a();
                        p.pixel.set_a(128);
                        renderer.draw_pixel_bg(p.x, p.y, p.pixel, dest, self.background_buffer.a[i].get_r(), self.background_buffer.a[i].get_g(), self.background_buffer.a[i].get_b(), true);
                        p.pixel.set_a(temp);
                    }
                }
            },
            .Hot => {
                if (self.background_buffer.status != .Hot) {
                    self.background_buffer.status = .Hot;
                    var fire_properties = physics_pixel.FIRE_PROPERTIES;
                    for (0..self.background_buffer.a.len) |i| {
                        const f_color = fire_properties.vary_color(10);
                        self.background_buffer.a[i].v = f_color.v;
                    }
                }

                for (self.pixels, 0..self.pixels.len) |p, i| {
                    if (p.pixel_type == .Object) {
                        const temp = p.pixel.get_a();
                        p.pixel.set_a(128);
                        renderer.draw_pixel_bg(p.x, p.y, p.pixel, dest, self.background_buffer.a[i].get_r(), self.background_buffer.a[i].get_g(), self.background_buffer.a[i].get_b(), true);
                        p.pixel.set_a(temp);
                    }
                }
            },
            .None => {
                for (self.pixels) |p| {
                    if (p.pixel_type == .Object) {
                        renderer.draw_pixel_bg(p.x, p.y, p.pixel, dest, 0, 0, 0, false);
                    }
                }
            },
        }
    }

    //TODO add active logic from physics pixel in here as well, can be problematic if game objects are large
    pub fn update(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) Error!void {
        self.wet_pixels = 0;
        self.hot_pixels = 0;
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
                if (self.pixels[i].active) {
                    self.pixels[i].updated = false;
                    self.pixels[i].left_update(pixels, xlimit, ylimit);
                    self.pixels[i].up_update(pixels, xlimit, ylimit);
                    self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                }
                if (self.pixels[i].updated) {
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                } else {
                    self.pixels[i].idle_turns += 1;
                    if (self.pixels[i].idle_turns >= 25) {
                        self.pixels[i].idle_turns = 0;
                        self.pixels[i].active = !self.pixels[i].active;
                    }
                }
                self.pixels[i].updated = false;
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
                if (self.pixels[i].active) {
                    self.pixels[i].updated = false;
                    self.pixels[i].up_update(pixels, xlimit, ylimit);
                }
                if (self.pixels[i].updated) {
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                } else {
                    self.pixels[i].idle_turns += 1;
                    if (self.pixels[i].idle_turns >= 25) {
                        self.pixels[i].idle_turns = 0;
                        self.pixels[i].active = !self.pixels[i].active;
                    }
                }
                self.pixels[i].updated = false;
            }
            var i: usize = self.pixels.len - 1;
            while (i >= 0) : (i -= 1) {
                if (self.pixels[i].pixel_type != .Object) {
                    if (i == 0) break;
                    continue;
                }
                if (self.pixels[i].active) {
                    self.pixels[i].updated = false;
                    self.pixels[i].right_update(pixels, xlimit, ylimit);
                    self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                }
                if (self.pixels[i].updated) {
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                } else {
                    self.pixels[i].idle_turns += 1;
                    if (self.pixels[i].idle_turns >= 25) {
                        self.pixels[i].idle_turns = 0;
                        self.pixels[i].active = !self.pixels[i].active;
                    }
                }
                self.pixels[i].updated = false;
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
                if (self.pixels[i].active) {
                    self.pixels[i].updated = false;
                    self.pixels[i].up_update(pixels, xlimit, ylimit);
                }
                if (self.pixels[i].updated) {
                    self.pixels[i].active = true;
                    self.pixels[i].idle_turns = 0;
                } else {
                    self.pixels[i].idle_turns += 1;
                    if (self.pixels[i].idle_turns >= 25) {
                        self.pixels[i].idle_turns = 0;
                        self.pixels[i].active = !self.pixels[i].active;
                    }
                }
                self.pixels[i].updated = false;
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
                    if (self.pixels[i].active) {
                        self.pixels[i].updated = false;
                        self.pixels[i].left_update(pixels, xlimit, ylimit);
                        self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    }
                    if (self.pixels[i].updated) {
                        self.pixels[i].active = true;
                        self.pixels[i].idle_turns = 0;
                    } else {
                        self.pixels[i].idle_turns += 1;
                        if (self.pixels[i].idle_turns >= 25) {
                            self.pixels[i].idle_turns = 0;
                            self.pixels[i].active = !self.pixels[i].active;
                        }
                    }
                    self.pixels[i].updated = false;
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
                    if (self.pixels[i].active) {
                        self.pixels[i].updated = false;
                        self.pixels[i].right_update(pixels, xlimit, ylimit);
                        self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    }
                    if (self.pixels[i].updated) {
                        self.pixels[i].active = true;
                        self.pixels[i].idle_turns = 0;
                    } else {
                        self.pixels[i].idle_turns += 1;
                        if (self.pixels[i].idle_turns >= 25) {
                            self.pixels[i].idle_turns = 0;
                            self.pixels[i].active = !self.pixels[i].active;
                        }
                    }
                    self.pixels[i].updated = false;
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
                    if (self.pixels[i].active) {
                        self.pixels[i].updated = false;
                        self.pixels[i].down_update(pixels, xlimit, ylimit);
                        self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    }
                    if (self.pixels[i].updated) {
                        self.pixels[i].active = true;
                        self.pixels[i].idle_turns = 0;
                    } else {
                        self.pixels[i].idle_turns += 1;
                        if (self.pixels[i].idle_turns >= 25) {
                            self.pixels[i].idle_turns = 0;
                            self.pixels[i].active = !self.pixels[i].active;
                        }
                    }
                    self.pixels[i].updated = false;
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
                    if (self.pixels[i].active) {
                        self.pixels[i].updated = false;
                        self.pixels[i].react_with_neighbors(pixels, xlimit, ylimit);
                    }
                    if (self.pixels[i].updated) {
                        self.pixels[i].active = true;
                        self.pixels[i].idle_turns = 0;
                    } else {
                        self.pixels[i].idle_turns += 1;
                        if (self.pixels[i].idle_turns >= 25) {
                            self.pixels[i].idle_turns = 0;
                            self.pixels[i].active = !self.pixels[i].active;
                        }
                    }
                    self.pixels[i].updated = false;
                }
            }
        }
        if (self.wet_pixels >= self.pixels.len / 2) {
            self.status = .Wet;
        } else if (self.hot_pixels >= self.pixels.len / 4) {
            self.status = .Hot;
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
