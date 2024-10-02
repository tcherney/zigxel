const std = @import("std");
const _ttf = @import("ttf.zig");
const _texture = @import("texture.zig");
const utils = @import("utils.zig");

pub const Point = utils.Point(i32);
pub const TTF = _ttf.TTF;
pub const Texture = _texture.Texture;
pub const Pixel = _texture.Pixel;

pub const Font = struct {
    ttf: TTF = undefined,
    allocator: std.mem.Allocator,
    color: Pixel,
    const Edge = struct {
        p0: Point,
        p1: Point,
        pub fn lessThan(_: void, lhs: Edge, rhs: Edge) bool {
            const lhs_y_min = @min(lhs.p0.y, lhs.p1.y);
            const rhs_y_min = @min(rhs.p0.y, rhs.p1.y);
            if (lhs_y_min == rhs_y_min) {
                const lhs_x_min = @min(lhs.p0.x, lhs.p1.x);
                const rhs_x_min = @min(rhs.p0.x, rhs.p1.x);
                return lhs_x_min < rhs_x_min;
            }
            return lhs_y_min < rhs_y_min;
        }
    };
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .ttf = TTF.init(allocator),
            .allocator = allocator,
            .color = .{ .r = 255, .g = 255, .b = 255 },
        };
    }

    //TODO subdivide the curves by 2-4x to lower the error of the edges
    fn gen_edges(self: *Self, outline: *TTF.GlyphOutline) std.mem.Allocator.Error!std.ArrayList(Edge) {
        var edges: std.ArrayList(Edge) = std.ArrayList(Edge).init(self.allocator);
        var bezier_indx: usize = 0;
        for (0..outline.end_contours.len) |i| {
            var extra_pt: ?TTF.Point = null;
            var j: usize = bezier_indx;
            while (j < outline.end_curves[i]) : (j += 1) {
                if (extra_pt == null) {
                    if (!TTF.Point.eql(outline.curves[j].p0, outline.curves[j].p1))
                        try edges.append(Edge{
                            .p0 = .{
                                .x = outline.curves[j].p0.x,
                                .y = outline.curves[j].p0.y,
                            },
                            .p1 = .{
                                .x = outline.curves[j].p1.x,
                                .y = outline.curves[j].p1.y,
                            },
                        });
                    if (!TTF.Point.eql(outline.curves[j].p1, outline.curves[j].p2))
                        try edges.append(Edge{
                            .p0 = .{
                                .x = outline.curves[j].p1.x,
                                .y = outline.curves[j].p1.y,
                            },
                            .p1 = .{
                                .x = outline.curves[j].p2.x,
                                .y = outline.curves[j].p2.y,
                            },
                        });
                    extra_pt = TTF.Point{ .x = outline.curves[j].p2.x, .y = outline.curves[j].p2.y };
                } else {
                    if (!TTF.Point.eql(extra_pt.?, outline.curves[j].p0))
                        try edges.append(Edge{
                            .p0 = .{
                                .x = extra_pt.?.x,
                                .y = extra_pt.?.y,
                            },
                            .p1 = .{
                                .x = outline.curves[j].p0.x,
                                .y = outline.curves[j].p0.y,
                            },
                        });
                    if (!TTF.Point.eql(outline.curves[j].p0, outline.curves[j].p1))
                        try edges.append(Edge{
                            .p0 = .{
                                .x = outline.curves[j].p0.x,
                                .y = outline.curves[j].p0.y,
                            },
                            .p1 = .{
                                .x = outline.curves[j].p1.x,
                                .y = outline.curves[j].p1.y,
                            },
                        });
                    if (!TTF.Point.eql(outline.curves[j].p1, outline.curves[j].p2))
                        try edges.append(Edge{
                            .p0 = .{
                                .x = outline.curves[j].p1.x,
                                .y = outline.curves[j].p1.y,
                            },
                            .p1 = .{
                                .x = outline.curves[j].p2.x,
                                .y = outline.curves[j].p2.y,
                            },
                        });
                    extra_pt.?.x = outline.curves[j].p2.x;
                    extra_pt.?.y = outline.curves[j].p2.y;
                }
            }
            bezier_indx = outline.end_curves[i];
        }
        return edges;
    }

    //https://medium.com/@dillihangrae/scanline-filling-algorithm-852ad47fb0dd
    pub fn draw_char(self: *Self, graphics: anytype, character: u8) !void {
        const glyph_outline: ?TTF.GlyphOutline = self.ttf.char_map.get(character);
        if (glyph_outline != null) {
            var outline: TTF.GlyphOutline = glyph_outline.?;
            const width = @as(u32, @bitCast(@as(i32, @intCast(outline.x_max - outline.x_min + 200))));
            const height = @as(u32, @bitCast(@as(i32, @intCast(outline.y_max - outline.y_min + 200))));
            var tex: *Texture = try self.allocator.create(Texture);
            tex.* = Texture.init(self.allocator);
            try tex.rect(width, height, 0, 0, 0, 255);

            for (0..outline.curves.len) |i| {
                graphics.draw_bezier(self.color, .{ .x = @as(i32, @intCast(outline.curves[i].p0.x)), .y = @as(i32, @intCast(outline.curves[i].p0.y)) }, .{ .x = @as(i32, @intCast(outline.curves[i].p1.x)), .y = @as(i32, @intCast(outline.curves[i].p1.y)) }, .{ .x = @as(i32, @intCast(outline.curves[i].p2.x)), .y = @as(i32, @intCast(outline.curves[i].p2.y)) }, tex.*);
            }
            std.debug.print("width {d}, height {d}\n", .{ width, height });
            std.debug.print("contour starts {any} {any} {any}\n", .{ outline.end_curves, outline.curves[outline.end_curves[0]], outline.curves[outline.end_curves[0] - 1] });
            std.debug.print("curves {any}\n", .{outline.curves});
            var edges: std.ArrayList(Edge) = try self.gen_edges(&outline);
            std.debug.print("before sort {any}\n", .{edges.items});
            std.mem.sort(Edge, edges.items, {}, Edge.lessThan);
            std.debug.print("after sort {any}\n", .{edges.items});
            var intersections: std.ArrayList(i32) = std.ArrayList(i32).init(self.allocator);
            for (0..height) |i| {
                intersections.clearRetainingCapacity();
                for (edges.items) |edge| {
                    const larger_y = @max(edge.p0.y, edge.p1.y);
                    const smaller_y = @min(edge.p0.y, edge.p1.y);
                    if (@as(i32, @intCast(@as(i64, @bitCast(i)))) < smaller_y or @as(i32, @intCast(@as(i64, @bitCast(i)))) > larger_y) continue;
                    const dy: i32 = edge.p1.y - edge.p0.y;
                    const dx: i32 = edge.p1.x - edge.p0.x;
                    var intersection: i32 = undefined;
                    if (dy == 0) continue;
                    if (dx == 0) {
                        intersection = edge.p0.x;
                    } else {
                        intersection = @as(i32, @intFromFloat((@as(f32, @floatFromInt(i)) - @as(f32, @floatFromInt(edge.p0.y))) * (@as(f32, @floatFromInt(dx)) / @as(f32, @floatFromInt(dy))) + @as(f32, @floatFromInt(edge.p0.x))));
                    }
                    var dupe: bool = false;
                    for (intersections.items) |j| {
                        if (j == intersection) {
                            dupe = true;
                        }
                    }
                    if (!dupe) try intersections.append(intersection);
                }
                std.mem.sort(i32, intersections.items, {}, std.sort.asc(i32));
                std.debug.print("intersections at {d} {any}\n", .{ i, intersections.items });
                var j: usize = 0;
                while (j < intersections.items.len) {
                    if (j == intersections.items.len - 1) break;
                    if (intersections.items[j] == intersections.items[j + 1]) {
                        j += 1;
                        continue;
                    }
                    graphics.draw_line(self.color, .{ .x = intersections.items[j], .y = @as(i32, @intCast(@as(i64, @bitCast(i)))) }, .{ .x = intersections.items[j + 1], .y = @as(i32, @intCast(@as(i64, @bitCast(i)))) }, tex.*);
                    j += 2;
                }
            }
            intersections.deinit();

            for (edges.items, 0..edges.items.len) |edge, j| {
                if (j % 2 == 0) {
                    graphics.draw_line(.{ .r = 255, .g = 0, .b = 0 }, edge.p0, edge.p1, tex.*);
                } else if (j % 3 == 0) {
                    graphics.draw_line(.{ .r = 0, .g = 255, .b = 0 }, edge.p0, edge.p1, tex.*);
                } else if (j % 2 == 1) {
                    graphics.draw_line(.{ .r = 0, .g = 0, .b = 255 }, edge.p0, edge.p1, tex.*);
                }
            }
            edges.deinit();
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
