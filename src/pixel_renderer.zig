const std = @import("std");
const builtin = @import("builtin");
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
pub const RenderType = graphics_enums.RendererType;
pub const ThreadingSupport = graphics_enums.ThreadingSupport;
pub const SixelWidth = graphics_enums.SixelWidth;
pub const SixelHeight = graphics_enums.SixelHeight;

pub const terminal_type: TerminalType = if (builtin.os.tag == .emscripten or builtin.os.tag == .wasi) .wasm else .native;

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
const TerminalBuffer = std.ArrayList(u8);
//TODO add camera matrix for basic 3d support
pub const Error = error{ TextureError, SystemResources, Unexpected, PermissionDenied, Unsupported } || term.Error || std.mem.Allocator.Error || std.fmt.BufPrintError || image.Image.Error;
pub const PixelRenderer = struct {
    sixel_renderer: bool = false,
    terminal: term.Term = undefined,
    pixel_buffer: []PixelType = undefined,
    last_frame: []PixelType = undefined,
    terminal_buffer: TerminalBuffer = undefined,
    text_to_render: std.ArrayList(Text) = undefined,
    allocator: std.mem.Allocator = undefined,
    first_render: bool = true,
    stack: MatrixStackType,
    pixel_width: usize,
    pixel_height: usize,
    graphics_type: GraphicsType,
    color_type: ColorMode,
    lock: std.Thread.Mutex = undefined,
    threading_support: ThreadingSupport = .single,
    thread_to_process: usize = 0,
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

    pub fn init(allocator: std.mem.Allocator, graphics_type: GraphicsType, color_type: ColorMode, renderer_type: RenderType, threading_support: ThreadingSupport) Error!Self {
        var terminal = try term.Term.init(allocator);
        if (terminal_type == .native) try terminal.on();
        const sixel_renderer = renderer_type == .sixel;
        const pixel_width = if (sixel_renderer) terminal.size.width * SixelWidth else terminal.size.width;
        const pixel_height = if (sixel_renderer) terminal.size.height * SixelHeight * 2 else terminal.size.height * 2;
        var pixel_buffer = try allocator.alloc(PixelType, pixel_height * pixel_width * 2);
        for (0..pixel_buffer.len) |i| {
            if (color_type == .color_256) {
                pixel_buffer[i] = .{ .color_256 = 0 };
            } else {
                pixel_buffer[i] = .{ .color_true = .{} };
            }
        }
        var last_frame = try allocator.alloc(PixelType, pixel_height * pixel_width * 2);
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
            .sixel_renderer = sixel_renderer,
            // need space for setting background and setting of foreground color for every pixel
            .terminal_buffer = TerminalBuffer.init(allocator),
            .text_to_render = std.ArrayList(Text).init(allocator),
            .stack = switch (graphics_type) {
                ._2d => .{ ._2d = try MatrixStack(._2d).init(allocator) },
                ._3d => .{ ._3d = try MatrixStack(._3d).init(allocator) },
            },
            .pixel_width = pixel_width,
            .pixel_height = pixel_height,
            .color_type = color_type,
            .graphics_type = graphics_type,
            .threading_support = threading_support,
            .lock = std.Thread.Mutex{},
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
        self.allocator.free(self.last_frame);
        self.terminal.size = .{ .width = size.width, .height = size.height };
        self.pixel_width = if (self.sixel_renderer) size.width * SixelWidth else size.width;
        self.pixel_height = if (self.sixel_renderer) size.height * SixelHeight * 2 else size.height * 2;
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
        self.terminal_buffer.deinit();
        if (terminal_type == .native) try self.terminal.off();
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
    pub const Sixel = struct {
        pixels: [6]u8,
        num_pixels: usize,
        pub fn to_char(self: *Sixel, on_color: u8) u8 {
            var res: u8 = 0;
            for (0..self.num_pixels) |i| {
                if (self.pixels[i] == on_color) {
                    res |= @as(u8, @intCast(1)) << @as(u3, @intCast(i));
                }
            }
            return res + 63;
        }
    };

    //TODO look for more small ways to optimize this loop
    fn sixel_loop(self: *Self, buffer: *TerminalBuffer, i: usize, width: usize, height: usize) !void {
        var dirty_pixel_buffer: [48]u8 = undefined;
        var colors_to_process: [256]u8 = undefined;
        var color_in_image = [_]bool{false} ** 256;
        var total_colors: usize = 0;
        for (0..width) |j| {
            for (0..6) |idx| {
                if ((i + idx) < height) {
                    const indx = (i + idx) * self.pixel_width + j;
                    const pixel = self.pixel_buffer[indx];
                    self.pixel_buffer[indx].color_true.indx = term.rgb_256(pixel.color_true.r, pixel.color_true.g, pixel.color_true.b);
                    color_in_image[self.pixel_buffer[indx].color_true.indx] = true;
                }
            }
        }
        for (1..color_in_image.len) |j| {
            if (color_in_image[j]) {
                colors_to_process[total_colors] = @intCast(j);
                total_colors += 1;
            }
        }
        for (0..total_colors) |k| {
            const on_color = colors_to_process[k];
            var j: usize = 0;
            var previous_sixel: u8 = 0;
            var previous_sixel_count: usize = 0;
            var first_color: bool = true;
            const RLE_ENABLED = true;
            while (j < width) : (j += 1) {
                var pixels: [6]u8 = undefined;
                var num_pixels: usize = 0;
                for (0..6) |idx| {
                    if ((i + idx) < height) {
                        if (self.color_type == .color_256) {
                            pixels[idx] = self.pixel_buffer[(i + idx) * self.pixel_width + j].color_256;
                        } else {
                            pixels[idx] = self.pixel_buffer[(i + idx) * self.pixel_width + j].color_true.indx;
                        }
                        num_pixels += 1;
                    } else {
                        pixels[idx] = 0;
                    }
                }
                const sixel_char = to_sixel_256(pixels, num_pixels, on_color);
                if (RLE_ENABLED) {
                    if (sixel_char == previous_sixel) {
                        previous_sixel_count += 1;
                    } else {
                        if (first_color and previous_sixel_count > 0) {
                            for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_USE_COLOR, .{on_color})) |c| {
                                try add_char_terminal(buffer, c);
                            }
                            first_color = false;
                        }
                        if (previous_sixel_count > 3) {
                            var remaining = previous_sixel_count;
                            while (remaining > 0) {
                                const to_write = if (remaining > 255) 255 else remaining;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_REPEAT ++ "{c}", .{ to_write, previous_sixel })) |c| {
                                    try add_char_terminal(buffer, c);
                                }
                                // buffer[buffer_len] = previous_sixel;
                                // buffer_len += 1;
                                remaining -= to_write;
                            }
                            //buffer_len -= 1;
                        } else {
                            if (previous_sixel_count > 0) {
                                for (0..previous_sixel_count) |_| {
                                    try add_char_terminal(buffer, previous_sixel);
                                }
                            }
                        }
                        previous_sixel = sixel_char;
                        previous_sixel_count = 1;
                    }
                } else {
                    if (first_color) {
                        for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_USE_COLOR, .{on_color})) |c| {
                            try add_char_terminal(buffer, c);
                        }
                        first_color = false;
                    }
                    try add_char_terminal(buffer, sixel_char);
                }
            }
            // flush remaining
            if (RLE_ENABLED) {
                if (previous_sixel_count > 0 and previous_sixel != '?') {
                    if (first_color) {
                        for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_USE_COLOR, .{on_color})) |c| {
                            try add_char_terminal(buffer, c);
                        }
                        first_color = false;
                    }
                    if (previous_sixel_count > 3) {
                        var remaining = previous_sixel_count;
                        while (remaining > 0) {
                            const to_write = if (remaining > 255) 255 else remaining;
                            for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_REPEAT ++ "{c}", .{ to_write, previous_sixel })) |c| {
                                try add_char_terminal(buffer, c);
                            }
                            remaining -= to_write;
                        }
                    } else {
                        if (previous_sixel_count > 0) {
                            for (0..previous_sixel_count) |_| {
                                try add_char_terminal(buffer, previous_sixel);
                            }
                        }
                    }
                }
            }
            if (!first_color) {
                for (term.SIXEL_RESET_LINE) |c| {
                    try add_char_terminal(buffer, c);
                }
            }
        }
        for (term.SIXEL_NEW_LINE) |c| {
            try add_char_terminal(buffer, c);
        }
    }

    fn sixel_thread(self: *Self, start: usize, end: usize, width: usize, height: usize, thread_id: usize) Error!void {
        var thread_buffer: TerminalBuffer = undefined;
        //var dirty_pixel_buffer: [48]u8 = undefined;
        var i: usize = start;
        if (terminal_type != .wasm and self.threading_support == .multi) {
            thread_buffer = TerminalBuffer.init(self.allocator);
        }
        while (i < end) : (i += 6) {
            if (terminal_type != .wasm and self.threading_support == .multi) {
                try self.sixel_loop(&thread_buffer, i, width, height);
            } else {
                try self.sixel_loop(&self.terminal_buffer, i, width, height);
            }
        }
        // for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_CURSOR_UP, .{1})) |c| {
        //     try add_char_terminal(&thread_buffer, c);
        // }
        if (terminal_type != .wasm and self.threading_support == .multi) {
            defer thread_buffer.deinit();
            while (self.thread_to_process != thread_id) {
                // busy wait
            }
            if (self.thread_to_process == thread_id) {
                self.lock.lock();
                defer self.lock.unlock();
                for (thread_buffer.items) |c| {
                    try add_char_terminal(&self.terminal_buffer, c);
                }
                self.thread_to_process += 1;
            }
        }
    }

    //TODO https://www.digiater.nl/openvms/decus/vax90b1/krypton-nasa/all-about-sixels.text
    fn sixel_render(self: *Self, width: usize, height: usize) Error!void {
        var dirty_pixel_buffer: [48]u8 = undefined;
        try common.timer_start();
        // for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ 0, 0, 0 })) |c| {
        //     try add_char_terminal(&self.terminal_buffer, c);
        // }
        // for (term.SIXEL_POSITIONAL) |c| {
        //     try add_char_terminal(&self.terminal_buffer, c);
        // }

        for (term.SIXEL_START) |c| {
            try add_char_terminal(&self.terminal_buffer, c);
        }

        for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.SIXEL_SIZE, .{ 1, 1, height, width })) |c| {
            try add_char_terminal(&self.terminal_buffer, c);
        }

        for (0..term.MAX_COLOR) |k| {
            for (term.SIXEL_COLORS[k]) |c| {
                try add_char_terminal(&self.terminal_buffer, c);
            }
        }
        PIXEL_RENDERER_LOG.info("Sixel start time ", .{});
        _ = common.timer_end();
        try common.timer_start();
        if (terminal_type != .wasm and self.threading_support == .multi) {
            self.thread_to_process = 0;
            const thread_count: usize = @min(try std.Thread.getCpuCount() - 1, height / 6);
            const rows_per_thread: usize = (height / thread_count) - (height / thread_count) % 6;
            var threads: []std.Thread = try self.allocator.alloc(std.Thread, thread_count);
            for (0..thread_count) |t| {
                threads[t] = try std.Thread.spawn(.{}, sixel_thread, .{
                    self,
                    t * rows_per_thread,
                    if (t == thread_count - 1) height else (t + 1) * rows_per_thread,
                    width,
                    height,
                    t,
                });
            }
            for (threads) |thread| {
                thread.join();
            }
            self.allocator.free(threads);
        } else if (terminal_type == .wasm or self.threading_support == .single) {
            try self.sixel_thread(0, height, width, height, 0);
        }

        PIXEL_RENDERER_LOG.info("Sixel loop time ", .{});
        _ = common.timer_end();
        for (term.SIXEL_END) |c| {
            try add_char_terminal(&self.terminal_buffer, c);
        }
        try common.timer_start();
        if (self.terminal_buffer.items.len > 0) {
            PIXEL_RENDERER_LOG.info("\n{d} bytes for sixel, cap is {d}\n", .{ self.terminal_buffer.items.len, self.terminal_buffer.items.len });
            //PIXEL_RENDERER_LOG.info("{s}\n", .{self.terminal_buffer.items});
            try self.terminal.out(term.SCREEN_CLEAR);
            try self.terminal.out(term.CURSOR_HOME);
            try self.terminal.out(self.terminal_buffer.items);
        }
        PIXEL_RENDERER_LOG.info("Time to output buffer ", .{});
        _ = common.timer_end();
    }

    fn to_sixel(p1: PixelType, p2: PixelType, p3: PixelType, p4: PixelType, p5: PixelType, p6: PixelType, on_color: struct { r: u8, g: u8, b: u8 }) u8 {
        const ERROR_THRESHOLD: u8 = 10;
        var result: u8 = 0;
        if (p1.color_true.r >= (on_color.r - ERROR_THRESHOLD) and p1.color_true.g >= (on_color.g - ERROR_THRESHOLD) and p1.color_true.b >= (on_color.b - ERROR_THRESHOLD)) {
            result |= 0b00000001;
        }
        if (p2.color_true.r >= (on_color.r - ERROR_THRESHOLD) and p2.color_true.g >= (on_color.g - ERROR_THRESHOLD) and p2.color_true.b >= (on_color.b - ERROR_THRESHOLD)) {
            result |= 0b00000010;
        }
        if (p3.color_true.r >= (on_color.r - ERROR_THRESHOLD) and p3.color_true.g >= (on_color.g - ERROR_THRESHOLD) and p3.color_true.b >= (on_color.b - ERROR_THRESHOLD)) {
            result |= 0b00000100;
        }
        if (p4.color_true.r >= (on_color.r - ERROR_THRESHOLD) and p4.color_true.g >= (on_color.g - ERROR_THRESHOLD) and p4.color_true.b >= (on_color.b - ERROR_THRESHOLD)) {
            result |= 0b00001000;
        }
        if (p5.color_true.r >= (on_color.r - ERROR_THRESHOLD) and p5.color_true.g >= (on_color.g - ERROR_THRESHOLD) and p5.color_true.b >= (on_color.b - ERROR_THRESHOLD)) {
            result |= 0b00010000;
        }
        if (p6.color_true.r >= (on_color.r - ERROR_THRESHOLD) and p6.color_true.g >= (on_color.g - ERROR_THRESHOLD) and p6.color_true.b >= (on_color.b - ERROR_THRESHOLD)) {
            result |= 0b00100000;
        }
        return result + 63;
    }

    inline fn to_sixel_256(pixels: [6]u8, num_pixels: usize, on_color: u8) u8 {
        var res: u8 = 0;
        for (0..num_pixels) |i| {
            if (pixels[i] == on_color) {
                res |= @as(u8, @intCast(1)) << @as(u3, @intCast(i));
            }
        }
        return res + 63;
    }

    inline fn add_char_terminal(buffer: *TerminalBuffer, c: u8) !void {
        try buffer.append(c);
    }

    fn block_render(self: *Self) Error!void {
        var dirty_pixel_buffer: [48]u8 = undefined;
        //std.debug.print("pixels {any}\n", .{self.pixel_buffer});
        var j: usize = 0;
        var i: usize = 0;
        var prev_fg_pixel: PixelType = self.pixel_buffer[j * self.pixel_width + i];
        var prev_bg_pixel: PixelType = self.pixel_buffer[(j + 1) * self.pixel_width + i];
        if (self.color_type == .color_256) {
            for (term.FG[prev_fg_pixel.color_256]) |c| {
                try add_char_terminal(&self.terminal_buffer, c);
            }
            for (term.BG[prev_bg_pixel.color_256]) |c| {
                try add_char_terminal(&self.terminal_buffer, c);
            }
        } else {
            for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ prev_fg_pixel.color_true.r, prev_fg_pixel.color_true.g, prev_fg_pixel.color_true.b })) |c| {
                try add_char_terminal(&self.terminal_buffer, c);
            }

            for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ prev_bg_pixel.color_true.r, prev_bg_pixel.color_true.g, prev_bg_pixel.color_true.b })) |c| {
                try add_char_terminal(&self.terminal_buffer, c);
            }
        }

        if (self.first_render) {
            PIXEL_RENDERER_LOG.debug("first render\n", .{});
            try self.terminal.out(term.CURSOR_HOME);
        }
        //GRAPHICS_LOG.debug("width height {d} {d}\n", .{ width, height });
        // each pixel is an index into the possible 256 colors
        while (j < self.pixel_height) : (j += 2) {
            i = 0;
            while (i < self.pixel_width) : (i += 1) {
                const fg_pixel = self.pixel_buffer[j * self.pixel_width + i];
                const bg_pixel = self.pixel_buffer[(j + 1) * self.pixel_width + i];
                const last_fg_pixel = self.last_frame[j * self.pixel_width + i];
                const last_bg_pixel = self.last_frame[(j + 1) * self.pixel_width + i];
                if (!self.first_render) {
                    switch (self.color_type) {
                        .color_256 => {
                            if (fg_pixel.eql(last_fg_pixel) and bg_pixel.eql(last_bg_pixel)) {
                                continue;
                            }
                        },
                        .color_true => {
                            if (fg_pixel.eql(last_fg_pixel) and bg_pixel.eql(last_bg_pixel)) {
                                continue;
                            }
                        },
                    }

                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ (j / 2) + 1, i + 1 })) |c| {
                        try add_char_terminal(&self.terminal_buffer, c);
                    }
                }

                switch (self.color_type) {
                    .color_256 => {
                        self.last_frame[j * self.pixel_width + i] = fg_pixel;
                        self.last_frame[(j + 1) * self.pixel_width + i] = bg_pixel;
                        if (bg_pixel.eql(prev_fg_pixel) and fg_pixel.eql(prev_bg_pixel) and !fg_pixel.eql(bg_pixel)) {
                            for (LOWER_PX) |c| {
                                try add_char_terminal(&self.terminal_buffer, c);
                            }
                        } else {
                            if (!prev_fg_pixel.eql(fg_pixel)) {
                                prev_fg_pixel.color_256 = fg_pixel.color_256;
                                for (term.FG[fg_pixel.color_256]) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }
                            if (!prev_bg_pixel.eql(bg_pixel)) {
                                prev_bg_pixel.color_256 = bg_pixel.color_256;
                                for (term.BG[bg_pixel.color_256]) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }

                            if (fg_pixel.eql(bg_pixel)) {
                                try add_char_terminal(&self.terminal_buffer, ' ');
                            } else {
                                for (UPPER_PX) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }
                        }
                    },
                    .color_true => {
                        self.last_frame[j * self.pixel_width + i].color_true.r = fg_pixel.color_true.r;
                        self.last_frame[j * self.pixel_width + i].color_true.g = fg_pixel.color_true.g;
                        self.last_frame[j * self.pixel_width + i].color_true.b = fg_pixel.color_true.b;
                        self.last_frame[(j + 1) * self.pixel_width + i].color_true.r = bg_pixel.color_true.r;
                        self.last_frame[(j + 1) * self.pixel_width + i].color_true.g = bg_pixel.color_true.g;
                        self.last_frame[(j + 1) * self.pixel_width + i].color_true.b = bg_pixel.color_true.b;
                        if (bg_pixel.eql(prev_fg_pixel) and fg_pixel.eql(prev_bg_pixel) and !fg_pixel.eql(bg_pixel)) {
                            for (LOWER_PX) |c| {
                                try add_char_terminal(&self.terminal_buffer, c);
                            }
                        } else {
                            if (!prev_fg_pixel.eql(fg_pixel)) {
                                prev_fg_pixel.color_true.r = fg_pixel.color_true.r;
                                prev_fg_pixel.color_true.g = fg_pixel.color_true.g;
                                prev_fg_pixel.color_true.b = fg_pixel.color_true.b;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ fg_pixel.color_true.r, fg_pixel.color_true.g, fg_pixel.color_true.b })) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }
                            if (!prev_bg_pixel.eql(bg_pixel)) {
                                prev_bg_pixel.color_true.r = bg_pixel.color_true.r;
                                prev_bg_pixel.color_true.g = bg_pixel.color_true.g;
                                prev_bg_pixel.color_true.b = bg_pixel.color_true.b;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ bg_pixel.color_true.r, bg_pixel.color_true.g, bg_pixel.color_true.b })) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }

                            if (fg_pixel.eql(bg_pixel)) {
                                try add_char_terminal(&self.terminal_buffer, ' ');
                            } else {
                                for (UPPER_PX) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
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
                        try add_char_terminal(&self.terminal_buffer, c);
                    }

                    switch (self.color_type) {
                        .color_256 => {
                            const fg_pixel: PixelType = .{ .color_256 = term.rgb_256(t.r, t.g, t.b) };

                            if (!prev_fg_pixel.eql(fg_pixel)) {
                                prev_fg_pixel = fg_pixel;
                                for (term.FG[fg_pixel.color_256]) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }

                            for (t.value, 0..) |c, z| {
                                const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * self.pixel_width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                                if (!prev_bg_pixel.eql(bg_pixel)) {
                                    prev_bg_pixel = bg_pixel;
                                    for (term.BG[bg_pixel.color_256]) |ci| {
                                        try add_char_terminal(&self.terminal_buffer, ci);
                                    }
                                }
                                try add_char_terminal(&self.terminal_buffer, c);
                            }
                        },
                        .color_true => {
                            if (prev_fg_pixel.color_true.r != t.r or prev_fg_pixel.color_true.g != t.g or prev_fg_pixel.color_true.b != t.b) {
                                prev_fg_pixel.color_true.r = t.r;
                                prev_fg_pixel.color_true.g = t.g;
                                prev_fg_pixel.color_true.b = t.b;
                                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ t.r, t.g, t.b })) |c| {
                                    try add_char_terminal(&self.terminal_buffer, c);
                                }
                            }
                            for (t.value, 0..) |c, z| {
                                const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * self.pixel_width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                                if (!prev_bg_pixel.eql(bg_pixel)) {
                                    prev_bg_pixel.color_true.r = bg_pixel.color_true.r;
                                    prev_bg_pixel.color_true.g = bg_pixel.color_true.g;
                                    prev_bg_pixel.color_true.b = bg_pixel.color_true.b;
                                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ bg_pixel.color_true.r, bg_pixel.color_true.g, bg_pixel.color_true.b })) |ci| {
                                        try add_char_terminal(&self.terminal_buffer, ci);
                                    }
                                }
                                try add_char_terminal(&self.terminal_buffer, c);
                            }
                        },
                    }
                }
                text = self.text_to_render.pop();
            }
        }
        self.first_render = false;
        if (self.terminal_buffer.items.len > 0) {
            try self.terminal.out(self.terminal_buffer.items);
            try self.terminal.out(term.COLOR_RESET);
            try self.terminal.out(term.CURSOR_HIDE);
            if (terminal_type == .wasm) try self.terminal.out("\n");
        }
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
        self.terminal_buffer.clearRetainingCapacity();
        const width = if (bounds != null) @min(self.pixel_width, @as(usize, @intCast(@as(u32, @bitCast(bounds.?.width))))) else self.pixel_width;
        const height = if (bounds != null) @min(self.pixel_height, @as(usize, @intCast(@as(u32, @bitCast(bounds.?.height))))) else self.pixel_height;
        PIXEL_RENDERER_LOG.info("Rendering at {d}x{d} pixel dims {d}x{d} bounds dims {d}x{d}\n", .{ width, height, self.pixel_width, self.pixel_height, if (bounds != null) @as(usize, @intCast(@as(u32, @bitCast(bounds.?.width)))) else 0, if (bounds != null) @as(usize, @intCast(@as(u32, @bitCast(bounds.?.height)))) else 0 });
        if (self.sixel_renderer) {
            try self.sixel_render(width, height);
        } else {
            try self.block_render();
        }
    }
};
