const std = @import("std");
const builtin = @import("builtin");
const term = @import("term.zig");

const PX = "█";

//
// fn initBuf(self: *Self) !void {
//     const px_char_sz = px.len;
//     const px_color_sz = BG[LAST_COLOR].len + FG[LAST_COLOR].len;
//     const px_sz = px_color_sz + px_char_sz;
//     const screen_sz: u64 = @as(u64, px_sz * self.size.width * self.size.width);
//     const overflow_sz: u64 = px_char_sz * 100;
//     const bs_sz: u64 = screen_sz + overflow_sz;
//     self.buffer = try self.allocator.alloc(u8, bs_sz * 2);
// }

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
        return Self{
            .terminal = terminal,
            .allocator = allocator,
            .pixel_buffer = try allocator.alloc(u8, terminal.size.height * terminal.size.width),
            // need space for setting background and setting of foreground color for every pixel
            .terminal_buffer = try allocator.alloc(u8, (term.FG[term.LAST_COLOR].len + PX.len) * ((terminal.size.height * terminal.size.width) + 100)),
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
        var previous_pixel: u8 = 0;
        // each pixel is an index into the possible 256 colors
        for (self.pixel_buffer) |pixel| {
            if (previous_pixel != pixel) {
                previous_pixel = pixel;
                for (term.FG[pixel]) |c| {
                    self.terminal_buffer[buffer_len] = c;
                    buffer_len += 1;
                }
            }
            for (PX) |c| {
                self.terminal_buffer[buffer_len] = c;
                buffer_len += 1;
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
    try graphics.draw_rect(85, 8, 3, 1, 128, 75, 0);
    try graphics.flip();
    _ = try std.io.getStdIn().reader().readByte();
    try graphics.deinit();
    if (gpa.deinit() == .leak) {
        std.debug.print("Leaked!\n", .{});
    }
}
