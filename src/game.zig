const std = @import("std");
const builtin = @import("builtin");
const engine = @import("engine.zig");
const common = @import("common");
const image = @import("image");
const sprite = @import("sprite.zig");
const physic_pixel = @import("physics_pixel.zig");
const game_object = @import("game_object.zig");
const asset_manager = @import("asset_manager.zig");
const emcc = @import("emcc.zig");
const _player = @import("player.zig");
const _font = @import("font.zig");
const _tui = @import("tui.zig");

pub const Font = _font.Font;
pub const World = @import("world.zig").World;
pub const PhysicsPixel = physic_pixel.PhysicsPixel;
pub const Player = _player.Player;
pub const GameObject = game_object.GameObject;
pub const Texture = game_object.Texture;
pub const AssetManager = asset_manager.AssetManager;
pub const Engine = engine.Engine;
pub const TUI = engine.TUI(Game.State);
const GAME_LOG = std.log.scoped(.game);

pub const DEBUG = false;
pub const SINGLE_THREADED: bool = false;
pub const PROFILE_MODE: bool = true;
pub const WASM: bool = builtin.os.tag == .emscripten or builtin.os.tag == .wasi;
const TERMINAL_HEIGHT_OFFSET = 35;
const TERMINAL_WIDTH_OFFSET = 30;

pub const Game = struct {
    running: bool = true,
    e: Engine = undefined,
    fps_buffer: [64]u8 = undefined,
    world_width: u32 = 5000,
    starting_pos_x: i32 = if (WASM) 0 else 5000 / 2,
    starting_pos_y: i32 = if (WASM) 0 else 10,
    placement_pixel: []PhysicsPixel = undefined,
    placement_index: usize = 0,
    current_world: World = undefined,
    assets: AssetManager = undefined,
    allocator: std.mem.Allocator = undefined,
    frame_limit: u64 = 16_666_667,
    player_mode: bool = false,
    lock: std.Thread.Mutex = undefined,
    render_lock: std.Thread.Mutex = undefined,
    old_mouse_x: i32 = -1,
    old_mouse_y: i32 = -1,
    player: ?Player = null,
    game_objects: std.ArrayList(GameObject) = undefined,
    tui: TUI,
    state: State = .start,
    timer: std.time.Timer = undefined,
    delta: u64 = undefined,
    active_pixels: u64 = undefined,
    pub const State = enum {
        game,
        start,
    };
    const Self = @This();
    pub const Error = error{} || image.Image.Error || engine.Error || std.posix.GetRandomError || std.mem.Allocator.Error || Texture.Error || Player.Error;
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        var ret = Self{ .allocator = allocator, .tui = TUI.init(allocator, .pixel) };
        try common.gen_rand();
        ret.placement_pixel = try ret.allocator.alloc(PhysicsPixel, 14);
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
        ret.placement_pixel[12] = PhysicsPixel.init(physic_pixel.PixelType.WhiteWall, ret.starting_pos_x, ret.starting_pos_y);
        ret.placement_pixel[13] = PhysicsPixel.init(physic_pixel.PixelType.Empty, ret.starting_pos_x, ret.starting_pos_y);
        return ret;
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        self.assets.deinit();
        self.tui.deinit();
        self.current_world.deinit();
        for (0..self.game_objects.items.len) |i| {
            self.game_objects.items[i].deinit();
        }
        self.game_objects.deinit();
        self.allocator.free(self.placement_pixel);
        if (self.player != null) {
            self.player.?.deinit();
        }
    }

    pub fn place_pixel(self: *Self) !void {
        var indx: u32 = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.current_world.pixels.items.len and self.current_world.pixels.items[indx] == null) {
            self.current_world.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.current_world.pixels.items.len) {
            const temp = self.current_world.pixels.items[indx].?.managed;
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y);
            self.current_world.pixels.items[indx].?.*.managed = temp;
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y + 1)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x));
        if (indx >= 0 and indx < self.current_world.pixels.items.len and self.current_world.pixels.items[indx] == null) {
            self.current_world.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y + 1);
        } else if (indx >= 0 and indx < self.current_world.pixels.items.len) {
            const temp = self.current_world.pixels.items[indx].?.managed;
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y + 1);
            self.current_world.pixels.items[indx].?.*.managed = temp;
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x + 1));
        if (indx >= 0 and indx < self.current_world.pixels.items.len and self.current_world.pixels.items[indx] == null) {
            self.current_world.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y);
        } else if (indx >= 0 and indx < self.current_world.pixels.items.len) {
            const temp = self.current_world.pixels.items[indx].?.managed;
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y);
            self.current_world.pixels.items[indx].?.*.managed = temp;
        }
        indx = @as(u32, @bitCast(self.placement_pixel[self.placement_index].y + 1)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x + 1));
        if (indx >= 0 and indx < self.current_world.pixels.items.len and self.current_world.pixels.items[indx] == null) {
            self.current_world.pixels.items[indx] = try self.allocator.create(PhysicsPixel);
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y + 1);
        } else if (indx >= 0 and indx < self.current_world.pixels.items.len) {
            const temp = self.current_world.pixels.items[indx].?.managed;
            self.current_world.pixels.items[indx].?.* = PhysicsPixel.init(self.placement_pixel[self.placement_index].pixel_type, self.placement_pixel[self.placement_index].x + 1, self.placement_pixel[self.placement_index].y + 1);
            self.current_world.pixels.items[indx].?.*.managed = temp;
        }
    }

    pub fn on_mouse_change(self: *Self, mouse_event: engine.MouseEvent) void {
        GAME_LOG.info("{any} {any}\n", .{ self.state, mouse_event });
        if (self.old_mouse_x == -1 or self.old_mouse_y == -1) {
            self.old_mouse_x = @as(i32, @intCast(mouse_event.x)) + self.current_world.viewport.x;
            self.old_mouse_y = @as(i32, @intCast(mouse_event.y)) * 2 + self.current_world.viewport.y;
        }
        switch (self.state) {
            .start => {
                if (mouse_event.clicked) {
                    GAME_LOG.info("Checking tui\n", .{});
                    self.tui.mouse_input(mouse_event.x, mouse_event.y * 2, self.state);
                }
            },
            .game => {
                self.placement_pixel[self.placement_index].x = @as(i32, @intCast(mouse_event.x)) + self.current_world.viewport.x;
                self.placement_pixel[self.placement_index].y = @as(i32, @intCast(mouse_event.y)) * 2 + self.current_world.viewport.y;
                const mouse_diff_x = self.placement_pixel[self.placement_index].x - self.old_mouse_x;
                const mouse_diff_y = self.placement_pixel[self.placement_index].y - self.old_mouse_y;
                self.old_mouse_x = self.placement_pixel[self.placement_index].x;
                self.old_mouse_y = self.placement_pixel[self.placement_index].y;
                if (mouse_event.clicked) {
                    GAME_LOG.info("placed {d} {d} \n", .{ self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y });
                    if (!SINGLE_THREADED and !WASM) {
                        self.lock.lock();
                    }
                    self.place_pixel() catch |err| {
                        GAME_LOG.info("{any}\n", .{err});
                        self.running = false;
                        return;
                    };
                    if (!SINGLE_THREADED and !WASM) {
                        self.lock.unlock();
                    }
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
                    GAME_LOG.info("{any} mouse {d} {d}\n", .{ mouse_event, mouse_diff_x, mouse_diff_y });
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
            },
        }
    }
    pub fn on_window_change(self: *Self, win_size: engine.WindowSize) void {
        GAME_LOG.info("on_window_change\n", .{});
        if (!SINGLE_THREADED and !WASM) {
            self.lock.lock();
            self.render_lock.lock();
        }
        GAME_LOG.info("changed height {d}\n", .{win_size.height});
        switch (self.state) {
            .start => {
                //todo
            },
            .game => {
                const w_width: u32 = if (win_size.width > self.world_width) win_size.width else self.world_width;
                self.current_world.resize(w_width, @as(u32, @intCast(self.e.renderer.pixel.pixel_height)) + 10, @as(u32, @intCast(self.e.renderer.pixel.pixel_width)), @as(u32, @intCast(self.e.renderer.pixel.pixel_height)), self.game_objects) catch |err| {
                    GAME_LOG.info("{any}\n", .{err});
                    self.running = false;
                    return;
                };
                self.current_world.viewport.x = self.starting_pos_x;
                self.current_world.viewport.y = self.starting_pos_y;
            },
        }
        if (!SINGLE_THREADED and !WASM) {
            self.lock.unlock();
            self.render_lock.unlock();
        }
    }

    pub fn on_key_down(self: *Self, key: engine.KEYS) void {
        GAME_LOG.info("{}\n", .{key});
        switch (self.state) {
            .start => {
                if (key == engine.KEYS.KEY_q) {
                    self.running = false;
                } else if (key == engine.KEYS.KEY_SPACE) {
                    self.state = .game;
                }
            },
            .game => {
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
                    if (self.player_mode) {
                        self.player.?.jump();
                        flip = true;
                    }
                } else if (key == engine.KEYS.KEY_s) {
                    if (!self.player_mode) {
                        self.placement_pixel[self.placement_index].y += 1;
                    }
                } else if (key == engine.KEYS.KEY_SPACE) {
                    GAME_LOG.info("placed {d} {d} \n", .{ self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y });
                    if (!SINGLE_THREADED and !WASM) {
                        self.lock.lock();
                    }
                    self.place_pixel() catch |err| {
                        GAME_LOG.info("{any}\n", .{err});
                        self.running = false;
                        return;
                    };
                    if (!SINGLE_THREADED and !WASM) {
                        self.lock.unlock();
                    }
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
                        GAME_LOG.info("{any}\n", .{err});
                        self.running = false;
                    };
                } else if (key == engine.KEYS.KEY_c) {
                    self.toggle_player_mode();
                }
            },
        }
    }

    fn toggle_player_mode(self: *Self) void {
        self.player_mode = !self.player_mode;
        if (self.player_mode) {
            if (self.player == null) {
                const tex = self.assets.get_texture("basic") catch |err| {
                    GAME_LOG.info("{any}\n", .{err});
                    self.running = false;
                    return;
                };
                self.player = Player.init(self.current_world.viewport.x, self.current_world.viewport.y, self.current_world.tex.width, tex, self.allocator) catch |err| {
                    GAME_LOG.info("{any}\n", .{err});
                    self.running = false;
                    return;
                };
                self.player.?.go.add_sim(self.current_world.pixels.items, self.current_world.tex.width);
            }
        }
    }

    pub fn on_key_up(self: *Self, key: engine.KEYS) void {
        switch (self.state) {
            .start => {
                //todo
            },
            .game => {
                switch (key) {
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
                    else => {},
                }
            },
        }
    }

    pub fn on_start_clicked(self: *Self) void {
        GAME_LOG.info("Start clicked\n", .{});
        self.state = .game;
    }

    var rotate_test: f64 = 0;
    var elapsed: u64 = 0;
    var flip: bool = false;
    var rect_rot: f64 = 0;
    var debug_buffer: [256]u8 = undefined;
    pub fn on_render(self: *Self, dt: u64) !void {
        if (!SINGLE_THREADED and !WASM) {
            self.render_lock.lock();
        }
        //GAME_LOG.info("starting render in {any}\n", .{self.state});
        //GAME_LOG.info("set bg {any} {any} {any}\n", .{ self.current_world.tex.width, self.current_world.tex.height, self.current_world.tex.pixel_buffer.len });
        if (PROFILE_MODE) self.e.renderer.pixel.set_bg(33, 36, 40, self.current_world.tex) else self.e.renderer.pixel.set_bg(0, 0, 0, self.current_world.tex);
        //GAME_LOG.info("end set bg {any}\n", .{self.state});
        switch (self.state) {
            .start => {
                //GAME_LOG.info("drawing tui {any} \n", .{self.state});
                try self.tui.draw(&self.e.renderer, self.current_world.tex, self.current_world.viewport.x, self.current_world.viewport.y, self.state);
            },
            .game => {
                //GAME_LOG.info("drawing world {any} \n", .{self.state});
                for (self.current_world.pixels.items) |p| {
                    if (p != null and p.?.*.pixel_type != .Empty and !(p.?.pixel_type == .Object and p.?.managed)) {
                        self.e.renderer.pixel.draw_pixel(p.?.*.x, p.?.*.y, p.?.*.pixel, self.current_world.tex);
                    }
                }

                if (self.player_mode) {
                    try self.e.renderer.pixel.push();
                    try self.e.renderer.pixel.translate(.{ ._2d = .{ .x = @floatFromInt(self.player.?.go.pixels[self.player.?.go.pixels.len / 2].x), .y = @floatFromInt(self.player.?.go.pixels[self.player.?.go.pixels.len / 2].y) } });
                    try self.e.renderer.pixel.rotate(rotate_test);
                    if (elapsed > 12500000 and flip) {
                        rotate_test += 90;
                        if (rotate_test >= 360) {
                            rotate_test = 0;
                            flip = false;
                        }
                        elapsed = 0;
                    } else {
                        elapsed += dt;
                    }
                    try self.e.renderer.pixel.translate(.{ ._2d = .{ .x = -@as(f64, @floatFromInt(self.player.?.go.pixels[self.player.?.go.pixels.len / 2].x)), .y = -@as(f64, @floatFromInt(self.player.?.go.pixels[self.player.?.go.pixels.len / 2].y)) } });
                    self.player.?.draw(&self.e.renderer.pixel, self.current_world.tex);
                    self.e.renderer.pixel.pop();
                }
                for (0..self.game_objects.items.len) |i| {
                    if (self.game_objects.items[i].managed) {
                        self.game_objects.items[i].draw(&self.e.renderer.pixel, self.current_world.tex);
                    }
                }
                self.e.renderer.pixel.draw_pixel(self.placement_pixel[self.placement_index].x, self.placement_pixel[self.placement_index].y, self.placement_pixel[self.placement_index].pixel, self.current_world.tex);
                // try self.e.renderer.pixel.push();
                // try self.e.renderer.pixel.translate(.{ .x = @floatFromInt(self.placement_pixel[self.placement_index].x), .y = @floatFromInt(self.placement_pixel[self.placement_index].y) });
                // try self.e.renderer.pixel.rotate(rect_rot);
                // rect_rot += 1;
                // if (rect_rot >= 360) rect_rot = 0;
                // try self.e.renderer.pixel.translate(.{ .x = @floatFromInt(-self.placement_pixel[self.placement_index].x), .y = @floatFromInt(-self.placement_pixel[self.placement_index].y) });
                // self.e.renderer.pixel.draw_rect(@as(usize, @bitCast(@as(i64, @intCast(self.placement_pixel[self.placement_index].x - 5)))), @as(usize, @bitCast(@as(i64, @intCast(self.placement_pixel[self.placement_index].y - 5)))), 10, 10, 255, 255, 255, self.current_world.tex);
                // self.e.renderer.pixel.pop();
                if (DEBUG) {
                    const p = self.current_world.pixels.items[@as(u32, @bitCast(self.placement_pixel[self.placement_index].y)) * self.current_world.tex.width + @as(u32, @bitCast(self.placement_pixel[self.placement_index].x))];
                    if (p != null) {
                        try self.e.renderer.pixel.draw_text(try std.fmt.bufPrint(&debug_buffer, "FPS: {d:.2} Color ({any}), Type {any}", .{ self.e.fps, p.?.pixel, p.?.pixel_type }), 0, 0, 255, 255, 255);
                    }
                }
            },
        }
        try self.e.renderer.pixel.flip(self.current_world.tex, self.current_world.viewport);
        if (!SINGLE_THREADED and !WASM) {
            self.render_lock.unlock();
        }
        //GAME_LOG.info("ending render\n", .{});
    }
    //TODO add mouse down and mouse up handling along with touch for wasm where on down starts placing pixels and keeps placing until its released
    pub fn main_loop(ctx: *anyopaque) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        //GAME_LOG.info("starting main loop in {any} {any}\n", .{ self.state, WASM });
        if (!SINGLE_THREADED and !WASM) {
            self.lock.lock();
        }

        switch (self.state) {
            .start => {
                //self.tui.items.items[self.tui.items.items.len - 1].button.y += 1;
                if (WASM or SINGLE_THREADED) {
                    self.on_render(self.delta) catch |err| {
                        GAME_LOG.info("Error: {any}\n", .{err});
                        return;
                    };
                }
                if (SINGLE_THREADED and !WASM) {
                    self.e.events.handle_events() catch |err| {
                        GAME_LOG.info("Error: {any}\n", .{err});
                        return;
                    };
                }
            },
            .game => {
                for (0..self.current_world.pixels.items.len) |i| {
                    if (self.current_world.pixels.items[i] != null) {
                        self.current_world.pixels.items[i].?.*.dirty = false;
                        //GAME_LOG.info("{d} pixel {any}\n", .{ i, self.current_world.pixels.items[i] });
                    }
                }
                const y_start = self.current_world.tex.height - 1;
                const x_start = self.current_world.tex.width - 1;
                var y = y_start;
                if (self.player_mode) {
                    self.player.?.update(self.current_world.pixels.items, self.current_world.tex.width, self.current_world.tex.height) catch |err| {
                        GAME_LOG.info("Error: {any}\n", .{err});
                        return;
                    };
                }
                for (0..self.game_objects.items.len) |i| {
                    if (self.game_objects.items[i].managed) {
                        self.game_objects.items[i].update(self.current_world.pixels.items, self.current_world.tex.width, self.current_world.tex.height) catch |err| {
                            GAME_LOG.info("Error: {any}\n", .{err});
                            return;
                        };
                    }
                }
                while (y >= 0) : (y -= 1) {
                    var x = x_start;
                    while (x >= 0) : (x -= 1) {
                        var p = self.current_world.pixels.items[y * self.current_world.tex.width + x];
                        if (p != null and !p.?.*.dirty and p.?.pixel_type != .Empty and !(p.?.pixel_type == .Object and p.?.managed)) {
                            //GAME_LOG.info("updating {any}\n", .{p.?});
                            p.?.update(self.current_world.pixels.items, self.current_world.tex.width, self.current_world.tex.height);
                            self.active_pixels = if (p.?.active) self.active_pixels + 1 else self.active_pixels;
                        }
                        if (x == 0) break;
                    }
                    if (y == 0) break;
                }
                if (WASM or SINGLE_THREADED) {
                    self.on_render(self.delta) catch |err| {
                        GAME_LOG.info("Error: {any}\n", .{err});
                        return;
                    };
                }
                if (SINGLE_THREADED and !WASM) {
                    self.e.events.handle_events() catch |err| {
                        GAME_LOG.info("Error: {any}\n", .{err});
                        return;
                    };
                }
            },
        }
        if (!SINGLE_THREADED and !WASM) {
            self.lock.unlock();
        }

        self.active_pixels = 0;
        //GAME_LOG.info("end main loop\n", .{});
        //return true;
    }

    pub fn em_click_handler(event_type: c_int, event: ?*const emcc.EmsdkWrapper.EmscriptenMouseEvent, ctx: ?*anyopaque) callconv(.C) bool {
        GAME_LOG.info("event_type {any}\n", .{event_type});
        GAME_LOG.info("event {any}\n", .{event});
        const self: *Self = @ptrCast(@alignCast(ctx));
        const width = 780;
        const height = 550;
        const scale_x: f64 = @as(f64, @floatFromInt(event.?.targetX)) / @as(f64, @floatFromInt(width));
        const scale_y: f64 = @as(f64, @floatFromInt(event.?.targetY)) / @as(f64, @floatFromInt(height));
        const res_x: i16 = @intFromFloat(scale_x * @as(f64, @floatFromInt(self.e.renderer.pixel.pixel_width)));
        const res_y: i16 = @intFromFloat((scale_y * @as(f64, @floatFromInt(self.e.renderer.pixel.pixel_height))) / 2);
        self.on_mouse_change(.{
            .x = res_x,
            .y = res_y,
            .clicked = (event.?.buttons & 0x03) > 0,
            .scroll_up = false,
            .scroll_down = false,
            .ctrl_pressed = false,
        });
        return true;
    }

    pub fn em_touch_handler(event_type: c_int, event: ?*const emcc.EmsdkWrapper.EmscriptenTouchEvent, ctx: ?*anyopaque) callconv(.C) bool {
        GAME_LOG.info("event_type {any}\n", .{event_type});
        GAME_LOG.info("event {any}\n", .{event});
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (event.?.numTouches > 0) {
            const width = 780;
            const height = 550;
            const scale_x: f64 = @as(f64, @floatFromInt(event.?.touches[0].targetX)) / @as(f64, @floatFromInt(width));
            const scale_y: f64 = @as(f64, @floatFromInt(event.?.touches[0].targetY)) / @as(f64, @floatFromInt(height));
            const res_x: i16 = @intFromFloat(scale_x * @as(f64, @floatFromInt(self.e.renderer.pixel.pixel_width)));
            const res_y: i16 = @intFromFloat((scale_y * @as(f64, @floatFromInt(self.e.renderer.pixel.pixel_height))) / 2);
            self.on_mouse_change(.{
                .x = res_x,
                .y = res_y,
                .clicked = event.?.numTouches == 1,
                .scroll_up = event.?.numTouches == 2,
                .scroll_down = event.?.numTouches == 3,
                .ctrl_pressed = false,
            });
        }

        return true;
    }

    pub fn em_wheel_handler(event_type: c_int, event: ?*const emcc.EmsdkWrapper.EmscriptenWheelEvent, ctx: ?*anyopaque) callconv(.C) bool {
        GAME_LOG.info("event_type {any}\n", .{event_type});
        GAME_LOG.info("event {any}\n", .{event});
        const self: *Self = @ptrCast(@alignCast(ctx));
        const scroll_up = event.?.deltaY < 0;
        self.on_mouse_change(.{
            .x = @truncate(self.placement_pixel[self.placement_index].x),
            .y = @truncate(@divFloor(self.placement_pixel[self.placement_index].y, 2)),
            .clicked = (event.?.mouse.buttons & 0x03) > 0,
            .scroll_up = scroll_up,
            .scroll_down = !scroll_up,
            .ctrl_pressed = false,
        });
        return true;
    }

    pub fn run(self: *Self) !void {
        self.lock = std.Thread.Mutex{};
        self.render_lock = std.Thread.Mutex{};
        engine.set_wasm_terminal_size(50, 130);
        self.e = try Engine.init(self.allocator, TERMINAL_WIDTH_OFFSET, TERMINAL_HEIGHT_OFFSET, .pixel, ._2d, .color_true, if (WASM) .wasm else .native, if (WASM) .single else .multi);
        GAME_LOG.info("starting height {d} starting width {d}\n", .{ self.e.renderer.pixel.terminal.size.height, self.e.renderer.pixel.terminal.size.width });
        self.current_world = if (WASM) try World.init(@as(u32, @intCast(self.e.renderer.pixel.pixel_width)), @as(u32, @intCast(self.e.renderer.pixel.pixel_height)), @as(u32, @intCast(self.e.renderer.pixel.pixel_width)), @as(u32, @intCast(self.e.renderer.pixel.pixel_height)), self.allocator) else try World.init(self.world_width, @as(u32, @intCast(self.e.renderer.pixel.pixel_height)) + 10, @as(u32, @intCast(self.e.renderer.pixel.pixel_width)), @as(u32, @intCast(self.e.renderer.pixel.pixel_height)), self.allocator);
        try self.current_world.generate(.forest);

        self.current_world.viewport.x = self.starting_pos_x;
        self.current_world.viewport.y = self.starting_pos_y;

        self.state = .game;
        self.assets = AssetManager.init(self.allocator);
        self.game_objects = std.ArrayList(GameObject).init(self.allocator);
        if (PROFILE_MODE) {
            self.placement_index = 6; // set default to explosive
            try self.assets.load_texture("profile", "assets/profile.jpg");
            var t = try self.assets.get_texture("profile");
            try t.scale(85, 85);
            try self.game_objects.append(try GameObject.init(self.current_world.viewport.x, self.current_world.viewport.y + if (self.current_world.viewport.height > t.height) @as(i32, @bitCast(self.current_world.viewport.height - t.height)) else 0, self.current_world.tex.width, try self.assets.get_texture("profile"), false, false, .Object, self.allocator));
            try self.assets.load_font("envy", "assets/envy.ttf", 22, &self.e.renderer);
            try self.assets.load_font_texture("Timothy", "envy");
            try self.assets.load_font_texture("Cherney", "envy");
            const t_tex = try self.assets.get_texture("Timothy");
            try self.game_objects.append(try GameObject.init(self.current_world.viewport.x, self.current_world.viewport.y + if (self.current_world.viewport.height > t.height + t_tex.height) @as(i32, @bitCast(self.current_world.viewport.height - t.height)) - @as(i32, @bitCast(t_tex.height)) else 0, self.current_world.tex.width, t_tex, false, false, .Wood, self.allocator));
            try self.game_objects.append(try GameObject.init(self.current_world.viewport.x + @as(i32, @bitCast(t_tex.width)) + 5, self.current_world.viewport.y + if (self.current_world.viewport.height > t.height + t_tex.height) @as(i32, @bitCast(self.current_world.viewport.height - t.height)) - @as(i32, @bitCast(t_tex.height)) else 0, self.current_world.tex.width, try self.assets.get_texture("Cherney"), false, false, .Wood, self.allocator));
        }
        if (!WASM) {
            try self.assets.load_texture("basic", "basic0.png");
        }
        for (0..self.game_objects.items.len) |i| {
            self.game_objects.items[i].add_sim(self.current_world.pixels.items, self.current_world.tex.width);
        }
        const tui_adjust = self.e.renderer.pixel.terminal.size.height % 2 == 1;
        var button_y = (self.e.renderer.pixel.pixel_height / 2);
        if (tui_adjust) button_y -= 1;
        try self.tui.add_button(self.e.renderer.pixel.pixel_width / 2, button_y, null, null, common.Colors.WHITE, common.Colors.BLUE, common.Colors.MAGENTA, self.assets.strings[@intFromEnum(AssetManager.StringIndex.START)], .start);
        self.tui.items.items[self.tui.items.items.len - 1].set_on_click(Self, on_start_clicked, self);
        self.e.on_key_down(Self, on_key_down, self);
        self.e.on_key_up(Self, on_key_up, self);
        self.e.on_render(Self, on_render, self);
        self.e.on_mouse_change(Self, on_mouse_change, self);
        self.e.on_window_change(Self, on_window_change, self);
        self.e.set_fps(60);
        //GAME_LOG.info("current world {any}\n", .{self.current_world});
        GAME_LOG.info("starting\n", .{});
        try self.e.start();
        GAME_LOG.info("started\n", .{});
        self.timer = try std.time.Timer.start();
        self.delta = 0;
        self.active_pixels = 0;
        // const time_to_place = std.time.ns_per_s;
        // var time_elapsed: u64 = 0;
        if (WASM) {
            //var ptr: *anyopaque = self;
            //emcc.EmsdkWrapper.emscripten_set_main_loop_arg(main_loop, self, 0, 0);
            //emcc.EmsdkWrapper.emscripten_request_animation_frame_loop(main_loop, self);
            GAME_LOG.info("setting handlers\n", .{});
            var res = emcc.EmsdkWrapper.emscripten_set_mousedown_callback("#output-container", self, true, em_click_handler);
            res = emcc.EmsdkWrapper.emscripten_set_mousemove_callback("#output-container", self, true, em_click_handler);
            res = emcc.EmsdkWrapper.emscripten_set_touchstart_callback("#output-container", self, true, em_touch_handler);
            res = emcc.EmsdkWrapper.emscripten_set_touchmove_callback("#output-container", self, true, em_touch_handler);
            GAME_LOG.info("result {any}\n", .{res});
            res = emcc.EmsdkWrapper.emscripten_set_wheel_callback("#output-container", self, true, em_wheel_handler);
        }
        while (self.running) {
            self.delta = self.timer.read();
            self.timer.reset();
            main_loop(self);
            self.delta = self.timer.read();
            // time_elapsed += self.delta;
            // GAME_LOG.info("time elapsed {any} out of {any}\n", .{ time_elapsed, time_to_place });
            // if (time_elapsed > time_to_place) {
            //     self.place_pixel() catch |err| {
            //         GAME_LOG.info("{any}\n", .{err});
            //         self.running = false;
            //         return;
            //     };
            //     time_elapsed = 0;
            // }
            self.timer.reset();
            const time_to_sleep: i64 = @as(i64, @bitCast(self.frame_limit)) - @as(i64, @bitCast(self.delta));
            //GAME_LOG.info("time to sleep {d}, active pixels {d}\n", .{ time_to_sleep, active_pixels });
            if (time_to_sleep > 0) {
                if (WASM) {
                    const to_sleep_u: u64 = @bitCast(time_to_sleep);
                    //std.debug.print("time to sleep {d}\n", .{to_sleep_u / std.time.ns_per_ms});
                    emcc.EmsdkWrapper.emscripten_sleep(@truncate(to_sleep_u / std.time.ns_per_ms));
                } else {
                    std.time.sleep(@as(u64, @bitCast(time_to_sleep)));
                }
            } else {
                if (WASM) {
                    emcc.EmsdkWrapper.emscripten_sleep(1);
                }
            }
        }
    }
};
