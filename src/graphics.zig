const std = @import("std");
const term = @import("term");
const texture = @import("texture.zig");
const utils = @import("utils.zig");
const sprite = @import("sprite.zig");

//https://www.compart.com/en/unicode/U+2580
const UPPER_PX = "▀";
//const FULL_PX = "█";
const LOWER_PX = "▄";
//▀█▄

pub const Error = error{TextureError} || term.Error || std.mem.Allocator.Error || std.fmt.BufPrintError;
pub const Point = utils.Point(i32);

pub fn Graphics(comptime color_type: utils.ColorMode) type {
    return struct {
        ascii_based: bool = false,
        terminal: term.Term = undefined,
        pixel_buffer: []PixelType = undefined,
        last_frame: []PixelType = undefined,
        terminal_buffer: []u8 = undefined,
        text_to_render: std.ArrayList(Text) = undefined,
        allocator: std.mem.Allocator = undefined,
        first_render: bool = true,
        pub const PixelType: type = switch (color_type) {
            .color_256 => u8,
            .color_true => struct { r: u8 = 0, g: u8 = 0, b: u8 = 0 },
        };
        const Self = @This();
        pub const Text = struct { x: i32, y: i32, r: u8, g: u8, b: u8, value: []const u8 };

        pub fn init(allocator: std.mem.Allocator) Error!Self {
            const terminal = try term.Term.init(allocator);
            var pixel_buffer = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 2);
            for (0..pixel_buffer.len) |i| {
                if (color_type == .color_256) {
                    pixel_buffer[i] = 0;
                } else {
                    pixel_buffer[i] = PixelType{};
                }
            }
            var last_frame = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 2);
            for (0..last_frame.len) |i| {
                if (color_type == .color_256) {
                    last_frame[i] = 0;
                } else {
                    last_frame[i] = PixelType{};
                }
            }
            return Self{
                .terminal = terminal,
                .allocator = allocator,
                .pixel_buffer = pixel_buffer,
                .last_frame = last_frame,
                // need space for setting background and setting of foreground color for every pixel
                .terminal_buffer = try allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((terminal.size.height * terminal.size.width) + 200)),
                .text_to_render = std.ArrayList(Text).init(allocator),
            };
        }

        pub fn size_change(self: *Self, size: term.Size) Error!void {
            self.allocator.free(self.terminal_buffer);
            self.allocator.free(self.last_frame);
            self.terminal.size.width = size.width;
            self.terminal.size.height = size.height * 2;
            self.terminal_buffer = try self.allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((self.terminal.size.height * self.terminal.size.width) + 200));
            self.allocator.free(self.pixel_buffer);
            self.pixel_buffer = try self.allocator.alloc(PixelType, self.terminal.size.height * self.terminal.size.width * 2);
            for (0..self.pixel_buffer.len) |i| {
                if (color_type == .color_256) {
                    self.pixel_buffer[i] = 0;
                } else {
                    self.pixel_buffer[i] = PixelType{};
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
            try self.terminal.deinit();
            self.allocator.free(self.last_frame);
            self.text_to_render.deinit();
        }

        pub fn set_bg(self: *Self, r: u8, g: u8, b: u8, dest: ?texture.Texture) void {
            if (dest == null) {
                const bg_color_indx = term.rgb_256(r, g, b);
                for (0..self.pixel_buffer.len) |i| {
                    if (color_type == .color_256) {
                        self.pixel_buffer[i] = bg_color_indx;
                    } else {
                        self.pixel_buffer[i] = .{ .r = r, .g = g, .b = b };
                    }
                }
            } else {
                const bg_color_indx = term.rgb_256(r, g, b);
                for (0..dest.?.pixel_buffer.len) |i| {
                    if (color_type == .color_256) {
                        dest.?.pixel_buffer[i].r = bg_color_indx;
                    } else {
                        dest.?.pixel_buffer[i] = .{ .r = r, .g = g, .b = b };
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
                if (x < 0 or x > self.terminal.size.width or y > self.terminal.size.height) {
                    return;
                }
                const x_indx = @as(usize, @intCast(@as(u32, @bitCast(x))));
                const y_indx = @as(usize, @intCast(@as(u32, @bitCast(y))));
                if (p.a) |alpha| {
                    const max_pixel = 255.0;

                    var rf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(p.r));
                    var gf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(p.g));
                    var bf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(p.b));
                    if (custom_bg) {
                        rf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bgr));
                        gf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bgg));
                        bf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bgb));
                    } else {
                        const bkgd = self.pixel_buffer[y_indx * self.terminal.size.width + x_indx];
                        rf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.r));
                        gf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.g));
                        bf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.b));
                    }

                    self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].r = @as(u8, @intFromFloat(rf));
                    self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].g = @as(u8, @intFromFloat(gf));
                    self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].b = @as(u8, @intFromFloat(bf));
                } else {
                    self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].r = p.r;
                    self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].g = p.g;
                    self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].b = p.b;
                }
            } else {
                if (x < 0 or x >= dest.?.width or y >= dest.?.height or y < 0) {
                    return;
                }
                const x_indx = @as(usize, @intCast(@as(u32, @bitCast(x))));
                const y_indx = @as(usize, @intCast(@as(u32, @bitCast(y))));
                if (p.a) |alpha| {
                    const max_pixel = 255.0;
                    var rf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(p.r));
                    var gf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(p.g));
                    var bf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(p.b));
                    if (custom_bg) {
                        rf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bgr));
                        gf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bgg));
                        bf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bgb));
                    } else {
                        const bkgd = dest.?.pixel_buffer[y_indx * dest.?.width + x_indx];
                        rf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.r));
                        gf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.g));
                        bf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.b));
                    }
                    dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].r = @as(u8, @intFromFloat(rf));
                    dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].g = @as(u8, @intFromFloat(gf));
                    dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].b = @as(u8, @intFromFloat(bf));
                } else {
                    dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].r = p.r;
                    dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].g = p.g;
                    dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].b = p.b;
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
                std.debug.print("rendering scaled\n", .{});
                const src_rect = utils.Rectangle{ .x = 0, .y = 0, .width = s.dest.width, .height = s.dest.height };
                try self.draw_pixel_buffer(s.scaled_buffer.?, s.dest.width, s.dest.height, src_rect, s.dest, dest);
            }
        }

        fn draw_pixel_buffer(self: *Self, pixel_buffer: []texture.Pixel, width: u32, height: u32, src: utils.Rectangle, dest_rect: utils.Rectangle, dest: ?texture.Texture) Error!void {
            var tex_indx: usize = (@as(u32, @bitCast(src.y)) * width + @as(u32, @bitCast(src.x)));
            if (src.height > height or src.width > width) {
                return Error.TextureError;
            }
            //const height_i: i32 = @as(i32, @bitCast(tex.height));
            const width_i: i32 = @as(i32, @bitCast(width));
            const src_height_i: i32 = @as(i32, @bitCast(src.height));
            const src_width_i: i32 = @as(i32, @bitCast(src.width));
            std.debug.print("{d} {d}\n", .{ width_i, src_width_i });
            var j: i32 = dest_rect.y;
            if (dest == null) {
                while (j < (dest_rect.y + src_height_i)) : (j += 1) {
                    if (j < 0) {
                        tex_indx += width;
                        continue;
                    } else if (j >= self.terminal.size.height) {
                        break;
                    }
                    var i: i32 = dest_rect.x;
                    while (i < (dest_rect.x + src_width_i) and tex_indx < pixel_buffer.len) : (i += 1) {
                        const i_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(i))));
                        const j_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(j))));
                        if (i < 0) {
                            tex_indx += 1;
                            continue;
                        } else if (i >= self.terminal.size.width) {
                            tex_indx += @as(usize, @intCast(@as(u32, @bitCast((dest_rect.x + width_i) - i))));
                            break;
                        }
                        // have alpha channel
                        var r: u8 = pixel_buffer[tex_indx].r;
                        var g: u8 = pixel_buffer[tex_indx].g;
                        var b: u8 = pixel_buffer[tex_indx].b;
                        if (pixel_buffer[tex_indx].a) |alpha| {
                            std.debug.print("computing alpha {any}", .{alpha});
                            const max_pixel = 255.0;
                            const bkgd = self.pixel_buffer[j_usize * self.terminal.size.width + i_usize];
                            var rf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(r));
                            var gf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(g));
                            var bf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(b));
                            rf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.r));
                            gf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.g));
                            bf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.b));
                            r = @as(u8, @intFromFloat(rf));
                            g = @as(u8, @intFromFloat(gf));
                            b = @as(u8, @intFromFloat(bf));
                        }

                        switch (color_type) {
                            .color_256 => {
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize] = term.rgb_256(r, g, b);
                            },
                            .color_true => {
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize].r = r;
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize].g = g;
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize].b = b;
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
                        const i_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(i))));
                        const j_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(j))));
                        if (i < 0) {
                            tex_indx += 1;
                            continue;
                        } else if (i >= dest.?.width) {
                            tex_indx += @as(usize, @intCast(@as(u32, @bitCast((dest_rect.x + width_i) - i))));
                            break;
                        }
                        // have alpha channel
                        var r: u8 = pixel_buffer[tex_indx].r;
                        var g: u8 = pixel_buffer[tex_indx].g;
                        var b: u8 = pixel_buffer[tex_indx].b;
                        if (pixel_buffer[tex_indx].a) |alpha| {
                            std.debug.print("computing alpha {any}", .{alpha});
                            const max_pixel = 255.0;
                            const bkgd = dest.?.pixel_buffer[j_usize * dest.?.width + i_usize];
                            var rf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(r));
                            var gf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(g));
                            var bf: f32 = if (alpha == 0) 0 else (@as(f32, @floatFromInt(alpha)) / max_pixel) * @as(f32, @floatFromInt(b));
                            rf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.r));
                            gf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.g));
                            bf += (1 - (@as(f32, @floatFromInt(alpha)) / max_pixel)) * @as(f32, @floatFromInt(bkgd.b));
                            r = @as(u8, @intFromFloat(rf));
                            g = @as(u8, @intFromFloat(gf));
                            b = @as(u8, @intFromFloat(bf));
                        }

                        switch (color_type) {
                            .color_256 => {
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize] = term.rgb_256(r, g, b);
                            },
                            .color_true => {
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].r = r;
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].g = g;
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].b = b;
                            },
                        }

                        tex_indx += 1;
                    }
                    tex_indx += width - src.width;
                }
            }
        }

        pub fn draw_texture(self: *Self, tex: texture.Texture, src_rect: utils.Rectangle, dest_rect: utils.Rectangle, dest: ?texture.Texture) Error!void {
            try self.draw_pixel_buffer(tex.pixel_buffer, tex.width, tex.height, src_rect, dest_rect, dest);
        }

        pub fn draw_rect(self: *Self, x: usize, y: usize, w: usize, h: usize, r: u8, g: u8, b: u8, dest: ?texture.Texture) void {
            if (dest == null) {
                const color_indx = term.rgb_256(r, g, b);
                for (y..y + h) |j| {
                    for (x..x + w) |i| {
                        switch (color_type) {
                            .color_256 => {
                                self.pixel_buffer[j * self.terminal.size.width + i] = color_indx;
                            },
                            .color_true => {
                                self.pixel_buffer[j * self.terminal.size.width + i].r = r;
                                self.pixel_buffer[j * self.terminal.size.width + i].g = g;
                                self.pixel_buffer[j * self.terminal.size.width + i].b = b;
                            },
                        }
                    }
                }
            } else {
                const color_indx = term.rgb_256(r, g, b);
                for (y..y + h) |j| {
                    for (x..x + w) |i| {
                        switch (color_type) {
                            .color_256 => {
                                dest.?.pixel_buffer[j * dest.?.width + i].r = color_indx;
                            },
                            .color_true => {
                                dest.?.pixel_buffer[j * dest.?.width + i].r = r;
                                dest.?.pixel_buffer[j * dest.?.width + i].g = g;
                                dest.?.pixel_buffer[j * dest.?.width + i].b = b;
                            },
                        }
                    }
                }
            }
        }

        pub fn draw_text(self: *Self, value: []const u8, x: i32, y: i32, r: u8, g: u8, b: u8) Error!void {
            //std.debug.print("{s} with len {d}\n", .{ value, value.len });
            try self.text_to_render.append(Text{ .x = x, .y = if (@mod(y, 2) == 1) y - 1 else y, .r = r, .g = g, .b = b, .value = value });
        }

        //TODO scaling pass based on difference between render size and user window, can scale everything up to meet their resolution
        pub fn flip(self: *Self, dest: ?texture.Texture, bounds: ?utils.Rectangle) Error!void {
            if (dest != null and bounds != null) {
                if (bounds.?.width > @as(u32, @intCast(self.terminal.size.width)) or bounds.?.height > @as(u32, @intCast(self.terminal.size.height))) {
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
                            if (color_type == .color_256) {
                                self.pixel_buffer[buffer_indx] = dest.?.pixel_buffer[y * dest.?.width + x].r;
                            } else {
                                self.pixel_buffer[buffer_indx].r = dest.?.pixel_buffer[y * dest.?.width + x].r;
                                self.pixel_buffer[buffer_indx].g = dest.?.pixel_buffer[y * dest.?.width + x].g;
                                self.pixel_buffer[buffer_indx].b = dest.?.pixel_buffer[y * dest.?.width + x].b;
                            }
                            buffer_indx += 1;
                        }
                    }
                }
            }
            var buffer_len: usize = 0;

            var j: usize = 0;
            var i: usize = 0;
            const width = self.terminal.size.width;
            const height = self.terminal.size.height * 2;
            var prev_fg_pixel: PixelType = self.pixel_buffer[j * width + i];
            var prev_bg_pixel: PixelType = self.pixel_buffer[(j + 1) * width + i];
            var dirty_pixel_buffer: [48]u8 = undefined;
            if (color_type == .color_256) {
                for (term.FG[prev_fg_pixel]) |c| {
                    self.terminal_buffer[buffer_len] = c;
                    buffer_len += 1;
                }
                for (term.BG[prev_bg_pixel]) |c| {
                    self.terminal_buffer[buffer_len] = c;
                    buffer_len += 1;
                }
            } else {
                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ prev_fg_pixel.r, prev_fg_pixel.g, prev_fg_pixel.b })) |c| {
                    self.terminal_buffer[buffer_len] = c;
                    buffer_len += 1;
                }

                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ prev_bg_pixel.r, prev_bg_pixel.g, prev_bg_pixel.b })) |c| {
                    self.terminal_buffer[buffer_len] = c;
                    buffer_len += 1;
                }
            }

            if (self.first_render) {
                std.debug.print("first render\n", .{});
                try self.terminal.out(term.CURSOR_HOME);
            }
            //std.debug.print("width height {d} {d}\n", .{ width, height });
            // each pixel is an index into the possible 256 colors
            while (j < height) : (j += 2) {
                i = 0;
                while (i < width) : (i += 1) {
                    const fg_pixel = self.pixel_buffer[j * width + i];
                    const bg_pixel = self.pixel_buffer[(j + 1) * width + i];
                    const last_fg_pixel = self.last_frame[j * width + i];
                    const last_bg_pixel = self.last_frame[(j + 1) * width + i];
                    if (!self.first_render) {
                        switch (color_type) {
                            .color_256 => {
                                if (fg_pixel == last_fg_pixel and bg_pixel == last_bg_pixel) {
                                    continue;
                                }
                                self.last_frame[j * width + i] = fg_pixel;
                                self.last_frame[(j + 1) * width + i] = bg_pixel;
                            },
                            .color_true => {
                                if (fg_pixel.r == last_fg_pixel.r and bg_pixel.r == last_bg_pixel.r and fg_pixel.g == last_fg_pixel.g and bg_pixel.g == last_bg_pixel.g and fg_pixel.b == last_fg_pixel.b and bg_pixel.b == last_bg_pixel.b) {
                                    continue;
                                }
                                self.last_frame[j * width + i].r = fg_pixel.r;
                                self.last_frame[j * width + i].g = fg_pixel.g;
                                self.last_frame[j * width + i].b = fg_pixel.b;
                                self.last_frame[(j + 1) * width + i].r = bg_pixel.r;
                                self.last_frame[(j + 1) * width + i].g = bg_pixel.g;
                                self.last_frame[(j + 1) * width + i].b = bg_pixel.b;
                            },
                        }

                        for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ (j / 2) + 1, i + 1 })) |c| {
                            self.terminal_buffer[buffer_len] = c;
                            buffer_len += 1;
                        }
                    }

                    switch (color_type) {
                        .color_256 => {
                            if (bg_pixel == prev_fg_pixel and fg_pixel == prev_bg_pixel) {
                                for (LOWER_PX) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            } else {
                                if (prev_fg_pixel != fg_pixel) {
                                    prev_fg_pixel = fg_pixel;
                                    for (term.FG[fg_pixel]) |c| {
                                        self.terminal_buffer[buffer_len] = c;
                                        buffer_len += 1;
                                    }
                                }
                                if (prev_bg_pixel != bg_pixel) {
                                    prev_bg_pixel = bg_pixel;
                                    for (term.BG[bg_pixel]) |c| {
                                        self.terminal_buffer[buffer_len] = c;
                                        buffer_len += 1;
                                    }
                                }

                                if (fg_pixel == bg_pixel) {
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
                            if (bg_pixel.r == prev_fg_pixel.r and fg_pixel.r == prev_bg_pixel.r and bg_pixel.g == prev_fg_pixel.g and fg_pixel.g == prev_bg_pixel.g and bg_pixel.b == prev_fg_pixel.b and fg_pixel.b == prev_bg_pixel.b) {
                                for (LOWER_PX) |c| {
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            } else {
                                if (prev_fg_pixel.r != fg_pixel.r or prev_fg_pixel.g != fg_pixel.g or prev_fg_pixel.b != fg_pixel.b) {
                                    prev_fg_pixel.r = fg_pixel.r;
                                    prev_fg_pixel.g = fg_pixel.g;
                                    prev_fg_pixel.b = fg_pixel.b;
                                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ fg_pixel.r, fg_pixel.g, fg_pixel.b })) |c| {
                                        self.terminal_buffer[buffer_len] = c;
                                        buffer_len += 1;
                                    }
                                }
                                if (prev_bg_pixel.r != bg_pixel.r or prev_bg_pixel.g != bg_pixel.g or prev_bg_pixel.b != bg_pixel.b) {
                                    prev_bg_pixel.r = bg_pixel.r;
                                    prev_bg_pixel.g = bg_pixel.g;
                                    prev_bg_pixel.b = bg_pixel.b;
                                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ bg_pixel.r, bg_pixel.g, bg_pixel.b })) |c| {
                                        self.terminal_buffer[buffer_len] = c;
                                        buffer_len += 1;
                                    }
                                }

                                if (fg_pixel.r == bg_pixel.r and fg_pixel.g == bg_pixel.g and fg_pixel.b == bg_pixel.b) {
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
            if (self.text_to_render.items.len > 0) {
                var text = self.text_to_render.popOrNull();
                while (text) |t| {
                    if (t.y >= 0 and t.y < self.terminal.size.height) {
                        for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ @divFloor(t.y, 2) + 1, t.x + 1 })) |c| {
                            self.terminal_buffer[buffer_len] = c;
                            buffer_len += 1;
                        }

                        switch (color_type) {
                            .color_256 => {
                                const fg_pixel = term.rgb_256(t.r, t.g, t.b);

                                if (prev_fg_pixel != fg_pixel) {
                                    prev_fg_pixel.r = fg_pixel.r;
                                    prev_fg_pixel.g = fg_pixel.g;
                                    prev_fg_pixel.b = fg_pixel.b;
                                    for (term.FG[fg_pixel]) |c| {
                                        self.terminal_buffer[buffer_len] = c;
                                        buffer_len += 1;
                                    }
                                }

                                for (t.value, 0..) |c, z| {
                                    const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                                    if (prev_bg_pixel != bg_pixel) {
                                        prev_bg_pixel.r = bg_pixel.r;
                                        prev_bg_pixel.g = bg_pixel.g;
                                        prev_bg_pixel.b = bg_pixel.b;
                                        for (term.BG[bg_pixel]) |ci| {
                                            self.terminal_buffer[buffer_len] = ci;
                                            buffer_len += 1;
                                        }
                                    }
                                    self.terminal_buffer[buffer_len] = c;
                                    buffer_len += 1;
                                }
                            },
                            .color_true => {
                                if (prev_fg_pixel.r != t.r or prev_fg_pixel.g != t.g or prev_fg_pixel.b != t.b) {
                                    prev_fg_pixel.r = t.r;
                                    prev_fg_pixel.g = t.g;
                                    prev_fg_pixel.b = t.b;
                                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.FG_RGB, .{ t.r, t.g, t.b })) |c| {
                                        self.terminal_buffer[buffer_len] = c;
                                        buffer_len += 1;
                                    }
                                }

                                for (t.value, 0..) |c, z| {
                                    const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                                    if (prev_bg_pixel.r != bg_pixel.r or prev_bg_pixel.g != bg_pixel.g or prev_bg_pixel.b != bg_pixel.b) {
                                        prev_bg_pixel.r = bg_pixel.r;
                                        prev_bg_pixel.g = bg_pixel.g;
                                        prev_bg_pixel.b = bg_pixel.b;
                                        for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ term.BG_RGB, .{ bg_pixel.r, bg_pixel.g, bg_pixel.b })) |ci| {
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
                    text = self.text_to_render.popOrNull();
                }
            }
            self.first_render = false;
            if (buffer_len > 0) {
                try self.terminal.out(self.terminal_buffer[0..buffer_len]);
                try self.terminal.out(term.COLOR_RESET);
                try self.terminal.out(term.CURSOR_HIDE);
            }
        }
    };
}

// test "square" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     var graphics = try Graphics.init(allocator);
//     try graphics.set_bg(0, 0, 0);
//     try graphics.draw_rect(50, 10, 5, 5, 255, 255, 0);
//     try graphics.draw_rect(60, 8, 2, 3, 0, 255, 255);
//     try graphics.draw_rect(60, 8, 3, 1, 128, 75, 0);
//     try graphics.draw_rect(95, 15, 2, 1, 255, 128, 0);
//     try graphics.draw_rect(75, 10, 1, 1, 255, 128, 255);
//     try graphics.flip();
//     _ = try std.io.getStdIn().reader().readByte();
//     try graphics.deinit();
//     if (gpa.deinit() == .leak) {
//         std.debug.print("Leaked!\n", .{});
//     }
// }
