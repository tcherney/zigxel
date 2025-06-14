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
        items: std.ArrayList(Item),
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
            on_click: ?OnClickCallback = null,
            const OnClickCallback = common.CallbackNoData();
            pub const Error = error{} || Allocator.Error || ascii_graphics.Error || graphics.Error;
            pub fn init(allocator: Allocator, x: usize, y: usize, width: ?usize, height: ?usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8) Button.Error!Button {
                const h = if (height != null) height.? else 2;
                const w = if (width != null) width.? else text.len + 2;
                return .{
                    .allocator = allocator,
                    .x = x,
                    .y = y,
                    .width = w,
                    .height = h,
                    .border_color = border_color,
                    .background_color = background_color,
                    .text_color = text_color,
                    .text = try allocator.dupe(u8, text),
                };
            }

            pub fn deinit(self: *Button) void {
                self.allocator.free(self.text);
            }

            pub fn set_on_click(self: *Button, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                self.on_click = OnClickCallback.init(CONTEXT_TYPE, func, context);
            }

            pub fn mouse_input(self: *const Button, x: i32, y: i32) void {
                const x_usize = @as(usize, @bitCast(@as(i64, @intCast(x))));
                const y_usize = @as(usize, @bitCast(@as(i64, @intCast(y))));
                TUI_LOG.info("Checking if {d},{d} in {any}\n", .{ x, y, self });
                if (x_usize >= self.x and x_usize <= self.x + self.width and y_usize >= self.y and y_usize <= self.y + self.height) {
                    self.on_click.?.call();
                }
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
        pub const Item = union(enum) {
            button: Button,
            pub const Error = error{} || Button.Error;
            pub fn set_on_click(self: *Item, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                switch (self.*) {
                    inline else => |*item| item.set_on_click(CONTEXT_TYPE, func, context),
                }
            }
            pub fn draw(self: *Item, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32) Item.Error!void {
                switch (self.*) {
                    inline else => |*item| try item.draw(renderer, dest, viewport_x, viewport_y),
                }
            }
            pub fn deinit(self: *Item) void {
                switch (self.*) {
                    inline else => |*item| item.deinit(),
                }
            }
        };
        pub const Self = @This();
        pub const Error = error{} || Item.Error;
        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .items = std.ArrayList(Item).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            for (0..self.items.items.len) |i| {
                self.items.items[i].deinit();
            }
            self.items.deinit();
        }
        pub fn mouse_input(self: *Self, x: i32, y: i32) void {
            for (0..self.items.items.len) |i| {
                switch (self.items.items[i]) {
                    .button => |button| {
                        button.mouse_input(x, y);
                    },
                }
            }
        }
        pub fn add_button(self: *Self, x: usize, y: usize, width: ?usize, height: ?usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8) Error!void {
            try self.items.append(.{ .button = try Button.init(self.allocator, x, y, width, height, border_color, background_color, text_color, text) });
            TUI_LOG.info("Button {any}\n", .{self.items.items[self.items.items.len - 1]});
        }

        pub fn draw(self: *Self, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32) Error!void {
            for (0..self.items.items.len) |i| {
                try self.items.items[i].draw(renderer, dest, viewport_x, viewport_y);
            }
        }
    };
}
