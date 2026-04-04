const std = @import("std");
const physics_pixel = @import("physics_pixel.zig");

pub const Allocator = std.mem.Allocator;
pub const PhysicsPixel = physics_pixel.PhysicsPixel;
pub const PixelRenderer = @import("pixel_renderer.zig").PixelRenderer;
pub const Point = @import("common").Point(2, i32);
//TODO implment weapon, start with none and trail effects with explosive end point
/// Weapons are projectiles that can be shot by the player or enemies, they have a speed, an effect and a type, they can be updated and drawn by the renderer, they can also be deinitialized when they are no longer needed
pub const Weapon = struct {
    projectile: *PhysicsPixel,
    speed: u64,
    effect: ProjectileEffect,
    allocator: Allocator,
    weapon_type: WeaponType,
    end_point: Point,
    pub const Error = error{InvalidWeaponType} || Allocator.Error;
    /// Effect that the trace applies, can be none, a visible trail, an explosive pixel being added at each step or a fire pixel being added at each step
    pub const ProjectileEffect = enum { none, trail, explosive, fire };
    /// PhysicsPixel that is used at end point point
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
    //TODO, move particle along and update trail effect, have to keep track of lifetime for visual trail
    pub fn update(self: *Weapon, dt: u64) void {
        _ = self;
        _ = dt;
    }
    //TODO, should be simple just configuring flags to be used in update
    pub fn shoot(self: *Weapon, x: i32, y: i32) void {
        _ = self;
        _ = x;
        _ = y;
    }
    //TODO should only need to draw visual trail effect rest will be handled by sim
    pub fn draw(self: *Weapon, renderer: *PixelRenderer) void {
        _ = self;
        _ = renderer;
    }
};
