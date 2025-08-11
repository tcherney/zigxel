const std = @import("std");
const physics_pixel = @import("physics_pixel.zig");

pub const Allocator = std.mem.Allocator;
pub const PhysicsPixel = physics_pixel.PhysicsPixel;
pub const PixelRenderer = @import("pixel_renderer.zig").PixelRenderer;

pub const Weapon = struct {
    projectile: *PhysicsPixel,
    speed: u64,
    effect: ProjectileEffect,
    allocator: Allocator,
    weapon_type: WeaponType,
    pub const Error = error{InvalidWeaponType} || Allocator.Error;
    pub const ProjectileEffect = enum { trail };
    pub const WeaponType = enum { explosive };
    pub fn init(weapon_type: WeaponType, allocator: Allocator) Error!Weapon {
        switch (weapon_type) {
            .explosive => {
                const p = try allocator.create(PhysicsPixel);
                p.* = PhysicsPixel.init(.Explosive, 0, 0);
                return .{
                    .projectile = p,
                    .speed = 1,
                    .effect = .trail,
                    .allocator = allocator,
                    .weapon_type = weapon_type,
                };
            },
        }
        return Error.InvalidWeaponType;
    }
    pub fn deinit(self: *Weapon) void {
        self.allocator.destroy(self.projectile);
    }
    //TODO
    pub fn update(self: *Weapon, dt: u64) void {
        _ = self;
        _ = dt;
    }
    //TODO
    pub fn shoot(self: *Weapon, x: i32, y: i32) void {
        _ = self;
        _ = x;
        _ = y;
    }
    //TODO draw projectile and effect until it hits something, then projectile will be taken over by sim
    pub fn draw(self: *Weapon, renderer: *PixelRenderer) void {
        _ = self;
        _ = renderer;
    }
};
