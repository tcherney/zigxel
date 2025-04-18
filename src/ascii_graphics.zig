const std = @import("std");
const term = @import("term");
const texture = @import("texture.zig");
const common = @import("common");
const sprite = @import("sprite.zig");
const image = @import("image");

pub const ColorMode = enum {
    color_256,
    color_true,
};

const UPPER_PX = "▀";
const LOWER_PX = "▄";

const GRAPHICS_LOG = std.log.scoped(.ascii_graphics);
//TODO add camera matrix for basic 3d support
pub const Error = error{TextureError} || term.Error || std.mem.Allocator.Error || std.fmt.BufPrintError || image.Error;
pub fn AsciiGraphics(comptime color_type: ColorMode) type {
    return struct {
        terminal: term.Term = undefined,
        pixel_buffer: []PixelType = undefined,
        ascii_buffer: []u8 = undefined,
        last_frame: []PixelType = undefined,
        ascii_last_frame: []u8 = undefined,
        background_pixel_buffer: []PixelType = undefined,
        background_last_frame: []PixelType = undefined,
        terminal_buffer: []u8 = undefined,
        allocator: std.mem.Allocator = undefined,
        first_render: bool = true,

        pub const Point = common.Point(2, i32);
        pub const Rectangle = common.Rectangle;
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
            var ascii_buffer = try allocator.alloc(u8, terminal.size.height * terminal.size.width * 2);
            for (0..ascii_buffer.len) |i| {
                ascii_buffer[i] = ' ';
            }
            var ascii_last_frame = try allocator.alloc(u8, terminal.size.height * terminal.size.width * 2);
            for (0..ascii_last_frame.len) |i| {
                ascii_last_frame[i] = ' ';
            }
            var last_frame = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 2);
            for (0..last_frame.len) |i| {
                if (color_type == .color_256) {
                    last_frame[i] = 0;
                } else {
                    last_frame[i] = PixelType{};
                }
            }
            var background_pixel_buffer = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 2);
            for (0..background_pixel_buffer.len) |i| {
                if (color_type == .color_256) {
                    background_pixel_buffer[i] = 0;
                } else {
                    background_pixel_buffer[i] = PixelType{};
                }
            }
            var background_last_frame = try allocator.alloc(PixelType, terminal.size.height * terminal.size.width * 2);
            for (0..background_last_frame.len) |i| {
                if (color_type == .color_256) {
                    background_last_frame[i] = 0;
                } else {
                    background_last_frame[i] = PixelType{};
                }
            }

            return Self{
                .terminal = terminal,
                .allocator = allocator,
                .pixel_buffer = pixel_buffer,
                .last_frame = last_frame,
                .ascii_buffer = ascii_buffer,
                .ascii_last_frame = ascii_last_frame,
                .background_last_frame = background_last_frame,
                .background_pixel_buffer = background_pixel_buffer,
                // need space for setting background and setting of foreground color for every pixel
                .terminal_buffer = try allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((terminal.size.height * terminal.size.width) + 200)),
            };
        }

        pub fn size_change(self: *Self, size: term.Size) Error!void {
            self.allocator.free(self.terminal_buffer);
            self.allocator.free(self.last_frame);
            self.terminal.size.width = size.width;
            self.terminal.size.height = size.height * 2;
            self.terminal_buffer = try self.allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((self.terminal.size.height * self.terminal.size.width) + 200));
            self.allocator.free(self.pixel_buffer);
            self.allocator.free(self.ascii_buffer);
            self.allocator.free(self.ascii_last_frame);
            self.allocator.free(self.background_last_frame);
            self.allocator.free(self.background_pixel_buffer);
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
            self.ascii_last_frame = try self.allocator.alloc(u8, self.pixel_buffer.len);
            for (0..self.pixel_buffer.len) |i| {
                self.ascii_last_frame[i] = ' ';
            }
            self.ascii_buffer = try self.allocator.alloc(u8, self.pixel_buffer.len);
            for (0..self.pixel_buffer.len) |i| {
                self.ascii_buffer[i] = ' ';
            }
            self.background_pixel_buffer = try self.allocator.alloc(PixelType, self.terminal.size.height * self.terminal.size.width * 2);
            for (0..self.background_pixel_buffer.len) |i| {
                if (color_type == .color_256) {
                    self.background_pixel_buffer[i] = 0;
                } else {
                    self.background_pixel_buffer[i] = PixelType{};
                }
            }
            self.background_last_frame = try self.allocator.alloc(PixelType, self.background_pixel_buffer.len);
            for (0..self.background_pixel_buffer.len) |i| {
                self.background_last_frame[i] = self.background_pixel_buffer[i];
            }
            self.first_render = true;
        }

        pub fn deinit(self: *Self) Error!void {
            self.allocator.free(self.pixel_buffer);
            self.allocator.free(self.terminal_buffer);
            try self.terminal.deinit();
            self.allocator.free(self.last_frame);
            self.allocator.free(self.ascii_buffer);
            self.allocator.free(self.ascii_last_frame);
            self.allocator.free(self.background_last_frame);
            self.allocator.free(self.background_pixel_buffer);
        }

        pub fn set_bg(self: *Self, r: u8, g: u8, b: u8, dest: ?texture.Texture) void {
            if (dest == null) {
                const bg_color_indx = term.rgb_256(r, g, b);
                for (0..self.background_pixel_buffer.len) |i| {
                    if (color_type == .color_256) {
                        self.background_pixel_buffer[i] = bg_color_indx;
                    } else {
                        self.background_pixel_buffer[i] = .{ .r = r, .g = g, .b = b };
                    }
                }
            } else {
                const bg_color_indx = term.rgb_256(r, g, b);
                for (0..dest.?.background_pixel_buffer.len) |i| {
                    if (color_type == .color_256) {
                        dest.?.background_pixel_buffer[i].set_r(bg_color_indx);
                    } else {
                        dest.?.background_pixel_buffer[i] = texture.Pixel.init(r, g, b, null);
                    }
                }
            }
        }

        pub fn draw_symbol_bg(self: *Self, x: i32, y: i32, symbol: u8, p: texture.Pixel, dest: ?texture.Texture, bgr: u8, bgg: u8, bgb: u8, custom_bg: bool) void {
            if (dest == null) {
                if (x < 0 or x >= @as(i32, @bitCast(self.terminal.size.width)) or y >= @as(i32, @bitCast(self.terminal.size.height)) or y < 0) {
                    return;
                }
                const x_indx: usize = @bitCast(x);
                const y_indx: usize = @bitCast(y);

                self.background_pixel_buffer[y_indx * self.terminal.size.width + x_indx].r = bgr;
                self.background_pixel_buffer[y_indx * self.terminal.size.width + x_indx].g = bgg;
                self.background_pixel_buffer[y_indx * self.terminal.size.width + x_indx].b = bgb;

                self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].r = p.get_r();
                self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].g = p.get_g();
                self.pixel_buffer[y_indx * self.terminal.size.width + x_indx].b = p.get_b();
                self.ascii_buffer[y_indx * self.terminal.size.width + x_indx] = symbol;
            } else {
                if (x < 0 or x >= @as(i32, @bitCast(dest.?.width)) or y >= @as(i32, @bitCast(dest.?.height)) or y < 0) {
                    return;
                }
                const x_indx: usize = @bitCast(x);
                const y_indx: usize = @bitCast(y);
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_r(p.get_a());
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_g(p.get_g());
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_b(p.get_b());
                dest.?.pixel_buffer[y_indx * dest.?.width + x_indx].set_a(p.get_a());
                dest.?.background_pixel_buffer[y_indx * dest.?.width + x_indx].set_r(bgr);
                dest.?.background_pixel_buffer[y_indx * dest.?.width + x_indx].set_g(bgg);
                dest.?.background_pixel_buffer[y_indx * dest.?.width + x_indx].set_b(bgb);
                dest.?.ascii_buffer[y_indx * self.terminal.size.width + x_indx] = symbol;
            }
        }

        pub fn draw_symbol(self: *Self, x: i32, y: i32, symbol: u8, p: texture.Pixel, dest: ?texture.Texture) void {
            self.draw_symbol_bg(x, y, symbol, p, dest, 0, 0, 0, false);
        }
        //TODO fix by removing stack references and setting the ascii buffer in graphics/texture objects
        pub fn draw_ascii_buffer(self: *Self, pixel_buffer: []texture.Pixel, background_pixel_buffer: []texture.Pixel, ascii_buffer: []u8, width: u32, height: u32, src: Rectangle, dest_rect: Rectangle, dest: ?texture.Texture) Error!void {
            var tex_indx: usize = (@as(u32, @bitCast(src.y)) * width + @as(u32, @bitCast(src.x)));
            if (src.height > height or src.width > width) {
                return Error.TextureError;
            }
            //const height_i: i32 = @as(i32, @bitCast(tex.height));
            const width_i: i32 = @as(i32, @bitCast(width));
            const src_height_i: i32 = @as(i32, @bitCast(src.height));
            const src_width_i: i32 = @as(i32, @bitCast(src.width));
            GRAPHICS_LOG.debug("{d} {d}\n", .{ width_i, src_width_i });
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
                        if (i < 0) {
                            tex_indx += 1;
                            continue;
                        } else if (i >= @as(i32, @intCast(self.terminal.size.width))) {
                            tex_indx += @as(usize, @intCast(@as(u32, @bitCast((dest_rect.x + width_i) - i))));
                            break;
                        }
                        const i_usize: usize = @intCast(i);
                        const j_usize: usize = @intCast(j);

                        switch (color_type) {
                            .color_256 => {
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize] = term.rgb_256(pixel_buffer[tex_indx].get_r(), pixel_buffer[tex_indx].get_g(), pixel_buffer[tex_indx].get_b());
                                self.background_pixel_buffer[j_usize * self.terminal.size.width + i_usize] = term.rgb_256(background_pixel_buffer[tex_indx].get_r(), background_pixel_buffer[tex_indx].get_g(), background_pixel_buffer[tex_indx].get_b());
                            },
                            .color_true => {
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize].r = pixel_buffer[tex_indx].get_r();
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize].g = pixel_buffer[tex_indx].get_g();
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize].b = pixel_buffer[tex_indx].get_b();

                                self.background_pixel_buffer[j_usize * self.terminal.size.width + i_usize].r = background_pixel_buffer[tex_indx].get_r();
                                self.background_pixel_buffer[j_usize * self.terminal.size.width + i_usize].g = background_pixel_buffer[tex_indx].get_g();
                                self.background_pixel_buffer[j_usize * self.terminal.size.width + i_usize].b = background_pixel_buffer[tex_indx].get_b();
                            },
                        }
                        self.ascii_buffer[j_usize * self.terminal.size.width + i_usize] = ascii_buffer[tex_indx];

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
                        if (i < 0) {
                            tex_indx += 1;
                            continue;
                        } else if (i >= @as(i32, @bitCast(dest.?.width))) {
                            tex_indx += @as(usize, @intCast(@as(u32, @bitCast((dest_rect.x + width_i) - i))));
                            break;
                        }
                        const i_usize: usize = @intCast(i);
                        const j_usize: usize = @intCast(j);

                        switch (color_type) {
                            .color_256 => {
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_r(term.rgb_256(pixel_buffer[tex_indx].get_r(), pixel_buffer[tex_indx].get_g(), pixel_buffer[tex_indx].get_b()));
                                dest.?.background_pixel_buffer[j_usize * dest.?.width + i_usize].set_r(term.rgb_256(background_pixel_buffer[tex_indx].get_r(), background_pixel_buffer[tex_indx].get_g(), background_pixel_buffer[tex_indx].get_b()));
                            },
                            .color_true => {
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_r(pixel_buffer[tex_indx].get_r());
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_g(pixel_buffer[tex_indx].get_g());
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_b(pixel_buffer[tex_indx].get_b());
                                dest.?.pixel_buffer[j_usize * dest.?.width + i_usize].set_a(pixel_buffer[tex_indx].get_a());

                                dest.?.background_pixel_buffer[j_usize * dest.?.width + i_usize].set_r(background_pixel_buffer[tex_indx].get_r());
                                dest.?.background_pixel_buffer[j_usize * dest.?.width + i_usize].set_g(background_pixel_buffer[tex_indx].get_g());
                                dest.?.background_pixel_buffer[j_usize * dest.?.width + i_usize].set_b(background_pixel_buffer[tex_indx].get_b());
                                dest.?.background_pixel_buffer[j_usize * dest.?.width + i_usize].set_a(background_pixel_buffer[tex_indx].get_a());
                            },
                        }
                        dest.?.ascii_buffer[j_usize * dest.?.width + i_usize] = ascii_buffer[tex_indx];

                        tex_indx += 1;
                    }
                    tex_indx += width - src.width;
                }
            }
        }

        pub fn draw_texture(self: *Self, tex: texture.Texture, src_rect: Rectangle, dest_rect: Rectangle, dest: ?texture.Texture) Error!void {
            try self.draw_ascii_buffer(tex.pixel_buffer, tex.background_pixel_buffer, tex.ascii_buffer, tex.width, tex.height, src_rect, dest_rect, dest);
        }

        //TODO scaling pass based on difference between render size and user window, can scale everything up to meet their resolution
        //TODO FIX TO JUST OUTPUT THE RAW ASCII HAVE TO RESTRUCTURE TO NOT TREAT BG AS ANOTHER ROW
        pub fn flip(self: *Self, dest: ?texture.Texture, bounds: ?Rectangle) Error!void {
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
                                self.pixel_buffer[buffer_indx] = dest.?.pixel_buffer[y * dest.?.width + x].get_r();
                                self.background_pixel_buffer[buffer_indx] = dest.?.background_pixel_buffer[y * dest.?.width + x].get_r();
                            } else {
                                self.pixel_buffer[buffer_indx].r = dest.?.pixel_buffer[y * dest.?.width + x].get_r();
                                self.pixel_buffer[buffer_indx].g = dest.?.pixel_buffer[y * dest.?.width + x].get_g();
                                self.pixel_buffer[buffer_indx].b = dest.?.pixel_buffer[y * dest.?.width + x].get_b();

                                self.background_pixel_buffer[buffer_indx].r = dest.?.background_pixel_buffer[y * dest.?.width + x].get_r();
                                self.background_pixel_buffer[buffer_indx].g = dest.?.background_pixel_buffer[y * dest.?.width + x].get_g();
                                self.background_pixel_buffer[buffer_indx].b = dest.?.background_pixel_buffer[y * dest.?.width + x].get_b();
                            }
                            self.ascii_buffer[buffer_indx] = dest.?.ascii_buffer[y * dest.?.width + x];
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
            var prev_bg_pixel: PixelType = self.background_pixel_buffer[j * width + i];
            var prev_ascii: u8 = self.ascii_buffer[j * width + i];
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
                GRAPHICS_LOG.debug("first render\n", .{});
                try self.terminal.out(term.CURSOR_HOME);
            }
            //GRAPHICS_LOG.debug("width height {d} {d}\n", .{ width, height });
            // each pixel is an index into the possible 256 colors
            while (j < height) : (j += 2) {
                i = 0;
                while (i < width) : (i += 1) {
                    const fg_pixel = self.pixel_buffer[j * width + i];
                    const bg_pixel = self.background_pixel_buffer[j * width + i];
                    const ascii = self.ascii_buffer[j * width + i];
                    const last_fg_pixel = self.last_frame[j * width + i];
                    const last_bg_pixel = self.background_last_frame[j * width + i];
                    if (!self.first_render) {
                        switch (color_type) {
                            .color_256 => {
                                if (fg_pixel == last_fg_pixel and bg_pixel == last_bg_pixel) {
                                    continue;
                                }
                                self.last_frame[j * width + i] = fg_pixel;
                                self.background_last_frame[j * width + i] = bg_pixel;
                            },
                            .color_true => {
                                if (fg_pixel.r == last_fg_pixel.r and bg_pixel.r == last_bg_pixel.r and fg_pixel.g == last_fg_pixel.g and bg_pixel.g == last_bg_pixel.g and fg_pixel.b == last_fg_pixel.b and bg_pixel.b == last_bg_pixel.b) {
                                    continue;
                                }
                                self.last_frame[j * width + i].r = fg_pixel.r;
                                self.last_frame[j * width + i].g = fg_pixel.g;
                                self.last_frame[j * width + i].b = fg_pixel.b;
                                self.background_last_frame[j * width + i].r = bg_pixel.r;
                                self.background_last_frame[j * width + i].g = bg_pixel.g;
                                self.background_last_frame[j * width + i].b = bg_pixel.b;
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
            self.first_render = false;
            if (buffer_len > 0) {
                try self.terminal.out(self.terminal_buffer[0..buffer_len]);
                try self.terminal.out(term.COLOR_RESET);
                try self.terminal.out(term.CURSOR_HIDE);
            }
        }
    };
}
