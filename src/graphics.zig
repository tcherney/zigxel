const std = @import("std");
const ascii_renderer = @import("ascii_renderer.zig");
const pixel_renderer = @import("pixel_renderer.zig");
const graphics_enums = @import("graphics_enums.zig");

pub const GraphicsType = graphics_enums.GraphicsType;
pub const RendererType = graphics_enums.RendererType;
pub const ColorMode = graphics_enums.ColorMode;
pub const PixelRenderer = pixel_renderer.PixelRenderer;
pub const AsciiRenderer = ascii_renderer.AsciiRenderer;

const GRAPHICS_LOG = std.log.scoped(.graphics);
pub const Error = ascii_renderer.Error || pixel_renderer.Error;
pub const Graphics = union(enum) {
    pixel: PixelRenderer,
    ascii: AsciiRenderer,
    pub fn init(allocator: std.mem.Allocator, renderer_type: RendererType, graphics_type: GraphicsType, color_type: ColorMode) Error!Graphics {
        switch (renderer_type) {
            .pixel => {
                return .{
                    .pixel = try PixelRenderer.init(allocator, graphics_type, color_type),
                };
            },
            .ascii => {
                return .{
                    .ascii = try AsciiRenderer.init(allocator, color_type),
                };
            },
        }
    }

    pub fn deinit(self: *Graphics) Error!void {
        switch (self.*) {
            inline else => |*g| {
                try g.deinit();
            },
        }
    }
};
