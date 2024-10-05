const std = @import("std");
const engine = @import("engine.zig");
const utils = @import("utils.zig");
const image = @import("image");
const sprite = @import("sprite.zig");
const physic_pixel = @import("physics_pixel.zig");
const game_object = @import("game_object.zig");
const asset_manager = @import("asset_manager.zig");
const _player = @import("player.zig");
const _font = @import("font.zig");

pub const Font = _font.Font;
pub const World = @import("world.zig").World;
pub const PhysicsPixel = physic_pixel.PhysicsPixel;
pub const Player = _player.Player;
pub const GameObject = game_object.GameObject;
pub const Texture = game_object.Texture;
pub const AssetManager = asset_manager.AssetManager;
pub const Error = error{} || image.Error || engine.Error || utils.Error || std.mem.Allocator.Error;

pub const Game = struct {
    running: bool = true,
    e: engine.Engine(utils.ColorMode.color_true) = undefined,
    fps_buffer: [64]u8 = undefined,
    world_width: u32 = 1920,
    starting_pos_x: i32 = 1920 / 2,
    starting_pos_y: i32 = 10,
    placement_pixel: []PhysicsPixel = undefined,
    placement_index: usize = 0,
    current_world: World = undefined,
    pixels: std.ArrayList(?*PhysicsPixel) = undefined,
    assets: AssetManager = undefined,
    allocator: std.mem.Allocator = undefined,
    frame_limit: u64 = 16_666_667,
    player_mode: bool = false,
    lock: std.Thread.Mutex = undefined,
    old_mouse_x: i32 = -1,
    old_mouse_y: i32 = -1,
    player: ?Player = null,
    font_tex: *Texture = undefined,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        var ret = Self{ .allocator = allocator };
        try utils.gen_rand();
        ret.placement_pixel = try ret.allocator.alloc(PhysicsPixel, 13);
        ret.placement_pixel[0] = PhysicsPixel.init(physic_pixel.PixelType.Sand, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[1] = PhysicsPixel.init(physic_pixel.PixelType.Water, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[2] = PhysicsPixel.init(physic_pixel.PixelType.Steam, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[3] = PhysicsPixel.init(physic_pixel.PixelType.Oil, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[4] = PhysicsPixel.init(physic_pixel.PixelType.Lava, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[5] = PhysicsPixel.init(physic_pixel.PixelType.Fire, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[6] = PhysicsPixel.init(physic_pixel.PixelType.Explosive, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[7] = PhysicsPixel.init(physic_pixel.PixelType.Ice, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[8] = PhysicsPixel.init(physic_pixel.PixelType.Rock, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[9] = PhysicsPixel.init(physic_pixel.PixelType.Wood, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[10] = PhysicsPixel.init(physic_pixel.PixelType.Plant, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[11] = PhysicsPixel.init(physic_pixel.PixelType.Wall, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[12] = PhysicsPixel.init(physic_pixel.PixelType.Empty, ret.starting_pos_x, ret.starting_pos_y);
        return ret;
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        self.assets.deinit();
        for (0..self.pixels.items.len) |i| {
            if (self.pixels.items[i] != null and !self.pixels.items[i].?.managed) {
                self.allocator.destroy(self.pixels.items[i].?);
            }
        }
        self.pixels.deinit();
        self.current_world.deinit();
        self.allocator.free(self.placement_pixel);
        if (self.player != null) {
            self.player.?.deinit();
        }
        self.font_tex.deinit();
        self.allocator.destroy(self.font_tex);
    }

    pub fn place_pixel(self: *Self) !void {
        var indx: u32 = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            const temp = self.pixels.items[indx].?.managed;
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y);
            self.pixels.items[indx].?.*.managed = temp;
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y + 1)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y + 1);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            const temp = self.pixels.items[indx].?.managed;
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y + 1);
            self.pixels.items[indx].?.*.managed = temp;
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x + 1));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            const temp = self.pixels.items[indx].?.managed;
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y);
            self.pixels.items[indx].?.*.managed = temp;
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y + 1)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x + 1));
        if (indx >= 0 and indx < self.pixels.items.len and self.pixels.items[indx] == null) {
            self.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y + 1);
        } else if (indx >= 0 and indx < self.pixels.items.len) {
            const temp = self.pixels.items[indx].?.managed;
            self.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y + 1);
            self.pixels.items[indx].?.*.managed = temp;
        }
    }

    pub fn on_mouse_change(self: *Self, mouse_event: engine.MouseEvent) void {
        std.debug.print("{any}\n", .{mouse_event});
        if (self.old_mouse_x == -1 or self.old_mouse_y == -1) {
            self.old_mouse_x = @as(i32, @intCast(mouse_event.x)) + self.current_world.viewport.x;
            self.old_mouse_y = @as(i32, @intCast(mouse_event.y)) * 2 + self.current_world.viewport.y;
        }
        self.placement_pixel[self.placement_index].x = @as(i32, @intCast(mouse_event.x)) + self.current_world.viewport.x;
        self.placement_pixel[self.placement_index].y = @as(i32, @intCast(mouse_event.y)) * 2 + self.current_world.viewport.y;
        const mouse_diff_x = self.placement_pixel[self.placement_index].x - self.old_mouse_x;
        const mouse_diff_y = self.placement_pixel[self.placement_index].y - self.old_mouse_y;
        self.old_mouse_x = self.placement_pixel[self.placement_index].x;
        self.old_mouse_y = self.placement_pixel[self.placement_index].y;
        if (mouse_event.clicked) {
            std.debug.print("placed {d} {d} \n", .{ self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y });
            self.lock.lock();
            self.place_pixel() catch |err| {
                std.debug.print("{any}\n", .{err});
                self.running = false;
                return;
            };
            self.lock.unlock();
        }
        if (mouse_event.scroll_up) {
            self.placement_pixel[(self.placement_index + 1) % self.placement_pixel.len].x = self.placement_pixel[self.placement_index].x;
            self.placement_pixel[(self.placement_index + 1) % self.placement_pixel.len].y = self.placement_pixel[self.placement_index].y;
            self.placement_index = (self.placement_index + 1) % self.placement_pixel.len;
        } else if (mouse_event.scroll_down) {
            if (self.placement_index == 0) {
                self.placement_pixel[self.placement_pixel.len - 1].x = self.placement_pixel[self.placement_index].x;
                self.placement_pixel[self.placement_pixel.len - 1].y = self.placement_pixel[self.placement_index].y;
                self.placement_index = self.placement_pixel.len - 1;
            } else {
                self.placement_pixel[(self.placement_index - 1) % self.placement_pixel.len].x = self.placement_pixel[self.placement_index].x;
                self.placement_pixel[(self.placement_index - 1) % self.placement_pixel.len].y = self.placement_pixel[self.placement_index].y;
                self.placement_index = (self.placement_index - 1) % self.placement_pixel.len;
            }
        }
        if (mouse_event.ctrl_pressed) {
            std.debug.print("{any} mouse {d} {d}\n", .{ mouse_event, mouse_diff_x, mouse_diff_y });
            self.current_world.viewport.x += if (mouse_diff_x > 0) 1 else if (mouse_diff_x < 0) -1 else 0;
            self.current_world.viewport.y += if (mouse_diff_y > 0) 1 else if (mouse_diff_y < 0) -1 else 0;
            if (self.current_world.viewport.x < 0) {
                self.current_world.viewport.x = 0;
            }
            if (self.current_world.viewport.y < 0) {
                self.current_world.viewport.y = 0;
            }
            if (@as(u32, @bitCast(self.current_world.viewport.x)) + self.current_world.viewport.width > self.current_world.bounds.width) {
                self.current_world.viewport.x = @as(i32, @bitCast(self.current_world.bounds.width - self.current_world.viewport.width));
            }
            if (@as(u32, @bitCast(self.current_world.viewport.y)) + self.current_world.viewport.height > self.current_world.bounds.height) {
                self.current_world.viewport.y = @as(i32, @bitCast(self.current_world.bounds.height - self.current_world.viewport.height));
            }
        }
    }
    pub fn on_window_change(self: *Self, win_size: engine.WindowSize) void {
        self.lock.lock();
        std.debug.print("changed height {d}\n", .{win_size.height});
        const w_width: u32 = if (win_size.width > self.world_width) win_size.width else self.world_width;
        var new_world: World = World.init(w_width, @as(u32, @intCast(self.e.renderer.terminal.size.height)) + 10, @as(u32, @intCast(self.e.renderer.terminal.size.width)), @as(u32, @intCast(self.e.renderer.terminal.size.height)), self.allocator) catch |err| {
            std.debug.print("{any}\n", .{err});
            self.running = false;
            return;
        };
        var new_pixels: std.ArrayList(?*PhysicsPixel) = std.ArrayList(?*PhysicsPixel).init(self.allocator);
        for (0..new_world.tex.width * new_world.tex.height) |i| {
            if (i < self.pixels.items.len) {
                new_pixels.append(self.pixels.items[i]) catch |err| {
                    std.debug.print("{any}\n", .{err});
                    self.running = false;
                    return;
                };
            } else {
                new_pixels.append(null) catch |err| {
                    std.debug.print("{any}\n", .{err});
                    self.running = false;
                    return;
                };
            }
        }
        const pixels_to_delete: i64 = @as(i64, @bitCast(self.pixels.items.len)) - @as(i64, @bitCast(new_pixels.items.len));
        if (pixels_to_delete > 0) {
            for (new_pixels.items.len..self.pixels.items.len) |i| {
                if (self.pixels.items[i] != null) {
                    self.allocator.destroy(self.pixels.items[i].?);
                }
            }
        }
        new_world.viewport.x = self.starting_pos_x;
        new_world.viewport.y = self.starting_pos_y;
        self.pixels.deinit();
        self.current_world.deinit();
        self.pixels = new_pixels;
        self.current_world = new_world;
        self.lock.unlock();
    }

    pub fn on_key_down(self: *Self, key: engine.KEYS) void {
        std.debug.print("{}\n", .{key});
        if (key == engine.KEYS.KEY_q) {
            self.running = false;
        } else if (key == engine.KEYS.KEY_a) {
            if (!self.player_mode) {
                self.placement_pixel[self.placement_index].x -= 1;
            } else {
                self.player.?.move_left();
            }
        } else if (key == engine.KEYS.KEY_d) {
            if (!self.player_mode) {
                self.placement_pixel[self.placement_index].x += 1;
            } else {
                self.player.?.move_right();
            }
        } else if (key == engine.KEYS.KEY_w) {
            if (!self.player_mode) {
                self.placement_pixel[self.placement_index].y -= 1;
            }
        } else if (key == engine.KEYS.KEY_s) {
            if (!self.player_mode) {
                self.placement_pixel[self.placement_index].y += 1;
            }
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
        } else if (key == engine.KEYS.KEY_p) {
            self.current_world.print() catch |err| {
                std.debug.print("{any}\n", .{err});
                self.running = false;
            };
        }
    }

    pub fn on_key_up(self: *Self, key: engine.KEYS) void {
        switch (key) {
            .KEY_w => {
                if (self.player_mode) {
                    self.player.?.jump();
                }
            },
            .KEY_a => {
                if (self.player_mode) {
                    self.player.?.stop_move_left();
                }
            },
            .KEY_d => {
                if (self.player_mode) {
                    self.player.?.stop_move_right();
                }
            },
            .KEY_c => {
                self.player_mode = !self.player_mode;
                if (self.player_mode) {
                    if (self.player == null) {
                        const tex = self.assets.get("basic") catch |err| {
                            std.debug.print("{any}\n", .{err});
                            self.running = false;
                            return;
                        };
                        self.player = Player.init(self.current_world.viewport.x, self.current_world.viewport.y, self.current_world.tex.width, tex, self.allocator) catch |err| {
                            std.debug.print("{any}\n", .{err});
                            self.running = false;
                            return;
                        };
                        self.player.?.go.add_sim(self.pixels.items, self.current_world.tex.width);
                    }
                }
            },
            else => {},
        }
    }

    pub fn on_render(self: *Self, _: u64) !void {
        self.e.renderer.set_bg(0, 0, 0, self.current_world.tex);
        for (self.pixels.items) |p| {
            if (p != null and p.?.*.pixel_type != .Empty and p.?.pixel_type != .Object) {
                self.e.renderer.draw_pixel(p.?.*.x, p.?.*.y, p.?.*.pixel, self.current_world.tex);
            }
        }
        if (self.player_mode) {
            self.player.?.draw(&self.e.renderer, self.current_world.tex);
        }
        self.e.renderer.draw_pixel(self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y, self.placement_pixel[self.placement_index].pixel, self.current_world.tex);
        try self.e.renderer.flip(self.current_world.tex, self.current_world.viewport);
    }
    pub fn run(self: *Self) !void {
        self.lock = std.Thread.Mutex{};
        self.e = try engine.Engine(utils.ColorMode.color_true).init(self.allocator);
        std.debug.print("starting height {d}\n", .{self.e.renderer.terminal.size.height});
        self.current_world = try World.init(self.world_width, @as(u32, @intCast(self.e.renderer.terminal.size.height)) + 10, @as(u32, @intCast(self.e.renderer.terminal.size.width)), @as(u32, @intCast(self.e.renderer.terminal.size.height)), self.allocator);
        self.pixels = std.ArrayList(?*PhysicsPixel).init(self.allocator);
        for (0..self.current_world.tex.width * self.current_world.tex.height) |_| {
            try self.pixels.append(null);
        }
        self.current_world.viewport.x = self.starting_pos_x;
        self.current_world.viewport.y = self.starting_pos_y;

        self.assets = AssetManager.init(self.allocator);
        try self.assets.load("basic", "basic0.png");
        var font: Font = Font.init(self.allocator);
        try font.load("arial.ttf", 24, &self.e.renderer);
        self.font_tex = try font.texture_from_string("HELLO WORLD");
        font.deinit();
        self.e.on_key_down(Self, on_key_down, self);
        self.e.on_key_up(Self, on_key_up, self);
        self.e.on_render(Self, on_render, self);
        self.e.on_mouse_change(Self, on_mouse_change, self);
        self.e.on_window_change(Self, on_window_change, self);
        self.e.set_fps(60);
        try self.e.start();

        var timer: std.time.Timer = try std.time.Timer.start();
        var delta: u64 = 0;
        var active_pixels: u64 = 0;
        while (self.running) {
            delta = timer.read();
            timer.reset();
            self.lock.lock();
            for (0..self.pixels.items.len) |i| {
                if (self.pixels.items[i] != null) {
                    self.pixels.items[i].?.*.dirty = false;
                }
            }
            const y_start = self.current_world.tex.height - 1;
            const x_start = self.current_world.tex.width - 1;
            var y = y_start;
            if (self.player_mode) {
                try self.player.?.update(self.pixels.items, self.current_world.tex.width, self.current_world.tex.height);
            }
            while (y >= 0) : (y -= 1) {
                var x = x_start;
                while (x >= 0) : (x -= 1) {
                    var p = self.pixels.items[y * self.current_world.tex.width + x];
                    if (p != null and !p.?.*.dirty and p.?.pixel_type != .Empty and p.?.pixel_type != .Object) {
                        //std.debug.print("updating {any}\n", .{p.?});
                        p.?.update(self.pixels.items, self.current_world.tex.width, self.current_world.tex.height);
                        active_pixels = if (p.?.active) active_pixels + 1 else active_pixels;
                    }
                    if (x == 0) break;
                }
                if (y == 0) break;
            }
            self.lock.unlock();
            delta = timer.read();
            timer.reset();
            const time_to_sleep: i64 = @as(i64, @bitCast(self.frame_limit)) - @as(i64, @bitCast(delta));
            //std.debug.print("time to sleep {d}, active pixels {d}\n", .{ time_to_sleep, active_pixels });
            if (time_to_sleep > 0) {
                std.time.sleep(@as(u64, @bitCast(time_to_sleep)));
            }
            active_pixels = 0;
        }
    }
};
