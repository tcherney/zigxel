const std = @import("std");
const ascii_graphics = @import("ascii_graphics.zig");
const graphics = @import("graphics.zig");
const common = @import("common");
const texture = @import("texture.zig");

pub const GraphicsType = enum {
    ascii,
    pixel,
};

pub const Pixel = common.Pixel;
pub const Allocator = std.mem.Allocator;
pub const Texture = texture.Texture;
const TUI_LOG = std.log.scoped(.tui);

pub fn TUI(comptime graphics_type: GraphicsType) type {
    return struct {
        allocator: Allocator,
        buttons: std.ArrayList(Button),
        pub const Graphics = if (graphics_type == .ascii) ascii_graphics.AsciiGraphics(.color_true) else graphics.Graphics(._2d, .color_true);
        pub const Button = struct {
            width: usize,
            height: usize,
            x: usize,
            y: usize,
            border_color: Pixel,
            background_color: Pixel,
            text_color: Pixel,
            text: []const u8,
            allocator: Allocator,
            pub const Error = error{} || Allocator.Error || ascii_graphics.Error || graphics.Error;
            pub fn init(allocator: Allocator, x: usize, y: usize, width: usize, height: usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8) Button.Error!Button {
                return .{
                    .allocator = allocator,
                    .x = x,
                    .y = y,
                    .width = width,
                    .height = height,
                    .border_color = border_color,
                    .background_color = background_color,
                    .text_color = text_color,
                    .text = try allocator.dupe(u8, text),
                };
            }

            pub fn deinit(self: *Button) void {
                self.allocator.free(self.text);
            }

            pub fn draw(self: *Button, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32) Button.Error!void {
                const viewport_x_usize = @as(usize, @bitCast(@as(i64, @intCast(viewport_x))));
                const viewport_y_usize = @as(usize, @bitCast(@as(i64, @intCast(viewport_y))));
                if (graphics_type == .pixel) {
                    for (viewport_y_usize + self.y..viewport_y_usize + self.y + self.height) |i| {
                        for (viewport_x_usize + self.x..viewport_x_usize + self.x + self.width) |j| {
                            renderer.draw_pixel(@as(i32, @intCast(@as(i64, @bitCast(j)))), @as(i32, @intCast(@as(i64, @bitCast(i)))), self.background_color, dest);
                        }
                    }
                    const mid_x = self.x + (self.width / 2) - (self.text.len / 2);
                    const mid_y = self.y + (self.height / 2);
                    try renderer.draw_text(self.text, @as(i32, @intCast(@as(i64, @bitCast(mid_x)))), @as(i32, @intCast(@as(i64, @bitCast(mid_y)))), self.text_color.get_r(), self.text_color.get_g(), self.text_color.get_b());
                } else {
                    //TODO
                }
            }
        };
        pub const Self = @This();
        pub const Error = error{} || Button.Error;
        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .buttons = std.ArrayList(Button).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            for (0..self.buttons.items.len) |i| {
                self.buttons.items[i].deinit();
            }
            self.buttons.deinit();
        }
        pub fn add_button(self: *Self, x: usize, y: usize, width: usize, height: usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8) Error!void {
            try self.buttons.append(try Button.init(self.allocator, x, y, width, height, border_color, background_color, text_color, text));
            TUI_LOG.info("Button {any}\n", .{self.buttons.items[self.buttons.items.len - 1]});
        }
    };
}
