const std = @import("std");
const term = @import("term");
const texture = @import("texture.zig");
const common = @import("common");
const sprite = @import("sprite.zig");
const image = @import("image");
const graphics_enums = @import("graphics_enums.zig");

//https://www.compart.com/en/unicode/U+2580
const UPPER_PX = "▀";
//const FULL_PX = "█";
const LOWER_PX = "▄";
//▀█▄
//TODO need to fix graphics assumtion about the height provided from the terminal lib
//TODO terminal lib should just give the height in rows
pub const GraphicsType = graphics_enums.GraphicsType;
pub const ColorMode = graphics_enums.ColorMode;
pub const Allocator = std.mem.Allocator;
pub const PixelType = graphics_enums.PixelType;
pub const TerminalType = graphics_enums.TerminalType;

fn MatrixStack(comptime T: GraphicsType) type {
    return struct {
        stack: std.ArrayList(Mat),
        allocator: std.mem.Allocator,
        const Mat: type = switch (T) {
            ._2d => image.Mat(3, f64),
            ._3d => image.Mat(4, f64),
        };
        const MatPoint: type = switch (T) {
            ._2d => common.Point(2, f64),
            ._3d => common.Point(3, f64),
        };
        pub const Self = @This();
        pub fn init(allocator: std.mem.Allocator) Error!Self {
            var ret = Self{
                .stack = std.ArrayList(Mat).init(allocator),
                .allocator = allocator,
            };
            try ret.stack.append(try Mat.identity());
            return ret;
        }
        pub fn deinit(self: *Self) void {
            self.stack.deinit();
        }
        // save matrix state
        pub fn push(self: *Self) Error!void {
            try self.stack.append(self.stack.getLast());
        }
        // revert to saved matrix
        pub fn pop(self: *Self) void {
            if (self.stack.items.len > 1) _ = self.stack.pop();
        }
        pub fn translate(self: *Self, p: MatPoint) Error!void {
            switch (T) {
                ._2d => {
                    self.stack.items[self.stack.items.len - 1] = self.stack.items[self.stack.items.len - 1].mul(try Mat.translate(p.x, p.y));
                },
                ._3d => unreachable,
            }
        }
        pub fn rotate(self: *Self, degrees: f64) Error!void {
            switch (T) {
                ._2d => {
                    self.stack.items[self.stack.items.len - 1] = self.stack.items[self.stack.items.len - 1].mul(try Mat.rotate(.z, degrees));
                },
                ._3d => unreachable,
            }
        }
        //TODO can probably improve this by splitting the result pixels instead of just rounding
        pub fn apply(self: *Self, p: MatPoint) MatPoint {
            switch (T) {
                ._2d => {
                    const res = self.stack.getLast().mul_v(.{ p.x, p.y, 1.0 });
                    return .{ .x = @round(res[0]), .y = @round(res[1]) };
                },
                ._3d => {
                    const res = self.stack.getLast().mul_v(.{ p.x, p.y, p.z, 1.0 });
                    return .{ .x = @round(res[0]), .y = @round(res[1]), .z = @round(res[2]) };
                },
            }
        }
    };
}

const PIXEL_RENDERER_LOG = std.log.scoped(.pixel_renderer);
//TODO add camera matrix for basic 3d support
pub const Error = error{TextureError} || term.Error || std.mem.Allocator.Error || std.fmt.BufPrintError || image.Image.Error;
pub const PixelRenderer = struct {
    ascii_based: bool = false,
    terminal: term.Term = undefined,
    pixel_buffer: []PixelType = undefined,
    last_frame: []PixelType = undefined,
    terminal_buffer: []u8 = undefined,
    text_to_render: std.ArrayList(Text) = undefined,
    allocator: std.mem.Allocator = undefined,
    first_render: bool = true,
    stack: MatrixStackType,
    pixel_width: usize,
    pixel_height: usize,
    graphics_type: GraphicsType,
    color_type: ColorMode,
    terminal_type: TerminalType,
    pub const Point = common.Point(2, i32);
    pub const Rectangle = common.Rectangle;
    pub const MatrixStackType = union(enum) {
        _2d: MatrixStack(._2d),
        _3d: MatrixStack(._3d),
        pub fn apply(self: *MatrixStackType, p: MatPoint) MatPoint {
            switch (self.*) {
                ._2d => |*stack| {
                    return .{ ._2d = stack.apply(p._2d) };
                },
                ._3d => |*stack| {
                    return .{ ._3d = stack.apply(p._3d) };
                },
            }
        }
    };
    pub const MatPoint = union(enum) {
        _2d: common.Point(2, f64),
        _3d: common.Point(3, f64),
    };

    const Self = @This();
    pub const Text = struct { x: i32, y: i32, r: u8, g: u8, b: u8, value: []const u8 };

    pub fn init(allocator: std.mem.Allocator, graphics_type: GraphicsType, color_type: ColorMode, terminal_type: TerminalType) Error!Self {
        var terminal = try term.Term.init(allocator);
        if (terminal_type == .native) try terminal.on();
        var pixel_buffer = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 4);
        for (0..pixel_buffer.len) |i| {
            if (color_type == .color_256) {
                pixel_buffer[i] = .{ .color_256 = 0 };
            } else {
                pixel_buffer[i] = .{ .color_true = .{} };
            }
        }
        var last_frame = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 4);
        for (0..last_frame.len) |i| {
            if (color_type == .color_256) {
                last_frame[i] = .{ .color_256 = 0 };
            } else {
                last_frame[i] = .{ .color_true = .{} };
            }
        }
        return Self{
            .terminal = terminal,
            .allocator = allocator,
            .pixel_buffer = pixel_buffer,
            .last_frame = last_frame,
            // need space for setting background and setting of foreground color for every pixel
            .terminal_buffer = try allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((terminal.size.height * terminal.size.width * 2) + 200)),
            .text_to_render = std.ArrayList(Text).init(allocator),
            .stack = switch (graphics_type) {
                ._2d => .{ ._2d = try MatrixStack(._2d).init(allocator) },
                ._3d => .{ ._3d = try MatrixStack(._3d).init(allocator) },
            },
            .pixel_width = terminal.size.width,
            .pixel_height = terminal.size.height * 2,
            .color_type = color_type,
            .graphics_type = graphics_type,
            .terminal_type = terminal_type,
        };
    }
    pub fn push(self: *Self) Error!void {
        switch (self.stack) {
            inline else => |*stack| try stack.push(),
        }
    }
    pub fn pop(self: *Self) void {
        switch (self.stack) {
            inline else => |*stack| stack.pop(),
        }
    }
    pub fn translate(self: *Self, p: MatPoint) Error!void {
        switch (self.stack) {
            ._2d => |*stack| {
                try stack.translate(p._2d);
            },
            ._3d => |*stack| {
                try stack.translate(p._3d);
            },
        }
    }
    pub fn rotate(self: *Self, degrees: f64) Error!void {
        switch (self.stack) {
            inline else => |*stack| try stack.rotate(degrees),
        }
    }

    pub fn size_change(self: *Self, size: term.Size) Error!void {
        self.allocator.free(self.terminal_buffer);
        self.allocator.free(self.last_frame);
        self.terminal.size = .{ .width = size.width, .height = size.height };
        self.pixel_width = size.width;
        self.pixel_height = size.height * 2;
        self.terminal_buffer = try self.allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((self.pixel_width * self.pixel_height) + 200));
        self.allocator.free(self.pixel_buffer);
        self.pixel_buffer = try self.allocator.alloc(PixelType, self.pixel_width * self.pixel_height * 2);
        for (0..self.pixel_buffer.len) |i| {
            if (self.color_type == .color_256) {
                self.pixel_buffer[i] = .{ .color_256 = 0 };
            } else {
                self.pixel_buffer[i] = .{ .color_true = .{} };
            }
        }
        self.last_frame = try self.allocator.alloc(PixelType, self.pixel_buffer.len);
        for (0..self.pixel_buffer.len) |i| {
            self.last_frame[i] = self.pixel_buffer[i];
        }
        self.first_render = true;
    }

    pub fn deinit(self: *Self) Error!void {
        self.allocator.free(self.pixel_buffer);
        self.allocator.free(self.terminal_buffer);
        if (self.terminal_type == .native) try self.terminal.off();
        self.allocator.free(self.last_frame);
        self.text_to_render.deinit();
        switch (self.stack) {
            inline else => |*stack| stack.deinit(),
        }
    }

    pub fn set_bg(self: *Self, r: u8, g: u8, b: u8, dest: ?texture.Texture) void {
        if (dest == null) {
            const bg_color_indx = term.rgb_256(r, g, b);
            for (0..self.pixel_buffer.len) |i| {
                if (self.color_type == .color_256) {
                    self.pixel_buffer[i].color_256 = bg_color_indx;
                } else {
                    self.pixel_buffer[i].color_true = .{ .r = r, .g = g, .b = b };
                }
            }
        } else {
            if (self.color_type == .color_256) {
                const bg_color_indx = term.rgb_256(r, g, b);
                for (0..dest.?.pixel_buffer.len) |i| {
                    dest.?.pixel_buffer[i].set_r(bg_color_indx);
                }
            } else {
                for (0..dest.?.pixel_buffer.len) |i| {
                    dest.?.pixel_buffer[i].set_r(r);
                    dest.?.pixel_buffer[i].set_g(g);
                    dest.?.pixel_buffer[i].set_b(b);
                    dest.?.pixel_buffer[i].set_a(255);
                }
            }
        }
    }

    pub fn draw_line(self: *Self, color: texture.Pixel, p0: Point, p1: Point, dest: ?texture.Texture) void {
        if (@abs(p1.y - p0.y) > @abs(p1.x - p0.x)) {
            const p_start = if (p1.y > p0.y) p0 else p1;
            const p_end = if (p1.y > p0.y) p1 else p0;
            var y = p_start.y + 1;
            self.draw_pixel(p_start.x, p_start.y, color, dest);
            while (y < p_end.y) : (y += 1) {
                const x = @divFloor((p_start.x * (p_end.y - y) + p_end.x * (y - p_start.y)), (p_end.y - p_start.y));
                self.draw_pixel(x, y, color, dest);
            }
            self.draw_pixel(p_end.x, p_end.y, color, dest);
        } else {
            const p_start = if (p1.x > p0.x) p0 else p1;
            const p_end = if (p1.x > p0.x) p1 else p0;
            var x = p_start.x + 1;
            self.draw_pixel(p_start.x, p_start.y, color, dest);
            while (x < p_end.x) : (x += 1) {
                const y = @divFloor((p_start.y * (p_end.x - x) + p_end.y * (x - p_start.x)), (p_end.x - p_start.x));
                self.draw_pixel(x, y, color, dest);
            }
            self.draw_pixel(p_end.x, p_end.y, color, dest);
        }
    }

    pub fn draw_bezier(self: *Self, color: texture.Pixel, p0: Point, p1: Point, p2: Point, dest: ?texture.Texture) void {
        const subdiv_into: i32 = 5;
        const step_per_iter: f32 = 1.0 / @as(f32, @floatFromInt(subdiv_into));
        var prev: Point = Point{ .x = p0.x, .y = p0.y };
        var curr: Point = undefined;
        for (0..subdiv_into + 1) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) * step_per_iter;
            const t1: f32 = 1.0 - t;
            const t2: f32 = t * t;
            const x = t1 * t1 * @as(f32, @floatFromInt(p0.x)) + 2 * t1 * t * @as(f32, @floatFromInt(p1.x)) + t2 * @as(f32, @floatFromInt(p2.x));
            const y = t1 * t1 * @as(f32, @floatFromInt(p0.y)) + 2 * t1 * t * @as(f32, @floatFromInt(p1.y)) + t2 * @as(f32, @floatFromInt(p2.y));
            curr.x = @as(i32, @intFromFloat(x));
            curr.y = @as(i32, @intFromFloat(y));
            self.draw_line(color, prev, curr, dest);
            prev.x = curr.x;
            prev.y = curr.y;
        }
    }

    pub fn draw_pixel_bg(self: *Self, x: i32, y: i32, p: texture.Pixel, dest: ?texture.Texture, bgr: u8, bgg: u8, bgb: u8, custom_bg: bool) void {
        if (dest == null) {
            const res_point = self.stack.apply(.{ ._2d = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) } })._2d;
            if (res_point.x < 0 or res_point.x >= @as(f64, @floatFromInt(self.pixel_width)) or res_point.y >= @as(f64, @floatFromInt(self.pixel_height)) or res_point.y < 0) {
                return;
            }
            const x_indx: usize = @intFromFloat(res_point.x);
            const y_indx: usize = @intFromFloat(res_point.y);
            if (p.get_a() != 255) {
                const max_pixel = 255.0;
                var end_color: @Vector(4, f32) = .{ @as(f32, @floatFromInt(p.get_r())), @as(f32, @floatFromInt(p.get_g())), @as(f32, @floatFromInt(p.get_b())), @as(f32, @floatFromInt(p.get_a())) };
                end_color *= @as(@Vector(4, f32), @splat((@as(f32, @floatFromInt(p.get_a())) / max_pixel)));
                if (custom_bg) {
                    const bkgd_vec: @Vector(4, f32) = @Vector(4, f32){ @as(f32, @floatFromInt(bgr)), @as(f32, @floatFromInt(bgg)), @as(f32, @floatFromInt(bgb)), @as(f32, @floatFromInt(p.get_a())) };
                    end_color += @as(@Vector(4, f32), @splat((1 - (@as(f32, @floatFromInt(p.get_a())) / max_pixel)))) * bkgd_vec;
                } else {
                    const bkgd = self.pixel_buffer[y_indx * self.pixel_width + x_indx];
                    const bkgd_vec: @Vector(4, f32) = @Vector(4, f32){ @as(f32, @floatFromInt(bkgd.color_true.r)), @as(f32, @floatFromInt(bkgd.color_true.g)), @as(f32, @floatFromInt(bkgd.color_true.b)), 255.0 };
                    end_color += @as(@Vector(4, f32), @splat((1 - (@as(f32, @floatFromInt(p.get_a())) / max_pixel)))) * bkgd_vec;
                }
                self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.r = @as(u8, @intFromFloat(end_color[0]));
                self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.g = @as(u8, @intFromFloat(end_color[1]));
                self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.b = @as(u8, @intFromFloat(end_color[2]));
            } else {
                self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.r = p.get_r();
                self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.g = p.get_g();
                self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.b = p.get_b();
            }
        } else {
            const res_point = self.stack.apply(.{ ._2d = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) } })._2d;
            if (res_point.x < 0 or res_point.x >= @as(f64, @floatFromInt(dest.?.width)) or res_point.y >= @as(f64, @floatFromInt(dest.?.height)) or res_point.y < 0) {
                return;
            }
            const x_indx: usize = @intFromFloat(res_point.x);
            const y_indx: usize = @intFromFloat(res_point.y);
            if (p.get_a() != 255) {
                const max_pixel = 255.0;
                var end_color: @Vector(4, f32) = .{ @as(f32, @floatFromInt(p.get_r())), @as(f32, @floatFromInt(p.get_g())), @as(f32, @floatFromInt(p.get_b())), @as(f32, @floatFromInt(p.get_a())) };
                end_color *= @as(@Vector(4, f32), @splat((@as(f32, @floatFromInt(p.get_a())) / max_pixel)));
                if (custom_bg) {
                    const bkgd_vec: @Vector(4, f32) = @Vector(4, f32){ @as(f32, @floatFromInt(bgr)), @as(f32, @floatFromInt(bgg)), @as(f32, @floatFromInt(bgb)), @as(f32, @floatFromInt(p.get_a())) };
                    end_color += @as(@Vector(4, f32), @splat((1 - (@as(f32, @floatFromInt(p.get_a())) / max_pixel)))) * bkgd_vec;
                } else {
                    const bkgd = dest.?.pixel_buffer[y_indx * dest.?.width + x_indx];
                    const bkgd_vec: @Vector(4, f32) = @Vector(4, f32){ @as(f32, @floatFromInt(bkgd.get_r())), @as(f32, @floatFromInt(bkgd.get_g())), @as(f32, @floatFromInt(bkgd.get_b())), @as(f32, @floatFromInt(bkgd.get_a())) };
                    end_color += @as(@Vector(4, f32), @splat((1 - (@as(f32, @floatFromInt(p.get_a())) / max_pixel)))) * bkgd_vec;
                }
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_r(@as(u8, @intFromFloat(end_color[0])));
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_g(@as(u8, @intFromFloat(end_color[1])));
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_b(@as(u8, @intFromFloat(end_color[2])));
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_a(p.get_a());
            } else {
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].v = p.v;
            }
        }
    }

    pub fn draw_pixel(self: *Self, x: i32, y: i32, p: texture.Pixel, dest: ?texture.Texture) void {
        self.draw_pixel_bg(x, y, p, dest, 0, 0, 0, false);
    }

    pub fn draw_sprite(self: *Self, s: sprite.Sprite, dest: ?texture.Texture) Error!void {
        if (s.scaled_buffer == null) {
            try self.draw_pixel_buffer(s.tex.pixel_buffer, s.tex.width, s.tex.height, s.src, s.dest, dest);
        } else {
            PIXEL_RENDERER_LOG.debug("rendering scaled\n", .{});
            const src_rect = Rectangle{ .x = 0, .y = 0, .width = s.dest.width, .height = s.dest.height };
            try self.draw_pixel_buffer(s.scaled_buffer.?, s.dest.width, s.dest.height, src_rect, s.dest, dest);
        }
    }

    pub fn draw_pixel_buffer(self: *Self, pixel_buffer: []texture.Pixel, width: u32, height: u32, src: Rectangle, dest_rect: Rectangle, dest: ?texture.Texture) Error!void {
        var tex_indx: usize = (@as(u32, @bitCast(src.y)) * width + @as(u32, @bitCast(src.x)));
        if (src.height > height or src.width > width) {
            return Error.TextureError;
        }
        //const height_i: i32 = @as(i32, @bitCast(tex.height));
        const width_i: i32 = @as(i32, @bitCast(width));
        const src_height_i: i32 = @as(i32, @bitCast(src.height));
        const src_width_i: i32 = @as(i32, @bitCast(src.width));
        PIXEL_RENDERER_LOG.debug("{d} {d}\n", .{ width_i, src_width_i });
        var j: i32 = dest_rect.y;
        if (dest == null) {
            while (j < (dest_rect.y + src_height_i)) : (j += 1) {
                if (j < 0) {
                    tex_indx += width;
                    continue;
                } else if (j >= self.pixel_height) {
                    break;
                }
                var i: i32 = dest_rect.x;
                while (i < (dest_rect.x + src_width_i) and tex_indx < pixel_buffer.len) : (i += 1) {
                    const res_point = self.stack.apply(.{ ._2d = .{ .x = @floatFromInt(i), .y = @floatFromInt(j) } })._2d;
                    if (res_point.x < 0) {
                        tex_indx += 1;
                        continue;
                    } else if (res_point.x >= @as(f64, @floatFromInt(self.pixel_width))) {
                        tex_indx += @as(usize, @intCast(@as(u32, @bitCast((dest_rect.x + width_i) - i))));
                        break;
                    }
                    const i_usize: usize = @intFromFloat(res_point.x);
                    const j_usize: usize = @intFromFloat(res_point.y);
                    // have alpha channel
                    var r: u8 = pixel_buffer[tex_indx].get_r();
                    var g: u8 = pixel_buffer[tex_indx].get_g();
                    var b: u8 = pixel_buffer[tex_indx].get_b();
                    if (pixel_buffer[tex_indx].get_a() != 255) {
                        const max_pixel = 255.0;
                        const bkgd = self.pixel_buffer[j_usize * self.pixel_width + i_usize];
                        var end_color: @Vector(4, f32) = .{ @as(f32, @floatFromInt(r)), @as(f32, @floatFromInt(g)), @as(f32, @floatFromInt(b)), @as(f32, @floatFromInt(pixel_buffer[tex_indx].get_a())) };
                        end_color *= @as(@Vector(4, f32), @splat((@as(f32, @floatFromInt(pixel_buffer[tex_indx].get_a())) / max_pixel)));
                        const bkgd_vec: @Vector(4, f32) = @Vector(4, f32){ @as(f32, @floatFromInt(bkgd.color_true.r)), @as(f32, @floatFromInt(bkgd.color_true.g)), @as(f32, @floatFromInt(bkgd.color_true.b)), 255.0 };
                        end_color += @as(@Vector(4, f32), @splat((1 - (@as(f32, @floatFromInt(pixel_buffer[tex_indx].get_a())) / max_pixel)))) * bkgd_vec;
                        r = @as(u8, @intFromFloat(end_color[0]));
                        g = @as(u8, @intFromFloat(end_color[1]));
                        b = @as(u8, @intFromFloat(end_color[2]));
                    }

                    switch (self.color_type) {
                        .color_256 => {
                            self.pixel_buffer[j_usize * self.pixel_width + i_usize].color_256 = term.rgb_256(r, g, b);
                        },
                        .color_true => {
                            self.pixel_buffer[j_usize * self.pixel_width + i_usize].color_true.r = r;
                            self.pixel_buffer[j_usize * self.pixel_width + i_usize].color_true.g = g;
                            self.pixel_buffer[j_usize * self.pixel_width + i_usize].color_true.b = b;
                        },
                    }

                    tex_indx += 1;
                }
                tex_indx += width - src.width;
            }
        } else {
            while (j < (dest_rect.y + src_height_i)) : (j += 1) {
                if (j < 0) {
                    tex_indx += width;
                    continue;
                } else if (j >= dest.?.height) {
                    break;
                }
                var i: i32 = dest_rect.x;
                while (i < (dest_rect.x + src_width_i) and tex_indx < pixel_buffer.len) : (i += 1) {
                    const res_point = self.stack.apply(.{ ._2d = .{ .x = @floatFromInt(i), .y = @floatFromInt(j) } })._2d;
                    if (res_point.x < 0) {
                        tex_indx += 1;
                        continue;
                    } else if (res_point.x >= @as(f64, @floatFromInt(dest.?.width))) {
                        tex_indx += @as(usize, @intCast(@as(u32, @bitCast((dest_rect.x + width_i) - i))));
                        break;
                    }
                    const i_usize: usize = @intFromFloat(res_point.x);
                    const j_usize: usize = @intFromFloat(res_point.y);
                    // have alpha channel
                    var r: u8 = pixel_buffer[tex_indx].get_r();
                    var g: u8 = pixel_buffer[tex_indx].get_g();
                    var b: u8 = pixel_buffer[tex_indx].get_b();
                    if (pixel_buffer[tex_indx].get_a() != 255) {
                        const max_pixel = 255.0;
                        const bkgd = dest.?.pixel_buffer[j_usize * dest.?.width + i_usize];
                        var end_color: @Vector(4, f32) = .{ @as(f32, @floatFromInt(r)), @as(f32, @floatFromInt(g)), @as(f32, @floatFromInt(b)), @as(f32, @floatFromInt(pixel_buffer[tex_indx].get_a())) };
                        end_color *= @as(@Vector(4, f32), @splat((@as(f32, @floatFromInt(pixel_buffer[tex_indx].get_a())) / max_pixel)));
                        const bkgd_vec: @Vector(4, f32) = @Vector(4, f32){ @as(f32, @floatFromInt(bkgd.get_r())), @as(f32, @floatFromInt(bkgd.get_g())), @as(f32, @floatFromInt(bkgd.get_b())), @as(f32, @floatFromInt(bkgd.get_a())) };
                        end_color += @as(@Vector(4, f32), @splat((1 - (@as(f32, @floatFromInt(pixel_buffer[tex_indx].get_a())) / max_pixel)))) * bkgd_vec;
                        r = @as(u8, @intFromFloat(end_color[0]));
                        g = @as(u8, @intFromFloat(end_color[1]));
                        b = @as(u8, @intFromFloat(end_color[2]));
                    }

                    switch (self.color_type) {
                        .color_256 => {
                            dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_r(term.rgb_256(r, g, b));
                        },
                        .color_true => {
                            dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_r(r);
                            dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_g(g);
                            dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_b(b);
                            dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_a(pixel_buffer[tex_indx].get_a());
                        },
                    }

                    tex_indx += 1;
                }
                tex_indx += width - src.width;
            }
        }
    }

    pub fn draw_texture(self: *Self, tex: texture.Texture, src_rect: Rectangle, dest_rect: Rectangle, dest: ?texture.Texture) Error!void {
        try self.draw_pixel_buffer(tex.pixel_buffer, tex.width, tex.height, src_rect, dest_rect, dest);
    }

    pub fn draw_rect(self: *Self, x: usize, y: usize, w: usize, h: usize, r: u8, g: u8, b: u8, dest: ?texture.Texture) void {
        if (dest == null) {
            const color_indx = term.rgb_256(r, g, b);
            for (y..y + h) |j| {
                for (x..x + w) |i| {
                    const res_point = self.stack.apply(.{ ._2d = .{ .x = @floatFromInt(i), .y = @floatFromInt(j) } })._2d;
                    if (res_point.x < 0 or res_point.x >= @as(f64, @floatFromInt(self.pixel_width)) or res_point.y >= @as(f64, @floatFromInt(self.pixel_height)) or res_point.y < 0) {
                        continue;
                    }
                    const x_indx: usize = @intFromFloat(res_point.x);
                    const y_indx: usize = @intFromFloat(res_point.y);
                    switch (self.color_type) {
                        .color_256 => {
                            self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_256 = color_indx;
                        },
                        .color_true => {
                            self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.r = r;
                            self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.g = g;
                            self.pixel_buffer[y_indx * self.pixel_width + x_indx].color_true.b = b;
                        },
                    }
                }
            }
        } else {
            const color_indx = term.rgb_256(r, g, b);
            for (y..y + h) |j| {
                for (x..x + w) |i| {
                    const res_point = self.stack.apply(.{ ._2d = .{ .x = @floatFromInt(i), .y = @floatFromInt(j) } })._2d;
                    if (res_point.x < 0 or res_point.x >= @as(f64, @floatFromInt(dest.?.width)) or res_point.y >= @as(f64, @floatFromInt(dest.?.height)) or res_point.y < 0) {
                        continue;
                    }
                    const x_indx: usize = @intFromFloat(res_point.x);
                    const y_indx: usize = @intFromFloat(res_point.y);
                    switch (self.color_type) {
                        .color_256 => {
                            dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_r(color_indx);
                        },
                        .color_true => {
                            dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_r(r);
                            dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_g(g);
                            dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_b(b);
                        },
                    }
                }
            }
        }
    }

    pub fn draw_text(self: *Self, value: []const u8, x: i32, y: i32, r: u8, g: u8, b: u8) Error!void {
        //GRAPHICS_LOG.debug("{s} with len {d}\n", .{ value, value.len });
        std.debug.print("drawing {any}\n", .{value});
        try self.text_to_render.append(Text{ .x = x, .y = if (@mod(y, 2) == 1) y - 1 else y, .r = r, .g = g, .b = b, .value = value });
    }

    //TODO scaling pass based on difference between render size and user window, can scale everything up to meet their resolution
    pub fn flip(self: *Self, dest: ?texture.Texture, bounds: ?Rectangle) Error!void {
        if (dest != null and bounds != null) {
            if (bounds.?.width > @as(u32, @intCast(self.pixel_width)) or bounds.?.height > @as(u32, @intCast(self.pixel_height))) {
                return Error.TextureError;
            } else {
                var y: usize = @as(usize, @intCast(@as(u32, @bitCast(bounds.?.y))));
                var buffer_indx: usize = 0;
                const y_bound = bounds.?.height + y;
                var x: usize = @as(usize, @intCast(@as(u32, @bitCast(bounds.?.x))));
                const x_bound = bounds.?.width + x;
                while (y < y_bound) : (y += 1) {
                    x = @as(usize, @intCast(@as(u32, @bitCast(bounds.?.x))));
                    while (x < x_bound) : (x += 1) {
                        if (self.color_type == .color_256) {
                            self.pixel_buffer[buffer_indx].color_256 = dest.?.pixel_buffer[y * dest.?.width + x].get_r();
                        } else {
                            self.pixel_buffer[buffer_indx].color_true.r = dest.?.pixel_buffer[y * dest.?.width + x].get_r();
                            self.pixel_buffer[buffer_indx].color_true.g = dest.?.pixel_buffer[y * dest.?.width + x].get_g();
                            self.pixel_buffer[buffer_indx].color_true.b = dest.?.pixel_buffer[y * dest.?.width + x].get_b();
                        }
                        buffer_indx += 1;
                    }
                }
            }
        }
        var buffer_len: usize = 0;
        //std.debug.print("pixels {any}\n", .{self.pixel_buffer});
        var j: usize = 0;
        var i: usize = 0;
        const width = self.pixel_width;
        const height = self.pixel_height;
        var prev_fg_pixel: PixelType = self.pixel_buffer[j * width + i];
        var prev_bg_pixel: PixelType = self.pixel_buffer[(j + 1) * width + i];
        var dirty_pixel_buffer: [48]u8 = undefined;
        if (self.color_type == .color_256) {
            for (term.FG[prev_fg_pixel.color_256]) |c| {
                self.terminal_buffer[buffer_len] = c;
                buffer_len += 1;
            }
            for (term.BG[prev_bg_pixel.color_256]) |c| {
                self.terminal_buffer[buffer_len] = c;
                buffer_len += 1;
            }
        } else {
            for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ prev_fg_pixel.color_true.r, prev_fg_pixel.color_true.g, prev_fg_pixel.color_true.b })) |c| {
                self.terminal_buffer[buffer_len] = c;
                buffer_len += 1;
            }

            for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ prev_bg_pixel.color_true.r, prev_bg_pixel.color_true.g, prev_bg_pixel.color_true.b })) |c| {
                self.terminal_buffer[buffer_len] = c;
                buffer_len += 1;
            }
        }

        if (self.first_render) {
            PIXEL_RENDERER_LOG.debug("first render\n", .{});
            try self.terminal.out(term.CURSOR_HOME);
        }
        //GRAPHICS_LOG.debug("width height {d} {d}\n", .{ width, height });
        // each pixel is an index into the possible 256 colors
        while (j < height) : (j += 2) {
            i = 0;
            while (i < width) : (i += 1) {
                const fg_pixel = self.pixel_buffer[j * width + i];
                const bg_pixel = self.pixel_buffer[(j + 1) * width + i];
                const last_fg_pixel = self.last_frame[j * width + i];
                const last_bg_pixel = self.last_frame[(j + 1) * width + i];
                if (!self.first_render) {
                    switch (self.color_type) {
                        .color_256 => {
                            if (fg_pixel.eql(last_fg_pixel) and bg_pixel.eql(last_bg_pixel)) {
                                continue;
                            }
                            self.last_frame[j * width + i] = fg_pixel;
                            self.last_frame[(j + 1) * width + i] = bg_pixel;
                        },
                        .color_true => {
                            if (fg_pixel.eql(last_fg_pixel) and bg_pixel.eql(last_bg_pixel)) {
                                continue;
                            }
                            self.last_frame[j * width + i].color_true.r = fg_pixel.color_true.r;
                            self.last_frame[j * width + i].color_true.g = fg_pixel.color_true.g;
                            self.last_frame[j * width + i].color_true.b = fg_pixel.color_true.b;
                            self.last_frame[(j + 1) * width + i].color_true.r = bg_pixel.color_true.r;
                            self.last_frame[(j + 1) * width + i].color_true.g = bg_pixel.color_true.g;
                            self.last_frame[(j + 1) * width + i].color_true.b = bg_pixel.color_true.b;
                        },
                    }

                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ (j / 2) + 1, i + 1 })) |c| {
                        self.terminal_buffer[buffer_len] = c;
                        buffer_len += 1;
                    }
                }

                switch (self.color_type) {
                    .color_256 => {
                        if (bg_pixel.eql(prev_fg_pixel) and fg_pixel.eql(prev_bg_pixel) and !fg_pixel.eql(bg_pixel)) {
                            for (LOWER_PX) |c| {
                                self.terminal_buffer[buffer_len] = c;
                                buffer_len += 1;
                            }
                        } else {
                            if (!prev_fg_pixel.eql(fg_pixel)) {
                                prev_fg_pixel.color_256 = fg_pixel.color_256;
                                for (term.FG[fg_pixel.color_256]) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }
                            if (!prev_bg_pixel.eql(bg_pixel)) {
                                prev_bg_pixel.color_256 = bg_pixel.color_256;
                                for (term.BG[bg_pixel.color_256]) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }

                            if (fg_pixel.eql(bg_pixel)) {
                                self.terminal_buffer[buffer_len] = ' ';
                                buffer_len += 1;
                            } else {
                                for (UPPER_PX) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }
                        }
                    },
                    .color_true => {
                        if (bg_pixel.eql(prev_fg_pixel) and fg_pixel.eql(prev_bg_pixel) and !fg_pixel.eql(bg_pixel)) {
                            for (LOWER_PX) |c| {
                                self.terminal_buffer[buffer_len] = c;
                                buffer_len += 1;
                            }
                        } else {
                            if (!prev_fg_pixel.eql(fg_pixel)) {
                                prev_fg_pixel.color_true.r = fg_pixel.color_true.r;
                                prev_fg_pixel.color_true.g = fg_pixel.color_true.g;
                                prev_fg_pixel.color_true.b = fg_pixel.color_true.b;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ fg_pixel.color_true.r, fg_pixel.color_true.g, fg_pixel.color_true.b })) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }
                            if (!prev_bg_pixel.eql(bg_pixel)) {
                                prev_bg_pixel.color_true.r = bg_pixel.color_true.r;
                                prev_bg_pixel.color_true.g = bg_pixel.color_true.g;
                                prev_bg_pixel.color_true.b = bg_pixel.color_true.b;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ bg_pixel.color_true.r, bg_pixel.color_true.g, bg_pixel.color_true.b })) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }

                            if (fg_pixel.eql(bg_pixel)) {
                                self.terminal_buffer[buffer_len] = ' ';
                                buffer_len += 1;
                            } else {
                                for (UPPER_PX) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }
                        }
                    },
                }
            }
        }
        //std.debug.print("pretext {s}\n", .{self.terminal_buffer[0..buffer_len]});
        if (self.text_to_render.items.len > 0) {
            var text = self.text_to_render.pop();
            while (text) |t| {
                if (t.y >= 0 and t.y < self.pixel_height) {
                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ @divFloor(t.y, 2) + 1, t.x + 1 })) |c| {
                        self.terminal_buffer[buffer_len] = c;
                        buffer_len += 1;
                    }

                    switch (self.color_type) {
                        .color_256 => {
                            const fg_pixel: PixelType = .{ .color_256 = term.rgb_256(t.r, t.g, t.b) };

                            if (!prev_fg_pixel.eql(fg_pixel)) {
                                prev_fg_pixel = fg_pixel;
                                for (term.FG[fg_pixel.color_256]) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }

                            for (t.value, 0..) |c, z| {
                                const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                                if (!prev_bg_pixel.eql(bg_pixel)) {
                                    prev_bg_pixel = bg_pixel;
                                    for (term.BG[bg_pixel.color_256]) |ci| {
                                        self.terminal_buffer[buffer_len] = ci;
                                        buffer_len += 1;
                                    }
                                }
                                self.terminal_buffer[buffer_len] = c;
                                buffer_len += 1;
                            }
                        },
                        .color_true => {
                            if (prev_fg_pixel.color_true.r != t.r or prev_fg_pixel.color_true.g != t.g or prev_fg_pixel.color_true.b != t.b) {
                                prev_fg_pixel.color_true.r = t.r;
                                prev_fg_pixel.color_true.g = t.g;
                                prev_fg_pixel.color_true.b = t.b;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ t.r, t.g, t.b })) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            }
                            for (t.value, 0..) |c, z| {
                                const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                                if (!prev_bg_pixel.eql(bg_pixel)) {
                                    prev_bg_pixel.color_true.r = bg_pixel.color_true.r;
                                    prev_bg_pixel.color_true.g = bg_pixel.color_true.g;
                                    prev_bg_pixel.color_true.b = bg_pixel.color_true.b;
                                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ bg_pixel.color_true.r, bg_pixel.color_true.g, bg_pixel.color_true.b })) |ci| {
                                        self.terminal_buffer[buffer_len] = ci;
                                        buffer_len += 1;
                                    }
                                }
                                self.terminal_buffer[buffer_len] = c;
                                buffer_len += 1;
                            }
                        },
                    }
                }
                text = self.text_to_render.pop();
            }
        }
        self.first_render = false;
        if (buffer_len > 0) {
            try self.terminal.out(self.terminal_buffer[0..buffer_len]);
            try self.terminal.out(term.COLOR_RESET);
            try self.terminal.out(term.CURSOR_HIDE);
            if (self.terminal_type == .wasm) try self.terminal.out("\n");
        }
    }
};
