pub const RendererType = enum { pixel, ascii, sixel };
pub const ColorMode = enum {
    color_256,
    color_true,
};
pub const GraphicsType = enum { _2d, _3d };
pub const TerminalType = enum { wasm, native };
pub const ThreadingSupport = enum { single, multi };
pub const SixelWidth = 10;
pub const SixelHeight = 10;

/// Represents a pixel color in either 256 color mode or true color mode. In 256 color mode, the pixel is represented by a single byte that is an index into a color palette. In true color mode, the pixel is represented by three bytes for the red, green, and blue components of the color. The `indx` field is used to store the original index of the color in the palette when converting from 256 color mode to true color mode, so that it can be converted back if needed.
pub const PixelType = union(enum) {
    color_256: u8,
    color_true: struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, indx: u8 = 0 },
    pub fn eql(self: *const PixelType, other: PixelType) bool {
        switch (self.*) {
            .color_256 => |p| {
                return p == other.color_256;
            },
            .color_true => |p| {
                return p.r == other.color_true.r and p.g == other.color_true.g and p.b == other.color_true.b;
            },
        }
    }
};
