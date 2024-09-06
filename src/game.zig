const std = @import("std");
const engine = @import("engine.zig");
const utils = @import("utils.zig");
const image = @import("image");
const sprite = @import("sprite.zig");
const physic_pixel = @import("physics_pixel.zig");

pub const World = @import("world.zig").World;
pub const PhysicsPixel = physic_pixel.PhysicsPixel;
pub const Error = error{} || image.Error || engine.Error || utils.Error || std.mem.Allocator.Error;

pub const Game = struct {
    running: bool = true,
    e: engine.Engine(utils.ColorMode.color_true) = undefined,
    fps_buffer: [64]u8 = undefined,
    starting_pos_x: i32 = 1920 / 2,
    starting_pos_y: i32 = 10,
    placement_pixel: []PhysicsPixel = undefined,
    placement_index: usize = 0,
    current_world: World = undefined,
    pixels: std.ArrayList(?*PhysicsPixel) = undefined,
    allocator: std.mem.Allocator = undefined,
    frame_limit: u64 = 16_666_667,
    lock: std.Thread.Mutex = undefined,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        var ret = Self{ .allocator = allocator };
        try utils.gen_rand();
        ret.placement_pixel = try ret.allocator.alloc(PhysicsPixel, 2);
        ret.placement_pixel[0] = PhysicsPixel.init(physic_pixel.PixelType.Sand, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[1] = PhysicsPixel.init(physic_pixel.PixelType.Water, ret.starting_pos_x, ret.starting_pos_y);
        return ret;
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        for (0..self.pixels.items.len) |i| {
            if (self.pixels.items[i] != null) {
                self.allocator.destroy(self.pixels.items[i].?);
            }
        }
        self.pixels.deinit();
        self.current_world.deinit();
        self.allocator.free(self.placement_pixel);
    }

    pub fn place_pixel(self: *Self) !void {
        var indx: u32 = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y);
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y + 1)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y + 1);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y + 1);
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x + 1));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y);
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y - 1)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y - 1);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y - 1);
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x - 1));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x - 1, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x - 1, self.placement_pixel[self.placement_index].y);
        }
    }

    pub fn on_key_press(self: *Self, key: engine.KEYS) void {
        //std.debug.print("{}\n", .{key});
        if (key == engine.KEYS.KEY_q) {
            self.running = false;
        } else if (key == engine.KEYS.KEY_a) {
            self.placement_pixel[self.placement_index].x -= 1;
        } else if (key == engine.KEYS.KEY_d) {
            self.placement_pixel[self.placement_index].x += 1;
        } else if (key == engine.KEYS.KEY_w) {
            self.placement_pixel[self.placement_index].y -= 1;
        } else if (key == engine.KEYS.KEY_s) {
            self.placement_pixel[self.placement_index].y += 1;
        } else if (key == engine.KEYS.KEY_SPACE) {
            std.debug.print("placed {d} {d} \n", .{ self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y });
            self.lock.lock();
            self.place_pixel() catch |err| {
                std.debug.print("{any}\n", .{err});
                self.running = false;
                return;
            };
            self.lock.unlock();
        } else if (key == engine.KEYS.KEY_i) {
            if (self.current_world.viewport.y > 0) {
                self.current_world.viewport.y -= 1;
            }
        } else if (key == engine.KEYS.KEY_k) {
            if (@as(u32, @bitCast(self.current_world.viewport.y)) + self.current_world.viewport.height < self.current_world.bounds.height) {
                self.current_world.viewport.y += 1;
            }
        } else if (key == engine.KEYS.KEY_j) {
            if (self.current_world.viewport.x > 0) {
                self.current_world.viewport.x -= 1;
            }
        } else if (key == engine.KEYS.KEY_l) {
            if (@as(u32, @bitCast(self.current_world.viewport.x)) + self.current_world.viewport.width < self.current_world.bounds.width) {
                self.current_world.viewport.x += 1;
            }
        } else if (key == engine.KEYS.KEY_z) {
            self.placement_pixel[(self.placement_index + 1) % self.placement_pixel.len].x = self.placement_pixel[self.placement_index].x;
            self.placement_pixel[(self.placement_index + 1) % self.placement_pixel.len].y = self.placement_pixel[self.placement_index].y;
            self.placement_index = (self.placement_index + 1) % self.placement_pixel.len;
        }
    }

    pub fn on_render(self: *Self, _: u64) !void {
        self.e.renderer.set_bg(0, 0, 0, self.current_world.tex);
        for (self.pixels.items) |p| {
            if (p != null) {
                self.e.renderer.draw_pixel(p.?.*.x, p.?.*.y, p.?.*.pixel, self.current_world.tex);
            }
        }
        self.e.renderer.draw_pixel(self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y, self.placement_pixel[self.placement_index].pixel, self.current_world.tex);
        try self.e.renderer.flip(self.current_world.tex, self.current_world.viewport);
    }
    pub fn run(self: *Self) !void {
        self.lock = std.Thread.Mutex{};
        self.e = try engine.Engine(utils.ColorMode.color_true).init(self.allocator);
        self.current_world = try World.init(1920, @as(u32, @intCast(self.e.renderer.terminal.size.height)) + 10, @as(u32, @intCast(self.e.renderer.terminal.size.width)), @as(u32, @intCast(self.e.renderer.terminal.size.height)), self.allocator);
        self.pixels = std.ArrayList(?*PhysicsPixel).init(self.allocator);
        for (0..self.current_world.tex.width * self.current_world.tex.height) |_| {
            try self.pixels.append(null);
        }
        self.current_world.viewport.x = self.starting_pos_x;
        self.current_world.viewport.y = self.starting_pos_y;

        self.e.on_key_press(Self, on_key_press, self);
        self.e.on_render(Self, on_render, self);
        self.e.set_fps(60);
        try self.e.start();

        var timer: std.time.Timer = try std.time.Timer.start();
        var delta: u64 = 0;
        while (self.running) {
            for (0..self.pixels.items.len) |i| {
                if (self.pixels.items[i] != null) {
                    self.pixels.items[i].?.*.dirty = false;
                }
            }
            const y_start = self.current_world.tex.height - 1;
            const x_start = self.current_world.tex.width - 1;
            var y = y_start;
            self.lock.lock();
            while (y >= 0) : (y -= 1) {
                var x = x_start;
                while (x >= 0) : (x -= 1) {
                    var p = self.pixels.items[y * self.current_world.tex.width + x];
                    if (p != null and !p.?.*.dirty) {
                        std.debug.print("updating {any}\n", .{p.?});
                        p.?.update(self.pixels.items, self.current_world.tex.width, self.current_world.tex.height);
                    }
                    if (x == 0) break;
                }
                if (y == 0) break;
            }
            self.lock.unlock();
            delta = timer.read();
            timer.reset();
            const time_to_sleep: i64 = @as(i64, @bitCast(self.frame_limit)) - @as(i64, @bitCast(delta));
            std.debug.print("time to sleep {d}\n", .{time_to_sleep});
            if (time_to_sleep > 0) {
                std.time.sleep(@as(u64, @bitCast(time_to_sleep)));
            }
        }
    }
};
