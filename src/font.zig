const std = @import("std");
const _ttf = @import("ttf.zig");
const _texture = @import("texture.zig");
const common = @import("common");

pub const Point = common.Point(2, i32);
pub const TTF = _ttf.TTF;
pub const Texture = _texture.Texture;
pub const Pixel = _texture.Pixel;

var num_chars: usize = 0;

const FONT_LOG = std.log.scoped(.font);

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
    pub const Error = error{CharNotSupported} || std.mem.Allocator.Error || std.fmt.BufPrintError || TTF.Error || Texture.Error;
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .ttf = TTF.init(allocator),
            .allocator = allocator,
            .color = Pixel.init(255, 255, 255, null),
            .chars = std.AutoHashMap(u8, *Texture).init(allocator),
        };
    }

    pub fn set_size(self: *Self, font_size: u16) void {
        self.font_size = font_size;
        FONT_LOG.info("units per em {any}, font_size {any}, lowest rec {any}\n", .{ self.ttf.font_directory.head.units_per_em, font_size, self.ttf.font_directory.head.lowest_rec_PPEM });
        self.scale = (1.0 / @as(f32, @floatFromInt(self.ttf.font_directory.head.units_per_em))) * @as(f32, @floatFromInt(font_size));
    }

    fn split_bezier(curve: TTF.BezierCurve) struct { ade: TTF.BezierCurve, efc: TTF.BezierCurve } {
        var D: TTF.Point = undefined;
        D.x = @divFloor(curve.p0.x + curve.p1.x, 2);
        D.y = @divFloor(curve.p0.y + curve.p1.y, 2);

        var E: TTF.Point = undefined;
        E.x = @divFloor(curve.p0.x + curve.p1.x * 2 + curve.p2.x, 4);
        E.y = @divFloor(curve.p0.y + curve.p1.y * 2 + curve.p2.y, 4);

        var F: TTF.Point = undefined;
        F.x = @divFloor(curve.p1.x + curve.p2.x, 2);
        F.y = @divFloor(curve.p1.y + curve.p2.y, 2);

        return .{
            .ade = TTF.BezierCurve{
                .p0 = .{
                    .x = curve.p0.x,
                    .y = curve.p0.y,
                },
                .p1 = .{
                    .x = D.x,
                    .y = D.y,
                },
                .p2 = .{
                    .x = E.x,
                    .y = E.y,
                },
            },
            .efc = TTF.BezierCurve{
                .p0 = .{
                    .x = E.x,
                    .y = E.y,
                },
                .p1 = .{
                    .x = F.x,
                    .y = F.y,
                },
                .p2 = .{
                    .x = curve.p2.x,
                    .y = curve.p2.y,
                },
            },
        };
    }

    fn gen_edges(self: *Self, outline: *TTF.GlyphOutline) Error!std.ArrayList(Edge) {
        var edges: std.ArrayList(Edge) = std.ArrayList(Edge).init(self.allocator);
        var bezier_indx: usize = 0;
        FONT_LOG.info("scale {any}\n", .{self.scale});
        for (0..outline.end_contours.len) |i| {
            //var extra_pt: ?TTF.Point = null;
            var j: usize = bezier_indx;
            while (j < outline.end_curves[i]) : (j += 1) {
                const split_curve = split_bezier(outline.curves[j]);
                const double_split1 = split_bezier(split_curve.ade);
                const double_split2 = split_bezier(split_curve.efc);
                try edges.append(Edge{
                    .p0 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.ade.p0.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.ade.p0.y)) * self.scale)),
                    },
                    .p1 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.ade.p2.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.ade.p2.y)) * self.scale)),
                    },
                });
                try edges.append(Edge{
                    .p0 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.efc.p0.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.efc.p0.y)) * self.scale)),
                    },
                    .p1 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.efc.p2.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split1.efc.p2.y)) * self.scale)),
                    },
                });
                try edges.append(Edge{
                    .p0 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.ade.p0.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.ade.p0.y)) * self.scale)),
                    },
                    .p1 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.ade.p2.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.ade.p2.y)) * self.scale)),
                    },
                });
                try edges.append(Edge{
                    .p0 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.efc.p0.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.efc.p0.y)) * self.scale)),
                    },
                    .p1 = .{
                        .x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.efc.p2.x)) * self.scale)),
                        .y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(double_split2.efc.p2.y)) * self.scale)),
                    },
                });
            }
            bezier_indx = outline.end_curves[i];
        }
        return edges;
    }

    //TODO figure out kerning
    pub fn texture_from_string(self: *Self, str: []const u8) Error!*Texture {
        var tex: ?*Texture = null;
        var baseline_y: u32 = 0;
        for (0..str.len) |i| {
            const character = str[i];
            const char_tex = self.chars.get(character);
            FONT_LOG.info("rendering {c}\n", .{character});
            if (tex == null) {
                FONT_LOG.info("grabbing copy\n", .{});
                if (char_tex == null) continue;
                if (character == ' ') {
                    tex = try self.allocator.create(Texture);
                    tex.?.* = Texture.init(self.allocator);
                    try tex.?.rect(char_tex.?.width, char_tex.?.height, 0, 0, 0, 0);
                } else {
                    tex = try char_tex.?.*.copy();
                    const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(character);
                    const y_from_base = @as(u32, @intFromFloat(@abs(@as(f32, @floatFromInt(glyph_outline.?.y_min)) * self.scale)));
                    FONT_LOG.info("y_from_base {d}, baseline_y {d}\n", .{ y_from_base, baseline_y });
                    if (y_from_base > baseline_y) {
                        baseline_y = y_from_base;
                        try tex.?.resize(tex.?.width, baseline_y + tex.?.height);
                        var y: usize = tex.?.*.height - 1;
                        while (y >= @as(u32, @bitCast(baseline_y))) : (y -= 1) {
                            for (0..tex.?.*.width) |x| {
                                const tmp = tex.?.pixel_buffer[(y - @as(u32, @bitCast(baseline_y))) * tex.?.width + x];
                                tex.?.pixel_buffer[(y - @as(u32, @bitCast(baseline_y))) * tex.?.width + x] = tex.?.pixel_buffer[y * tex.?.width + x];
                                tex.?.pixel_buffer[y * tex.?.width + x] = tmp;
                            }
                        }
                    }
                }
            } else {
                FONT_LOG.info("resizing\n", .{});
                if (character == ' ' or char_tex == null) {
                    if (char_tex == null) {
                        const default_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.ttf.font_directory.hhea.advance_width_max)) * self.scale));
                        try tex.?.resize(tex.?.width + default_width, tex.?.height);
                    } else {
                        try tex.?.resize(tex.?.width + char_tex.?.*.width, tex.?.height);
                    }
                } else {
                    const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(character);
                    const y_from_base = @as(u32, @intFromFloat(@abs(@as(f32, @floatFromInt(glyph_outline.?.y_min)) * self.scale)));
                    FONT_LOG.info("y_from_base {d}, baseline_y {d}\n", .{ y_from_base, baseline_y });
                    if (y_from_base > baseline_y) {
                        baseline_y = y_from_base;
                    }
                    const larger_height: u32 = @max(char_tex.?.height + baseline_y, tex.?.height);
                    const height_diff: i32 = @as(i32, @bitCast(larger_height)) - @as(i32, @bitCast(tex.?.height));
                    const horizontal_metrics = self.ttf.get_horizontal_metrics(@as(u16, @intCast(str[i - 1])));
                    FONT_LOG.info("kerning adjust {any}\n", .{self.ttf.kerning_adj(@as(u16, @intCast(str[i - 1])), @as(u16, @intCast(str[i])))});
                    FONT_LOG.info("x_max {d}, metrics {any}\n", .{ glyph_outline.?.x_max, horizontal_metrics });
                    var width_adjust = @as(i32, @intFromFloat(@as(f32, @floatFromInt(@as(i16, @bitCast(horizontal_metrics.advance_width)) - horizontal_metrics.lsb - (glyph_outline.?.x_max))) * self.scale));
                    //const x_adj = width_adjust;
                    FONT_LOG.info("width adjust {d}\n", .{width_adjust});
                    if (width_adjust < 0) width_adjust = 1;
                    try tex.?.resize(tex.?.width + char_tex.?.*.width + @as(u32, @bitCast(width_adjust)), larger_height);
                    if (height_diff > 0) {
                        var y: usize = tex.?.*.height - 1;
                        while (y >= @as(u32, @bitCast(height_diff))) : (y -= 1) {
                            for (0..tex.?.*.width) |x| {
                                const tmp = tex.?.pixel_buffer[(y - @as(u32, @bitCast(height_diff))) * tex.?.width + x];
                                tex.?.pixel_buffer[(y - @as(u32, @bitCast(height_diff))) * tex.?.width + x] = tex.?.pixel_buffer[y * tex.?.width + x];
                                tex.?.pixel_buffer[y * tex.?.width + x] = tmp;
                            }
                        }
                    }
                    //const y_adj = if (char_tex.?.*.height < tex.?.height) tex.?.height - char_tex.?.*.height else 0;
                    for (0..char_tex.?.*.height) |y| {
                        for (0..char_tex.?.*.width) |x| {
                            //FONT_LOG.info("y {d} - baseline_y {d} + tex.?.height {d} - char_tex.?.*.height {d}\n", .{ y, baseline_y, tex.?.height, char_tex.?.*.height });
                            //FONT_LOG.info("final {d}\n", .{(y + tex.?.height - baseline_y - char_tex.?.*.height) * tex.?.width + (x + (tex.?.width - char_tex.?.*.width))});
                            tex.?.pixel_buffer[(y + y_from_base + tex.?.height - baseline_y - char_tex.?.*.height) * tex.?.width + (x + (tex.?.width - char_tex.?.*.width))] = char_tex.?.*.pixel_buffer[y * char_tex.?.*.width + x];
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
    fn gen_char(self: *Self, graphics: anytype, character: u8) Error!*Texture {
        const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(character);
        if (glyph_outline != null) {
            var outline: TTF.GlyphOutline = glyph_outline.?;
            const width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(outline.x_max - outline.x_min)) * self.scale));
            const height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(outline.y_max - outline.y_min)) * self.scale));
            var tex: *Texture = try self.allocator.create(Texture);
            tex.* = Texture.init(self.allocator);
            try tex.rect(width, height, 0, 0, 0, 0);

            FONT_LOG.debug("width {d}, height {d}\n", .{ width, height });
            FONT_LOG.debug("contour starts {any}\n", .{outline.end_curves});
            FONT_LOG.debug("curves {any}\n", .{outline.curves});
            var edges: std.ArrayList(Edge) = try self.gen_edges(&outline);
            FONT_LOG.debug("before sort {any}\n", .{edges.items});
            std.mem.sort(Edge, edges.items, {}, Edge.sort_y);
            FONT_LOG.debug("after sort {any}\n", .{edges.items});
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

    pub fn load(self: *Self, file_name: []const u8, font_size: u16, graphics: anytype) Error!void {
        try self.ttf.load(file_name);
        self.set_size(font_size);
        var key_iter = self.ttf.char_map.keyIterator();
        var key: ?*u8 = key_iter.next();
        while (key != null) : (key = key_iter.next()) {
            const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(key.?.*);
            if (glyph_outline != null) {
                const width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(glyph_outline.?.x_max - glyph_outline.?.x_min)) * self.scale));
                const height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(glyph_outline.?.y_max - glyph_outline.?.y_min)) * self.scale));
                if (width == 0 or height == 0) {
                    self.set_size(self.ttf.font_directory.head.lowest_rec_PPEM * 2);
                    break;
                }
            }
        }
        key_iter = self.ttf.char_map.keyIterator();
        key = key_iter.next();
        while (key != null) : (key = key_iter.next()) {
            FONT_LOG.info("generating char {any} {d}\n", .{ key.?.*, num_chars });
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
