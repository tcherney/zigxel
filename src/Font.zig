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

    //TODO generate all edges from the curves to be used for scaline intersections
    fn gen_edges(self: *Self, outline: *TTF.GlyphOutline) std.mem.Allocator.Error!std.ArrayList(Edge) {
        var edges: std.ArrayList(Edge) = std.ArrayList(Edge).init(self.allocator);
        var bezier_indx: usize = 0;
        for (0..outline.end_contours.len) |i| {
            var extra_pt: ?Point = null;
            var j: usize = bezier_indx;
            while (j < outline.end_curves[i]) : (j += 1) {
                if (extra_pt == null) {
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
                    extra_pt = Point{ .x = outline.curves[j].p2.x, .y = outline.curves[j].p2.y };
                } else {
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
            var intersections: std.ArrayList(Point) = std.ArrayList(Point).init(self.allocator);
            var edges: std.ArrayList(Edge) = try self.gen_edges(&outline);
            std.debug.print("before sort {any}\n", .{edges.items});
            std.mem.sort(Edge, edges.items, {}, Edge.lessThan);
            std.debug.print("after sort {any}\n", .{edges.items});
            var active_edges: std.ArrayList(Edge) = std.ArrayList(Edge).init(self.allocator);
            defer active_edges.deinit();
            defer edges.deinit();
            //TODO have edges now find which ones intersect then sort them and fill in between
            for (0..height) |i| {
                _ = i;
                //                 if(dy == 0) continue;

                // f32 intersection = -1;
                // if(dx == 0) {
                //     intersection = edge->p1.x;
                // } else {
                //     intersection = (scanline - edge->p1.y)*(dx/dy) + edge->p1.x;
                // }
                // for (0..height) |i| {
                //     intersections.clearRetainingCapacity();
                //     for (0..width) |j| {
                //         if (tex.pixel_buffer[i * width + j].eql(self.color)) {
                //             try intersections.append(.{
                //                 .x = @as(i32, @bitCast(@as(u32, @intCast(j)))),
                //                 .y = @as(i32, @bitCast(@as(u32, @intCast(i)))),
                //             });
                //         }
                //     }
                //     var k: usize = 0;
                //     if (intersections.items.len < 2) continue;
                //     if (i == 632) {
                //         std.debug.print("intersections {any}\n", .{intersections.items});
                //     }
                //     while (k < intersections.items.len) {
                //         var p0: Point = intersections.items[k];
                //         while ((k + 1 != intersections.items.len) and intersections.items[k + 1].x == p0.x) {
                //             p0 = intersections.items[k + 1];
                //             k += 1;
                //         }
                //         if (k == intersections.items.len - 1) {
                //             graphics.draw_line(self.color, intersections.items[k - 1], p0, tex.*);
                //             k += 1;
                //         } else {
                //             graphics.draw_line(self.color, p0, intersections.items[k + 1], tex.*);
                //             k += 2;
                //         }
                //     }
                // }
                // var in_bounds = false;
                // var start_point: Point = undefined;
                // var end_point: Point = undefined;
                // for (0..width) |j| {
                //     if (tex.pixel_buffer[i * width + j].eql(self.color)) {
                //         if (in_bounds) {
                //             if (@as(i32, @bitCast(@as(u32, @intCast(j)))) - 1 == start_point.x) {
                //                 start_point.x = @as(i32, @bitCast(@as(u32, @intCast(j))));
                //             } else {
                //                 end_point.x = @as(i32, @bitCast(@as(u32, @intCast(j))));
                //                 end_point.y = @as(i32, @bitCast(@as(u32, @intCast(i))));
                //                 graphics.draw_line(self.color, start_point, end_point, tex.*);
                //                 in_bounds = false;
                //             }
                //         } else {
                //             if (j >= 1 and !tex.pixel_buffer[i * width + j - 1].eql(self.color)) {
                //                 start_point.x = @as(i32, @bitCast(@as(u32, @intCast(j))));
                //                 start_point.y = @as(i32, @bitCast(@as(u32, @intCast(i))));
                //                 in_bounds = true;
                //             } else if (j == 0) {
                //                 start_point.x = @as(i32, @bitCast(@as(u32, @intCast(j))));
                //                 start_point.y = @as(i32, @bitCast(@as(u32, @intCast(i))));
                //                 in_bounds = true;
                //             }
                //         }
                //     }
                // }
            }
            intersections.deinit();
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
