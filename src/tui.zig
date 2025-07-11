const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const common = @import("common");
const texture = @import("texture.zig");

pub const RendererType = graphics.RendererType;
pub const Graphics = graphics.Graphics;
pub const Pixel = common.Pixel;
pub const Allocator = std.mem.Allocator;
pub const Texture = texture.Texture;
const TUI_LOG = std.log.scoped(.tui);

pub const WASM: bool = if (builtin.os.tag == .emscripten or builtin.os.tag == .wasi) true else false;

//TODO add more elements (textfields??) add key navigation (keeping track of current selected element)
pub fn TUI(comptime State: type) type {
    return struct {
        allocator: Allocator,
        items: std.ArrayList(Item),
        renderer_type: RendererType,
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
            state: State,
            renderer_type: RendererType,
            const OnClickCallback = common.CallbackNoData();
            pub const Error = error{} || Allocator.Error || graphics.Error;
            pub fn init(allocator: Allocator, x: usize, y: usize, width: ?usize, height: ?usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8, state: State, renderer_type: RendererType) Button.Error!Button {
                const h: usize = if (height != null) height.? else if (renderer_type == .pixel) 2 else 1;
                const w: usize = if (width != null) width.? else text.len + 2;
                return .{
                    .allocator = allocator,
                    .x = x,
                    .y = y,
                    .width = w,
                    .height = h,
                    .border_color = border_color,
                    .background_color = background_color,
                    .text_color = text_color,
                    .text = text,
                    .state = state,
                    .renderer_type = renderer_type,
                };
            }

            pub fn deinit(_: *Button) void {}

            pub fn set_on_click(self: *Button, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                self.on_click = OnClickCallback.init(CONTEXT_TYPE, func, context);
            }

            pub fn mouse_input(self: *const Button, x: i32, y: i32) void {
                const x_usize = if (WASM) @as(usize, @bitCast(x)) else @as(usize, @bitCast(@as(i64, @intCast(x))));
                const y_usize = if (WASM) @as(usize, @bitCast(y)) else @as(usize, @bitCast(@as(i64, @intCast(y))));
                TUI_LOG.info("Checking if {d},{d} in {any}\n", .{ x, y, self });
                if (x_usize >= self.x and x_usize <= self.x + self.width and y_usize >= self.y and y_usize <= self.y + self.height) {
                    self.on_click.?.call();
                }
            }

            pub fn draw(self: *Button, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32) Button.Error!void {
                const viewport_x_usize = if (WASM) @as(usize, @bitCast(viewport_x)) else @as(usize, @bitCast(@as(i64, @intCast(viewport_x))));
                const viewport_y_usize = if (WASM) @as(usize, @bitCast(viewport_y)) else @as(usize, @bitCast(@as(i64, @intCast(viewport_y))));
                if (self.renderer_type == .pixel) {
                    const y_start = viewport_y_usize + self.y;
                    for (y_start..y_start + self.height) |i| {
                        const i_i32 = if (WASM) @as(i32, @bitCast(i)) else @as(i32, @intCast(@as(i64, @bitCast(i))));
                        for (viewport_x_usize + self.x..viewport_x_usize + self.x + self.width) |j| {
                            const j_i32 = if (WASM) @as(i32, @bitCast(j)) else @as(i32, @intCast(@as(i64, @bitCast(j))));
                            renderer.pixel.draw_pixel(j_i32, i_i32, self.background_color, dest);
                        }
                    }
                    const mid_x = self.x + (self.width / 2) - (self.text.len / 2);
                    const mid_y = self.y + (self.height / 2);
                    const mix_x_i32 = if (WASM) @as(i32, @bitCast(mid_x)) else @as(i32, @intCast(@as(i64, @bitCast(mid_x))));
                    const mid_y_i32 = if (WASM) @as(i32, @bitCast(mid_y)) else @as(i32, @intCast(@as(i64, @bitCast(mid_y))));
                    try renderer.pixel.draw_text(self.text, mix_x_i32, mid_y_i32, self.text_color.get_r(), self.text_color.get_g(), self.text_color.get_b());
                } else {
                    const mid_x = self.x + (self.width / 2) - (self.text.len / 2);
                    const mid_y = self.y + (self.height / 2);
                    var curr_char: usize = 0;
                    for (viewport_y_usize + self.y..viewport_y_usize + self.y + self.height) |i| {
                        const i_i32 = if (WASM) @as(i32, @bitCast(i)) else @as(i32, @intCast(@as(i64, @bitCast(i))));
                        for (viewport_x_usize + self.x..viewport_x_usize + self.x + self.width) |j| {
                            const j_i32 = if (WASM) @as(i32, @bitCast(j)) else @as(i32, @intCast(@as(i64, @bitCast(j))));
                            if (j >= mid_x and i >= mid_y and curr_char < self.text.len) {
                                renderer.ascii.draw_symbol_bg(j_i32, i_i32, self.text[curr_char], self.text_color, dest, self.background_color.get_r(), self.background_color.get_g(), self.background_color.get_b());
                                curr_char += 1;
                            } else {
                                renderer.ascii.draw_symbol_bg(j_i32, i_i32, ' ', self.background_color, dest, self.background_color.get_r(), self.background_color.get_g(), self.background_color.get_b());
                            }
                        }
                    }
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
            pub fn draw(self: *Item, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) Item.Error!void {
                switch (self.*) {
                    inline else => |*item| {
                        if (state == item.state) try item.draw(renderer, dest, viewport_x, viewport_y);
                    },
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
        pub fn init(allocator: Allocator, renderer_type: RendererType) Self {
            return .{
                .allocator = allocator,
                .items = std.ArrayList(Item).init(allocator),
                .renderer_type = renderer_type,
            };
        }
        pub fn deinit(self: *Self) void {
            for (0..self.items.items.len) |i| {
                self.items.items[i].deinit();
            }
            self.items.deinit();
        }
        pub fn mouse_input(self: *Self, x: i32, y: i32, state: State) void {
            for (0..self.items.items.len) |i| {
                switch (self.items.items[i]) {
                    .button => |button| {
                        if (state != button.state or button.on_click == null) continue;
                        button.mouse_input(x, y);
                    },
                }
            }
        }
        pub fn add_button(self: *Self, x: usize, y: usize, width: ?usize, height: ?usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8, state: State) Error!void {
            //TODO find out why my text ptr is getting clobbered in wasm
            try self.items.append(.{ .button = try Button.init(self.allocator, x, y, width, height, border_color, background_color, text_color, text, state, self.renderer_type) });
            TUI_LOG.info("Button {any}\n", .{self.items.items[self.items.items.len - 1]});
        }

        pub fn draw(self: *Self, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) Error!void {
            for (0..self.items.items.len) |i| {
                try self.items.items[i].draw(renderer, dest, viewport_x, viewport_y, state);
            }
        }
    };
}
