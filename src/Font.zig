const std = @import("std");
const _ttf = @import("ttf.zig");
const _texture = @import("texture.zig");
const utils = @import("utils.zig");

pub const Point = utils.Point(i32);
pub const TTF = _ttf.TTF;
pub const Texture = _texture.Texture;
pub const Pixel = _texture.Pixel;

var num_chars: usize = 0;

pub const Font = struct {
    ttf: TTF = undefined,
    allocator: std.mem.Allocator,
    color: Pixel,
    chars: std.AutoHashMap(u8, *Texture),
    font_size: u16 = undefined,
    scale: f32 = undefined,
    const Edge = struct {
        p0: Point,
        p1: Point,
        x: i32 = -1,
        pub fn sort_y(_: void, lhs: Edge, rhs: Edge) bool {
            const lhs_y_min = @min(lhs.p0.y, lhs.p1.y);
            const rhs_y_min = @min(rhs.p0.y, rhs.p1.y);
            if (lhs_y_min == rhs_y_min) {
                const lhs_x_min = @min(lhs.p0.x, lhs.p1.x);
                const rhs_x_min = @min(rhs.p0.x, rhs.p1.x);
                return lhs_x_min < rhs_x_min;
            }
            return lhs_y_min < rhs_y_min;
        }
        pub fn sort_x(_: void, lhs: Edge, rhs: Edge) bool {
            return lhs.x < rhs.x;
        }
    };
    const Self = @This();
    pub const Error = error{CharNotSupported} || std.mem.Allocator.Error || std.fmt.BufPrintError;
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .ttf = TTF.init(allocator),
            .allocator = allocator,
            .color = .{ .r = 255, .g = 255, .b = 255 },
            .chars = std.AutoHashMap(u8, *Texture).init(allocator),
        };
    }

    pub fn set_size(self: *Self, font_size: u16) void {
        self.font_size = font_size;
        std.debug.print("units per em {any}, font_size {any}\n", .{ self.ttf.font_directory.head.units_per_em, font_size });
        self.scale = (1.0 / @as(f32, @floatFromInt(self.ttf.font_directory.head.units_per_em))) * @as(f32, @floatFromInt(font_size));
    }

    //TODO subdivide the curves by 2-4x to lower the error of the edges
    fn gen_edges(self: *Self, outline: *TTF.GlyphOutline) Error!std.ArrayList(Edge) {
        var edges: std.ArrayList(Edge) = std.ArrayList(Edge).init(self.allocator);
        var bezier_indx: usize = 0;
        std.debug.print("scale {any}\n", .{self.scale});
        for (0..outline.end_contours.len) |i| {
            //var extra_pt: ?TTF.Point = null;
            var j: usize = bezier_indx;
            while (j < outline.end_curves[i]) : (j += 1) {
                try edges.append(Edge{
                    .p0 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(outline.curves[j].p0.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(outline.curves[j].p0.y)) * self.scale)),
                    },
                    .p1 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(outline.curves[j].p2.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(outline.curves[j].p2.y)) * self.scale)),
                    },
                });
            }
            bezier_indx = outline.end_curves[i];
        }
        return edges;
    }

    //TODO figure out kerning
    pub fn texture_from_string(self: *Self, str: []const u8) !*Texture {
        var tex: ?*Texture = null;
        for (str) |character| {
            const char_tex = self.chars.get(character);
            if (tex == null) {
                std.debug.print("grabbing copy\n", .{});
                if (char_tex == null or character == ' ') {
                    var iter = self.chars.valueIterator();
                    const other_char_tex = iter.next().?.*;
                    tex = try self.allocator.create(Texture);
                    tex.?.* = Texture.init(self.allocator);
                    try tex.?.rect(other_char_tex.width, other_char_tex.height, 0, 0, 0, 255);
                } else {
                    tex = try char_tex.?.*.copy();
                }
            } else {
                std.debug.print("resizing\n", .{});
                if (char_tex == null or character == ' ') {
                    var iter = self.chars.valueIterator();
                    try tex.?.resize(tex.?.width + iter.next().?.*.width + 10, tex.?.height);
                } else {
                    const larger_height = @max(char_tex.?.height, tex.?.height);
                    try tex.?.resize(tex.?.width + char_tex.?.*.width + 10, larger_height);
                    for (0..char_tex.?.*.height) |i| {
                        for (0..char_tex.?.*.width) |j| {
                            tex.?.pixel_buffer[i * tex.?.width + (j + (tex.?.width - char_tex.?.*.width))] = char_tex.?.*.pixel_buffer[i * char_tex.?.*.width + j];
                        }
                    }
                }
            }
        }
        try tex.?.image_core().write_BMP("string.bmp");
        return tex.?;
    }

    //https://medium.com/@dillihangrae/scanline-filling-algorithm-852ad47fb0dd
    //https://gabormakesgames.com/blog_polygons_scanline.html
    fn gen_char(self: *Self, graphics: anytype, character: u8) !*Texture {
        const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(character);
        if (glyph_outline != null) {
            var outline: TTF.GlyphOutline = glyph_outline.?;
            const width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(outline.x_max - outline.x_min)) * self.scale));
            const height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(outline.y_max - outline.y_min)) * self.scale));
            var tex: *Texture = try self.allocator.create(Texture);
            tex.* = Texture.init(self.allocator);
            try tex.rect(width, height, 0, 0, 0, 255);

            std.debug.print("width {d}, height {d}\n", .{ width, height });
            std.debug.print("contour starts {any}\n", .{outline.end_curves});
            std.debug.print("curves {any}\n", .{outline.curves});
            var edges: std.ArrayList(Edge) = try self.gen_edges(&outline);
            std.debug.print("before sort {any}\n", .{edges.items});
            std.mem.sort(Edge, edges.items, {}, Edge.sort_y);
            std.debug.print("after sort {any}\n", .{edges.items});
            var active_edges: std.ArrayList(Edge) = std.ArrayList(Edge).init(self.allocator);
            var first_edge: usize = 0;
            for (0..height) |i| {
                while (first_edge < edges.items.len) {
                    const edge = edges.items[first_edge];
                    if (@min(edge.p0.y, edge.p1.y) <= @as(i32, @intCast(@as(i64, @bitCast(i))))) {
                        try active_edges.append(edge);
                        first_edge += 1;
                    } else {
                        break;
                    }
                }
                var j: usize = 0;
                while (j < active_edges.items.len) {
                    const edge = active_edges.items[j];
                    if (@max(edge.p0.y, edge.p1.y) <= @as(i32, @intCast(@as(i64, @bitCast(i))))) {
                        _ = active_edges.orderedRemove(j);
                    } else {
                        j += 1;
                    }
                }
                for (0..active_edges.items.len) |k| {
                    const dy: i32 = active_edges.items[k].p1.y - active_edges.items[k].p0.y;
                    const dx: i32 = active_edges.items[k].p1.x - active_edges.items[k].p0.x;
                    if (dy == 0) continue;
                    if (dx == 0) {
                        active_edges.items[k].x = active_edges.items[k].p0.x;
                    } else {
                        active_edges.items[k].x = @as(i32, @intFromFloat((@as(f32, @floatFromInt(i)) - @as(f32, @floatFromInt(active_edges.items[k].p0.y))) * (@as(f32, @floatFromInt(dx)) / @as(f32, @floatFromInt(dy))) + @as(f32, @floatFromInt(active_edges.items[k].p0.x))));
                    }
                }
                if (active_edges.items.len < 1) continue;
                std.mem.sort(Edge, active_edges.items, {}, Edge.sort_x);
                var winding: i32 = 0;
                var curr_edge: usize = 0;
                for (@as(usize, @bitCast(@as(i64, @intCast(active_edges.items[0].x))))..@as(usize, @bitCast(@as(i64, @intCast(active_edges.items[active_edges.items.len - 1].x + 1))))) |x| {
                    while (curr_edge != active_edges.items.len and active_edges.items[curr_edge].x < @as(i32, @intCast(@as(i64, @bitCast(x))))) {
                        if (active_edges.items[curr_edge].p0.y <= @as(i32, @intCast(@as(i64, @bitCast(i)))) and active_edges.items[curr_edge].p1.y > @as(i32, @intCast(@as(i64, @bitCast(i))))) {
                            winding -= 1;
                        } else if (active_edges.items[curr_edge].p1.y <= @as(i32, @intCast(@as(i64, @bitCast(i)))) and active_edges.items[curr_edge].p0.y > @as(i32, @intCast(@as(i64, @bitCast(i))))) {
                            winding += 1;
                        }
                        curr_edge += 1;
                    }

                    if (winding != 0) {
                        graphics.draw_pixel(@as(i32, @intCast(@as(i64, @bitCast(x)))), @as(i32, @intCast(@as(i64, @bitCast(i)))), self.color, tex.*);
                    }
                }
            }
            active_edges.deinit();
            // for (edges.items, 0..edges.items.len) |edge, j| {
            //     if (j % 2 == 0) {
            //         graphics.draw_line(.{ .r = 255, .g = 0, .b = 0 }, edge.p0, edge.p1, tex.*);
            //     } else if (j % 3 == 0) {
            //         graphics.draw_line(.{ .r = 0, .g = 255, .b = 0 }, edge.p0, edge.p1, tex.*);
            //     } else if (j % 2 == 1) {
            //         graphics.draw_line(.{ .r = 0, .g = 0, .b = 255 }, edge.p0, edge.p1, tex.*);
            //     }
            // }
            edges.deinit();
            const f_name = ".bmp";
            var buff_name: [16]u8 = undefined;
            try tex.image_core().write_BMP(try std.fmt.bufPrint(&buff_name, "{d}{s}", .{ num_chars, f_name }));
            num_chars += 1;
            return tex;
        } else return Error.CharNotSupported;
    }

    pub fn load(self: *Self, file_name: []const u8, font_size: u16, graphics: anytype) !void {
        try self.ttf.load(file_name);
        self.set_size(font_size);
        var key_iter = self.ttf.char_map.keyIterator();
        var key: ?*u8 = key_iter.next();
        var current_font_size: u16 = font_size;
        while (key != null) : (key = key_iter.next()) {
            const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(key.?.*);
            if (glyph_outline != null) {
                const width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(glyph_outline.?.x_max - glyph_outline.?.x_min)) * self.scale));
                const height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(glyph_outline.?.y_max - glyph_outline.?.y_min)) * self.scale));
                if (width == 0 or height == 0) {
                    current_font_size += 1;
                    self.set_size(current_font_size);
                    key_iter = self.ttf.char_map.keyIterator();
                }
            }
        }
        key_iter = self.ttf.char_map.keyIterator();
        key = key_iter.next();
        while (key != null) : (key = key_iter.next()) {
            std.debug.print("generating char {any} {d}\n", .{ key.?.*, num_chars });
            try self.chars.put(key.?.*, try self.gen_char(graphics, key.?.*));
        }
    }

    pub fn deinit(self: *Self) void {
        self.ttf.deinit();
        var iter = self.chars.valueIterator();
        var texture: ?**Texture = iter.next();
        while (texture != null) {
            texture.?.*.deinit();
            self.allocator.destroy(texture.?.*);
            texture = iter.next();
        }
        self.chars.deinit();
    }
};
