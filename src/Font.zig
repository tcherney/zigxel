const std = @import("std");
const _ttf = @import("ttf.zig");
const _texture = @import("texture.zig");
const utils = @import("utils.zig");

pub const Point = utils.Point(i32);
pub const TTF = _ttf.TTF;
pub const Texture = _texture.Texture;

pub const Font = struct {
    ttf: TTF = undefined,
    allocator: std.mem.Allocator,

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .ttf = TTF.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn draw_char(self: *Self, graphics: anytype, character: u8) !void {
        const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(character);
        if (glyph_outline) |outline| {
            const width = outline.x_max - outline.x_min + 200;
            const height = outline.y_max - outline.y_min + 200;
            var tex: *Texture = try self.allocator.create(Texture);
            tex.* = Texture.init(self.allocator);
            try tex.rect(@as(u32, @bitCast(@as(i32, @intCast(width)))), @as(u32, @bitCast(@as(i32, @intCast(height)))), 0, 0, 0, 255);

            var p0: Point = undefined;
            var p1: Point = undefined;
            p0.x = @as(i32, @intCast(outline.x_coord[0]));
            p0.y = @as(i32, @intCast(height)) - @as(i32, @intCast(outline.y_coord[0]));
            for (1..outline.x_coord.len) |i| {
                p1.x = @as(i32, @intCast(outline.x_coord[i]));
                p1.y = @as(i32, @intCast(height)) - @as(i32, @intCast(outline.y_coord[i]));
                graphics.draw_line(.{ .r = 255, .g = 255, .b = 255 }, p0, p1, tex.*);
                p0.x = p1.x;
                p0.y = p1.y;
            }
            try tex.image_core().write_BMP("char.bmp");
            tex.deinit();
            self.allocator.destroy(tex);
        }
    }

    pub fn load(self: *Self, file_name: []const u8) !void {
        try self.ttf.load(file_name);
    }

    pub fn deinit(self: *Self) void {
        self.ttf.deinit();
    }
};
