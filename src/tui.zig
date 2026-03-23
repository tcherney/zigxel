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
//TODO add layout system, start with grid, row, column, add alignment options, padding, margins
/// TUI designed to provide a simple way to create interactive terminal interfaces. It supports both pixel and ascii rendering, and is designed to be used with the zig-terminal library for input handling. It is also designed to be used with the zig-image library for pixel rendering, but can be used with any graphics library that implements the Graphics interface.
pub fn TUI(comptime State: type) type {
    return struct {
        allocator: Allocator,
        layout: Layout,
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

            pub fn draw(self: *Button, renderer: *Graphics, dest: ?Texture, offset_x: usize, offset_y: usize, viewport_x: i32, viewport_y: i32) Button.Error!void {
                const viewport_x_usize = if (WASM) @as(usize, @bitCast(viewport_x)) else @as(usize, @bitCast(@as(i64, @intCast(viewport_x))));
                const viewport_y_usize = if (WASM) @as(usize, @bitCast(viewport_y)) else @as(usize, @bitCast(@as(i64, @intCast(viewport_y))));
                if (self.renderer_type == .pixel) {
                    const y_start = viewport_y_usize + self.y + offset_y;
                    for (y_start..y_start + self.height) |i| {
                        const i_i32 = if (WASM) @as(i32, @bitCast(i)) else @as(i32, @intCast(@as(i64, @bitCast(i))));
                        for (viewport_x_usize + self.x..viewport_x_usize + self.x + self.width + offset_x) |j| {
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
                    for (viewport_y_usize + self.y + offset_y..viewport_y_usize + self.y + self.height + offset_y) |i| {
                        const i_i32 = if (WASM) @as(i32, @bitCast(i)) else @as(i32, @intCast(@as(i64, @bitCast(i))));
                        for (viewport_x_usize + self.x + offset_x..viewport_x_usize + self.x + self.width + offset_x) |j| {
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
        pub const Layout = union(enum) {
            absolute: AbsoluteLayout,
            grid: GridLayout,
            row: RowLayout,
            column: ColumnLayout,
            pub const AbsoluteLayout = struct {
                allocator: Allocator,
                x: usize,
                y: usize,
                items: std.ArrayList(Item),
                pub const Error = error{} || Allocator.Error || Item.Error;
                pub fn init(allocator: Allocator, x: usize, y: usize) AbsoluteLayout.Error!AbsoluteLayout {
                    return .{
                        .allocator = allocator,
                        .x = x,
                        .y = y,
                        .items = std.ArrayList(Item).init(allocator),
                    };
                }

                pub fn deinit(self: *AbsoluteLayout) void {
                    for (0..self.items.items.len) |i| {
                        self.items.items[i].deinit();
                    }
                    self.items.deinit();
                }

                pub fn set_on_click(_: *AbsoluteLayout, item: *Item, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                    switch (item.*) {
                        inline else => |*i| i.set_on_click(CONTEXT_TYPE, func, context),
                    }
                }

                //TODO have to modifiy the draw function to take relative x,y and add it to item positions
                pub fn draw(self: *AbsoluteLayout, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) AbsoluteLayout.Error!void {
                    for (0..self.items.items.len) |i| {
                        try self.items.items[i].draw(renderer, dest, self.x, self.y, viewport_x, viewport_y, state);
                    }
                }
            };
            pub const GridLayout = struct {
                allocator: Allocator,
                x: usize,
                y: usize,
                rows: usize,
                columns: usize,
                items: std.ArrayList(Item),
                pub const Error = error{} || Allocator.Error || Item.Error;
                pub fn init(allocator: Allocator, x: usize, y: usize, rows: usize, columns: usize) GridLayout.Error!GridLayout {
                    return .{
                        .allocator = allocator,
                        .x = x,
                        .y = y,
                        .rows = rows,
                        .columns = columns,
                        .items = std.ArrayList(Item).init(allocator),
                    };
                }

                pub fn deinit(self: *GridLayout) void {
                    for (0..self.items.items.len) |i| {
                        self.items.items[i].deinit();
                    }
                    self.items.deinit();
                }

                pub fn set_on_click(_: *GridLayout, item: *Item, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                    switch (item.*) {
                        inline else => |*i| i.set_on_click(CONTEXT_TYPE, func, context),
                    }
                }

                //TODO calculate item positions based on grid layout and viewport
                pub fn draw(self: *GridLayout, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) GridLayout.Error!void {
                    const prev_x_end: i32 = self.x;
                    var prev_y_end: i32 = self.y;
                    //TODO have to adjust offset x every column increment and reset back to self.x when column resets
                    //TODO have to keep offset y to previous end and track the element that extends the furthest
                    //TODO then use that for next row offset
                    for (0..self.rows) |r| {
                        const curr_y_end = prev_y_end;
                        var curr_x_end = prev_x_end;
                        for (0..self.columns) |c| {
                            const index = r * self.columns + c;
                            if (index >= self.items.items.len) break;
                            try self.items.items[index].draw(renderer, dest, curr_y_end, prev_y_end, viewport_x, viewport_y, state);
                            switch (self.items.items[index]) {
                                inline else => |*item| {
                                    prev_y_end = @max(prev_y_end, curr_y_end + @as(i32, @bitCast(item.y + item.height)));
                                    curr_x_end = curr_x_end + @as(i32, @bitCast(item.x + item.width));
                                },
                            }
                        }
                    }
                }
            };
            pub const RowLayout = struct {
                allocator: Allocator,
                x: usize,
                y: usize,
                rows: usize,
                items: std.ArrayList(Item),
                pub const Error = error{} || Allocator.Error || Item.Error;
                pub fn init(allocator: Allocator, x: usize, y: usize, rows: usize) RowLayout.Error!RowLayout {
                    return .{
                        .allocator = allocator,
                        .x = x,
                        .y = y,
                        .rows = rows,
                        .items = std.ArrayList(Item).init(allocator),
                    };
                }

                pub fn deinit(self: *RowLayout) void {
                    for (0..self.items.items.len) |i| {
                        self.items.items[i].deinit();
                    }
                    self.items.deinit();
                }

                pub fn set_on_click(_: *RowLayout, item: *Item, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                    switch (item.*) {
                        inline else => |*i| i.set_on_click(CONTEXT_TYPE, func, context),
                    }
                }

                //TODO calculate item positions based on grid layout and viewport
                pub fn draw(self: *RowLayout, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) RowLayout.Error!void {
                    for (0..self.items.items.len) |i| {
                        try self.items.items[i].draw(renderer, dest, self.x, self.y, viewport_x, viewport_y, state);
                    }
                }
            };
            pub const ColumnLayout = struct {
                allocator: Allocator,
                x: usize,
                y: usize,
                columns: usize,
                items: std.ArrayList(Item),
                pub const Error = error{} || Allocator.Error || Item.Error;
                pub fn init(allocator: Allocator, x: usize, y: usize, columns: usize) ColumnLayout.Error!ColumnLayout {
                    return .{
                        .allocator = allocator,
                        .x = x,
                        .y = y,
                        .columns = columns,
                        .items = std.ArrayList(Item).init(allocator),
                    };
                }

                pub fn deinit(self: *ColumnLayout) void {
                    for (0..self.items.items.len) |i| {
                        self.items.items[i].deinit();
                    }
                    self.items.deinit();
                }

                pub fn set_on_click(_: *ColumnLayout, item: *Item, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                    switch (item.*) {
                        inline else => |*i| i.set_on_click(CONTEXT_TYPE, func, context),
                    }
                }

                //TODO calculate item positions based on column layout and viewport
                pub fn draw(self: *ColumnLayout, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) ColumnLayout.Error!void {
                    for (0..self.items.items.len) |i| {
                        try self.items.items[i].draw(renderer, dest, self.x, self.y, viewport_x, viewport_y, state);
                    }
                }
            };
            pub const Error = error{} || AbsoluteLayout.Error || GridLayout.Error || ColumnLayout.Error || Item.Error;
            pub fn set_on_click(self: *Layout, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                switch (self.*) {
                    inline else => |*layout| layout.set_on_click(CONTEXT_TYPE, func, context),
                }
            }
            pub fn draw(self: *Layout, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32) Layout.Error!void {
                switch (self.*) {
                    inline else => |*layout| {
                        try layout.draw(renderer, dest, viewport_x, viewport_y);
                    },
                }
            }
            pub fn deinit(self: *Layout) void {
                switch (self.*) {
                    inline else => |*layout| layout.deinit(),
                }
            }
        };
        /// Item is a union of all possible UI elements. It provides a common interface for drawing and handling input for all elements, allowing them to be stored in a single list and iterated over for drawing and input handling.
        pub const Item = union(enum) {
            button: Button,
            pub const Error = error{} || Button.Error;
            pub fn set_on_click(self: *Item, comptime CONTEXT_TYPE: type, func: anytype, context: *CONTEXT_TYPE) void {
                switch (self.*) {
                    inline else => |*item| item.set_on_click(CONTEXT_TYPE, func, context),
                }
            }
            pub fn draw(self: *Item, renderer: *Graphics, dest: ?Texture, offset_x: usize, offset_y: usize, viewport_x: i32, viewport_y: i32, state: State) Item.Error!void {
                switch (self.*) {
                    inline else => |*item| {
                        if (state == item.state) try item.draw(renderer, dest, offset_x, offset_y, viewport_x, viewport_y);
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
        pub const Error = error{} || Layout.Error;
        pub fn init(allocator: Allocator, renderer_type: RendererType) Error!Self {
            return .{
                .allocator = allocator,
                .layout = .{ .absolute = try Layout.AbsoluteLayout.init(allocator, 0, 0) },
                .renderer_type = renderer_type,
            };
        }
        pub fn deinit(self: *Self) void {
            switch (self.layout) {
                inline else => |*layout| {
                    layout.deinit();
                },
            }
        }
        pub fn mouse_input(self: *Self, x: i32, y: i32, state: State) void {
            switch (self.layout) {
                inline else => |*layout| {
                    for (0..layout.items.items.len) |i| {
                        switch (layout.items.items[i]) {
                            .button => |button| {
                                if (state != button.state or button.on_click == null) continue;
                                button.mouse_input(x, y);
                            },
                        }
                    }
                },
            }
        }
        //TODO add more elements
        pub fn add_button(self: *Self, x: usize, y: usize, width: ?usize, height: ?usize, border_color: Pixel, background_color: Pixel, text_color: Pixel, text: []const u8, state: State) Error!void {
            //TODO find out why my text ptr is getting clobbered in wasm
            switch (self.layout) {
                inline else => |*layout| {
                    try layout.items.append(.{ .button = try Button.init(self.allocator, x, y, width, height, border_color, background_color, text_color, text, state, self.renderer_type) });
                    TUI_LOG.info("Button {any}\n", .{layout.items.items[layout.items.items.len - 1]});
                },
            }
        }

        pub fn draw(self: *Self, renderer: *Graphics, dest: ?Texture, viewport_x: i32, viewport_y: i32, state: State) Error!void {
            switch (self.layout) {
                inline else => |*layout| {
                    try layout.draw(renderer, dest, viewport_x, viewport_y, state);
                },
            }
        }
    };
}
