const std = @import("std");
const term = @import("term.zig");
const texture = @import("texture.zig");
const utils = @import("utils.zig");

//https://www.compart.com/en/unicode/U+2580
const UPPER_PX = "▀";
//const FULL_PX = "█";
const LOWER_PX = "▄";
//▀█▄

pub const Error = error{TextureError} || term.Error || std.mem.Allocator.Error || std.fmt.BufPrintError;

pub const Graphics = struct {
    ascii_based: bool = false,
    terminal: term.Term = undefined,
    pixel_buffer: []u8 = undefined,
    last_frame: []u8 = undefined,
    terminal_buffer: []u8 = undefined,
    text_to_render: std.ArrayList(Text) = undefined,
    allocator: std.mem.Allocator = undefined,
    first_render: bool = true,
    const Self = @This();
    pub const Text = struct { x: i32, y: i32, r: u8, g: u8, b: u8, value: []const u8 };

    pub fn init(allocator: std.mem.Allocator) Error!Graphics {
        const terminal = try term.Term.init(allocator);
        var pixel_buffer = try allocator.alloc(u8, terminal.size.height * terminal.size.width * 2);
        for (0..pixel_buffer.len) |i| {
            pixel_buffer[i] = 0;
        }
        var last_frame = try allocator.alloc(u8, terminal.size.height * terminal.size.width * 2);
        for (0..last_frame.len) |i| {
            last_frame[i] = 0;
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
        self.pixel_buffer = try self.allocator.alloc(u8, self.terminal.size.height * self.terminal.size.width * 2);
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i] = 0;
        }
        self.last_frame = try self.allocator.alloc(u8, self.pixel_buffer.len);
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

    pub fn set_bg(self: *Self, r: u8, g: u8, b: u8) void {
        const bg_color_indx = utils.rgb_256(r, g, b);
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i] = bg_color_indx;
        }
    }

    pub fn draw_texture(self: *Self, tex: anytype) Error!void {
        var tex_indx: usize = 0;
        const height: i32 = @as(i32, @intCast(@as(i64, @bitCast(tex.height))));
        const width: i32 = @as(i32, @intCast(@as(i64, @bitCast(tex.width))));
        switch (@TypeOf(tex)) {
            texture.Texture(texture.ColorMode.color_256) => {
                var j: i32 = tex.y;
                while (j < (tex.y + height)) : (j += 1) {
                    if (j < 0) {
                        tex_indx += tex.width;
                        continue;
                    } else if (j >= self.terminal.size.height) {
                        break;
                    }
                    var i: i32 = tex.x;
                    while (i < (tex.x + width) and tex_indx < tex.pixel_buffer.len) : (i += 1) {
                        const i_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(i))));
                        const j_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(j))));
                        if (i < 0) {
                            tex_indx += 1;
                            continue;
                        } else if (i >= self.terminal.size.width) {
                            tex_indx += @as(usize, @intCast(@as(u32, @bitCast((tex.x + width) - i))));
                            break;
                        }
                        if (tex.alpha_index) |a| {
                            if (tex.pixel_buffer[tex_indx] != a) {
                                self.pixel_buffer[j_usize * self.terminal.size.width + i_usize] = tex.pixel_buffer[tex_indx];
                            }
                        } else {
                            self.pixel_buffer[j_usize * self.terminal.size.width + i_usize] = tex.pixel_buffer[tex_indx];
                        }

                        tex_indx += 1;
                    }
                }
            },
            texture.Texture(texture.ColorMode.color_true) => {
                var j: i32 = tex.y;
                while (j < (tex.y + height)) : (j += 1) {
                    if (j < 0) {
                        tex_indx += tex.width;
                        continue;
                    } else if (j >= self.terminal.size.height) {
                        break;
                    }
                    var i: i32 = tex.x;
                    while (i < (tex.x + width) and tex_indx < tex.pixel_buffer.len) : (i += 1) {
                        const i_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(i))));
                        const j_usize: usize = @as(usize, @intCast(@as(u32, @bitCast(j))));
                        if (i < 0) {
                            tex_indx += 1;
                            continue;
                        } else if (i >= self.terminal.size.width) {
                            tex_indx += @as(usize, @intCast(@as(u32, @bitCast((tex.x + width) - i))));
                            break;
                        }
                        // have alpha channel
                        var r: u8 = tex.pixel_buffer[tex_indx].r;
                        var g: u8 = tex.pixel_buffer[tex_indx].g;
                        var b: u8 = tex.pixel_buffer[tex_indx].b;
                        if (tex.pixel_buffer[tex_indx].a) |alpha| {
                            const max_pixel = 255.0;
                            const bkgd = utils.indx_rgb(self.pixel_buffer[j_usize * self.terminal.size.width + i_usize]);
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
                        self.pixel_buffer[j_usize * self.terminal.size.width + i_usize] = utils.rgb_256(r, g, b);

                        tex_indx += 1;
                    }
                }
            },
            else => {
                return Error.TextureError;
            },
        }
    }

    pub fn draw_rect(self: *Self, x: usize, y: usize, w: usize, h: usize, r: u8, g: u8, b: u8) void {
        const color_indx = utils.rgb_256(r, g, b);
        for (y..y + h) |j| {
            for (x..x + w) |i| {
                self.pixel_buffer[j * self.terminal.size.width + i] = color_indx;
            }
        }
    }

    pub fn draw_text(self: *Self, value: []const u8, x: i32, y: i32, r: u8, g: u8, b: u8) Error!void {
        //std.debug.print("{s} with len {d}\n", .{ value, value.len });
        try self.text_to_render.append(Text{ .x = x, .y = if (@mod(y, 2) == 1) y - 1 else y, .r = r, .g = g, .b = b, .value = value });
    }

    pub fn flip(self: *Self) Error!void {
        // fill terminal buffer with pixel colors
        var buffer_len: usize = 0;
        var prev_fg_pixel: u8 = 0;
        var prev_bg_pixel: u8 = 0;
        var j: usize = 0;
        var i: usize = 0;
        const width = self.terminal.size.width;
        const height = self.terminal.size.height * 2;
        var dirty_pixel_buffer: [12]u8 = undefined;
        if (self.first_render) {
            std.debug.print("first render\n", .{});
            try self.terminal.out(term.CURSOR_HOME);
        }
        //std.debug.print("width height {d} {d}\n", .{ width, height });
        // each pixel is an index into the possible 256 colors
        while (j < height) : (j += 2) {
            i = 0;
            while (i < width) : (i += 1) {
                if (!self.first_render) {
                    if (self.pixel_buffer[j * width + i] == self.last_frame[j * width + i] and self.pixel_buffer[(j + 1) * width + i] == self.last_frame[(j + 1) * width + i]) {
                        continue;
                    }
                    self.last_frame[j * width + i] = self.pixel_buffer[j * width + i];
                    self.last_frame[(j + 1) * width + i] = self.pixel_buffer[(j + 1) * width + i];
                    for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ (j / 2) + 1, i + 1 })) |c| {
                        self.terminal_buffer[buffer_len] = c;
                        buffer_len += 1;
                    }
                }
                const fg_pixel = self.pixel_buffer[j * width + i];
                const bg_pixel = self.pixel_buffer[(j + 1) * width + i];
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
                    const fg_pixel = utils.rgb_256(t.r, t.g, t.b);

                    if (prev_fg_pixel != fg_pixel) {
                        prev_fg_pixel = fg_pixel;
                        for (term.FG[fg_pixel]) |c| {
                            self.terminal_buffer[buffer_len] = c;
                            buffer_len += 1;
                        }
                    }

                    for (t.value, 0..) |c, z| {
                        const bg_pixel = self.pixel_buffer[(@as(usize, @intCast(@as(u32, @bitCast(t.y)))) + 1) * width + @as(usize, @intCast(@as(u32, @bitCast(t.x)))) + z];
                        if (prev_bg_pixel != bg_pixel) {
                            prev_bg_pixel = bg_pixel;
                            for (term.BG[bg_pixel]) |ci| {
                                self.terminal_buffer[buffer_len] = ci;
                                buffer_len += 1;
                            }
                        }
                        self.terminal_buffer[buffer_len] = c;
                        buffer_len += 1;
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
