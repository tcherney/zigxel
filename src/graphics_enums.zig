pub const RendererType = enum { pixel, ascii, sixel };
pub const ColorMode = enum {
    color_256,
    color_true,
};
pub const GraphicsType = enum { _2d, _3d };
pub const TerminalType = enum { wasm, native };

pub const PixelType = union(enum) {
    color_256: u8,
    color_true: struct { r: u8 = 0, g: u8 = 0, b: u8 = 0 },
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
