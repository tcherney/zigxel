const std = @import("std");
const term = @import("term.zig");

const PX = "▀";
//▀█

pub const Graphics = struct {
    ascii_based: bool = false,
    terminal: term.Term = undefined,
    pixel_buffer: []u8 = undefined,
    terminal_buffer: []u8 = undefined,
    allocator: std.mem.Allocator = undefined,
    bg_color_indx: u8 = undefined,
    const Self = @This();
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
            .terminal_buffer = try allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + PX.len + term.BG[term.LAST_COLOR].len) * ((terminal.size.height * terminal.size.width) + 100)),
        };
    }

    pub fn deinit(self: *Self) !void {
        self.allocator.free(self.pixel_buffer);
        self.allocator.free(self.terminal_buffer);
        try self.terminal.deinit();
    }

    pub fn set_bg(self: *Self, r: u8, g: u8, b: u8) !void {
        self.bg_color_indx = @as(u8, @intCast(self.terminal.rgb_256(r, g, b)));
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i] = self.bg_color_indx;
        }
        try self.terminal.out(term.BG[self.bg_color_indx]);
    }

    pub fn draw_rect(self: *Self, x: usize, y: usize, w: usize, h: usize, r: u8, g: u8, b: u8) !void {
        const color_indx = @as(u8, @intCast(self.terminal.rgb_256(r, g, b)));
        for (y..y + h) |j| {
            for (x..x + w) |i| {
                self.pixel_buffer[j * self.terminal.size.width + i] = color_indx;
            }
        }
    }

    pub fn flip(self: *Self) !void {
        try self.terminal.out(term.SCREEN_CLEAR);
        try self.terminal.out(term.CURSOR_HOME);
        // fill terminal buffer with pixel colors
        var buffer_len: usize = 0;
        var prev_fg_pixel: u8 = 0;
        var prev_bg_pixel: u8 = 0;
        var j: usize = 0;
        var i: usize = 0;
        const width = self.terminal.size.width;
        const height = self.terminal.size.height * 2;
        // each pixel is an index into the possible 256 colors
        while (j < height) : (j += 2) {
            i = 0;
            while (i < width) : (i += 1) {
                const fg_pixel = self.pixel_buffer[j * width + i];
                const bg_pixel = self.pixel_buffer[(j + 1) * width + i];
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
                // can render with space
                if (fg_pixel == bg_pixel) {
                    self.terminal_buffer[buffer_len] = ' ';
                    buffer_len += 1;
                } else {
                    for (PX) |c| {
                        self.terminal_buffer[buffer_len] = c;
                        buffer_len += 1;
                    }
                }
            }
        }
        try self.terminal.out(self.terminal_buffer[0..buffer_len]);
    }
};

test "square" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var graphics = try Graphics.init(allocator);
    try graphics.set_bg(0, 0, 0);
    try graphics.draw_rect(50, 10, 5, 5, 255, 255, 0);
    try graphics.draw_rect(60, 8, 2, 3, 0, 255, 255);
    try graphics.draw_rect(60, 8, 3, 1, 128, 75, 0);
    try graphics.draw_rect(95, 15, 2, 1, 255, 128, 0);
    try graphics.draw_rect(75, 10, 1, 1, 255, 128, 255);
    try graphics.flip();
    _ = try std.io.getStdIn().reader().readByte();
    try graphics.deinit();
    if (gpa.deinit() == .leak) {
        std.debug.print("Leaked!\n", .{});
    }
}
