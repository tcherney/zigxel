const std = @import("std");
const game_object = @import("game_object.zig");
const physics_pixel = @import("physics_pixel.zig");
const weapons = @import("weapons.zig");

pub const PixelRenderer = @import("pixel_renderer.zig").PixelRenderer;
pub const GameObject = game_object.GameObject;
pub const Weapon = weapons.Weapon;

pub const Player = struct {
    allocator: std.mem.Allocator,
    go: GameObject,
    weapon: Weapon,
    const Self = @This();
    pub const Error = error{} || GameObject.Error || Weapon.Error;
    pub fn init(x: i32, y: i32, w_width: u32, tex: *game_object.Texture, allocator: std.mem.Allocator) Error!Self {
        return Self{
            .allocator = allocator,
            .go = try GameObject.init(x, y, w_width, tex, true, false, .Object, allocator),
            .weapon = try Weapon.init(.explosive, allocator),
        };
    }

    pub fn move_left(self: *Self) void {
        self.go.left = true;
        self.go.right = false;
    }

    pub fn move_right(self: *Self) void {
        self.go.right = true;
        self.go.left = false;
    }

    pub fn stop_move_left(self: *Self) void {
        self.go.left = false;
    }

    pub fn stop_move_right(self: *Self) void {
        self.go.right = false;
    }

    pub fn jump(self: *Self) void {
        self.go.jumping = true;
        self.go.jumping_duration = 0;
    }

    //TODO add explosive player attack

    pub fn update(self: *Self, pixels: []?*physics_pixel.PhysicsPixel, xlimit: u32, ylimit: u32) Error!void {
        try self.go.update(pixels, xlimit, ylimit);
    }

    pub fn draw(self: *Self, renderer: *PixelRenderer, dest: ?game_object.Texture) void {
        self.go.draw(renderer, dest);
    }

    pub fn deinit(self: *Self) void {
        self.go.deinit();
    }
};
