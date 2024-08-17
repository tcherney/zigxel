const std = @import("std");
const term = @import("term.zig");

//https://www.compart.com/en/unicode/U+2580
const UPPER_PX = "▀";
//const FULL_PX = "█";
const LOWER_PX = "▄";
//▀█▄

pub const Graphics = struct {
    ascii_based: bool = false,
    terminal: term.Term = undefined,
    pixel_buffer: []u8 = undefined,
    last_frame: ?[]u8 = null,
    terminal_buffer: []u8 = undefined,
    text_to_render: std.ArrayList(Text) = undefined,
    allocator: std.mem.Allocator = undefined,
    const Self = @This();
    pub const Text = struct { x: usize, y: usize, r: u8, g: u8, b: u8, value: []const u8 };
    pub fn init(allocator: std.mem.Allocator) !Graphics {
        const terminal = try term.Term.init(allocator);
        var pixel_buffer = try allocator.alloc(u8, terminal.size.height * terminal.size.width * 2);
        for (0..pixel_buffer.len) |i| {
            pixel_buffer[i] = 0;
        }
        return Self{
            .terminal = terminal,
            .allocator = allocator,
            .pixel_buffer = pixel_buffer,
            // need space for setting background and setting of foreground color for every pixel
            .terminal_buffer = try allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + UPPER_PX.len + term.BG[term.LAST_COLOR].len) * ((terminal.size.height * terminal.size.width) + 100)),
            .text_to_render = std.ArrayList(Text).init(allocator),
        };
    }

    pub fn deinit(self: *Self) !void {
        self.allocator.free(self.pixel_buffer);
        self.allocator.free(self.terminal_buffer);
        try self.terminal.deinit();
        self.allocator.free(self.last_frame.?);
        self.text_to_render.deinit();
    }

    pub fn set_bg(self: *Self, r: u8, g: u8, b: u8) !void {
        const bg_color_indx = @as(u8, @intCast(self.terminal.rgb_256(r, g, b)));
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i] = bg_color_indx;
        }
    }

    pub fn draw_rect(self: *Self, x: usize, y: usize, w: usize, h: usize, r: u8, g: u8, b: u8) !void {
        const color_indx = @as(u8, @intCast(self.terminal.rgb_256(r, g, b)));
        for (y..y + h) |j| {
            for (x..x + w) |i| {
                self.pixel_buffer[j * self.terminal.size.width + i] = color_indx;
            }
        }
    }

    pub fn draw_text(self: *Self, value: []const u8, x: usize, y: usize, r: u8, g: u8, b: u8) !void {
        std.debug.print("{s} with len {d}\n", .{ value, value.len });
        try self.text_to_render.append(Text{ .x = x, .y = if (y % 2 == 1) y - 1 else y, .r = r, .g = g, .b = b, .value = value });
    }

    pub fn flip(self: *Self) !void {
        // fill terminal buffer with pixel colors
        var buffer_len: usize = 0;
        var prev_fg_pixel: u8 = 0;
        var prev_bg_pixel: u8 = 0;
        var j: usize = 0;
        var i: usize = 0;
        const width = self.terminal.size.width;
        const height = self.terminal.size.height * 2;
        var dirty_pixel_buffer: [12]u8 = undefined;
        var first_render: bool = false;
        if (self.last_frame == null) {
            try self.terminal.out(term.CURSOR_HOME);
            self.last_frame = try self.allocator.alloc(u8, self.pixel_buffer.len);
            for (0..self.pixel_buffer.len) |pixel| {
                self.last_frame.?[pixel] = self.pixel_buffer[pixel];
            }
            first_render = true;
        }
        // each pixel is an index into the possible 256 colors
        while (j < height) : (j += 2) {
            i = 0;
            while (i < width) : (i += 1) {
                if (!first_render and self.pixel_buffer[j * width + i] == self.last_frame.?[j * width + i] and self.pixel_buffer[(j + 1) * width + i] == self.last_frame.?[(j + 1) * width + i]) {
                    continue;
                }
                if (!first_render) {
                    self.last_frame.?[j * width + i] = self.pixel_buffer[j * width + i];
                    self.last_frame.?[(j + 1) * width + i] = self.pixel_buffer[(j + 1) * width + i];
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
                for (try std.fmt.bufPrint(&dirty_pixel_buffer, term.CSI ++ "{d};{d}H", .{ (t.y / 2) + 1, t.x + 1 })) |c| {
                    self.terminal_buffer[buffer_len] = c;
                    buffer_len += 1;
                }
                const fg_pixel = @as(u8, @intCast(self.terminal.rgb_256(t.r, t.g, t.b)));

                if (prev_fg_pixel != fg_pixel) {
                    prev_fg_pixel = fg_pixel;
                    for (term.FG[fg_pixel]) |c| {
                        self.terminal_buffer[buffer_len] = c;
                        buffer_len += 1;
                    }
                }

                for (t.value, 0..) |c, z| {
                    const bg_pixel = self.pixel_buffer[(t.y + 1) * width + t.x + z];
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

                text = self.text_to_render.popOrNull();
            }
        }

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
