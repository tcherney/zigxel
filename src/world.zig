pub const texture = @import("texture.zig");
pub const common = @import("common");
pub const std = @import("std");

pub const Texture = texture.Texture;

pub const World = struct {
    tex: Texture,
    bounds: common.Rectangle,
    viewport: common.Rectangle = undefined,
    allocator: std.mem.Allocator,
    const Self = @This();
    pub const Error = error{} || Texture.Error;
    pub fn init(w_width: u32, w_height: u32, v_width: u32, v_height: u32, allocator: std.mem.Allocator) Error!Self {
        var world_tex = Texture.init(allocator);
        try world_tex.rect(w_width, w_height, 0, 0, 0, 255);
        return Self{
            .tex = world_tex,
            .bounds = common.Rectangle{
                .x = 0,
                .y = 0,
                .height = world_tex.height,
                .width = world_tex.width,
            },
            .viewport = common.Rectangle{
                .x = 0,
                .y = 0,
                .width = v_width,
                .height = v_height,
            },
            .allocator = allocator,
        };
    }
    //TODO world generation

    pub fn print(self: *Self) Error!void {
        try texture.image_core.write_BMP(self.allocator, self.tex.pixel_buffer, self.tex.width, self.tex.height, "world.bmp");
    }

    pub fn deinit(self: *Self) void {
        self.tex.deinit();
    }
};
