const std = @import("std");
const texture = @import("texture.zig");
const image = @import("image");
const _graphics = @import("graphics.zig");
const font = @import("font.zig");

pub const Texture = texture.Texture;
pub const Image = image.Image;
pub const Font = font.Font;
pub const Graphics = _graphics.Graphics;

/// General asset manager that facilitates the access of different asset types using string names,
/// this ensures all assets being used by multiple objects get allocated only once
//TODO manage more assests sound
pub const AssetManager = struct {
    textures: std.StringHashMap(Texture),
    font_textures: std.StringHashMap(*Texture),
    fonts: std.StringHashMap(Font),
    strings: []const []const u8 = &[_][]const u8{
        "Start",
    },
    allocator: std.mem.Allocator,
    pub const StringIndex = enum(usize) {
        START = 0,
    };
    const Self = @This();
    pub const Error = error{ TextureNotLoaded, FontNotLoaded } || Texture.Error || std.mem.Allocator.Error || image.Image.Error || Font.Error;
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .textures = std.StringHashMap(Texture).init(allocator),
            .font_textures = std.StringHashMap(*Texture).init(allocator),
            .fonts = std.StringHashMap(Font).init(allocator),
            .allocator = allocator,
        };
    }

    /// Gets a font from the asset manager using the asset name. If the font is not found, it returns an error.
    pub fn get_font(self: *Self, asset_name: []const u8) Error!*Font {
        const entry = self.fonts.getEntry(asset_name);
        if (entry) |e| {
            return e.value_ptr;
        } else {
            return Error.FontNotLoaded;
        }
    }

    /// Loads a font from a file and stores it in the asset manager with the given asset name.
    pub fn load_font(self: *Self, asset_name: []const u8, font_path: []const u8, font_size: u16, graphics: *Graphics) Error!void {
        const entry = try self.fonts.getOrPut(asset_name);
        if (!entry.found_existing) {
            entry.value_ptr.* = Font.init(self.allocator);
            switch (graphics.*) {
                .pixel => |*g| try entry.value_ptr.load(font_path, font_size, g),
                else => unreachable,
            }
        }
    }

    /// Loads a font texture from a string using the specified font. The resulting texture is stored in the asset manager with the given string as the key.
    /// This allows for dynamic generation of font textures based on the characters needed, and ensures that each unique string is only rendered to a texture once,
    /// saving memory and processing time.
    pub fn load_font_texture(self: *Self, str: []const u8, font_name: []const u8) Error!void {
        const entry = try self.font_textures.getOrPut(str);
        if (!entry.found_existing) {
            const f = try self.get_font(font_name);
            entry.value_ptr.* = try f.texture_from_string(str);
        }
    }

    /// Gets a texture from the asset manager using the asset name. If the texture is not found, it returns an error.
    /// It first checks the textures hashmap, and if it doesn't find it there, it checks the font_textures hashmap.
    /// This allows for both regular textures and font textures to be accessed using the same function.
    pub fn get_texture(self: *Self, asset_name: []const u8) Error!*Texture {
        const entry = self.textures.getEntry(asset_name);
        if (entry) |e| {
            return e.value_ptr;
        } else {
            const font_entry = self.font_textures.getEntry(asset_name);
            if (font_entry) |e| {
                return e.value_ptr.*;
            } else {
                return Error.TextureNotLoaded;
            }
        }
    }

    /// Loads a texture from an image file and stores it in the asset manager with the given asset name.
    /// If the asset name already exists, it will not load the texture again and will keep the existing one.
    /// The image format is determined by the file extension, and supports PNG, BMP, and JPEG formats.
    pub fn load_texture(self: *Self, asset_name: []const u8, image_path: []const u8) Error!void {
        const last_indx = std.mem.lastIndexOf(u8, image_path, ".");
        if (last_indx) |indx| {
            const img_ext = image_path[indx + 1 ..];
            if (std.mem.eql(u8, img_ext, "png") or std.mem.eql(u8, img_ext, "PNG")) {
                var img: Image = try Image.init_load(self.allocator, image_path, .PNG);
                const entry = try self.textures.getOrPut(asset_name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Texture.init(self.allocator);
                    try entry.value_ptr.load_image(img);
                }
                img.deinit();
            } else if (std.mem.eql(u8, img_ext, "bmp") or std.mem.eql(u8, img_ext, "BMP")) {
                var img: Image = try Image.init_load(self.allocator, image_path, .BMP);
                const entry = try self.textures.getOrPut(asset_name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Texture.init(self.allocator);
                    try entry.value_ptr.load_image(img);
                }
                img.deinit();
            } else if (std.mem.eql(u8, img_ext, "jpg") or std.mem.eql(u8, img_ext, "JPG") or std.mem.eql(u8, img_ext, "jpeg") or std.mem.eql(u8, img_ext, "JPEG")) {
                var img: Image = try Image.init_load(self.allocator, image_path, .JPEG);
                const entry = try self.textures.getOrPut(asset_name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Texture.init(self.allocator);
                    try entry.value_ptr.load_image(img);
                }
                img.deinit();
            }
        }
    }

    pub fn deinit(self: *Self) void {
        var tex_val_iter = self.textures.valueIterator();
        var tex_iter: ?*Texture = tex_val_iter.next();
        while (tex_iter != null) {
            tex_iter.?.deinit();
            tex_iter = tex_val_iter.next();
        }
        var font_val_iter = self.fonts.valueIterator();
        var font_iter: ?*Font = font_val_iter.next();
        while (font_iter != null) {
            font_iter.?.deinit();
            font_iter = font_val_iter.next();
        }
        var font_tex_val_iter = self.font_textures.valueIterator();
        var font_tex_iter: ?**Texture = font_tex_val_iter.next();
        while (font_tex_iter != null) {
            font_tex_iter.?.*.deinit();
            self.allocator.destroy(font_tex_iter.?.*);
            font_tex_iter = font_tex_val_iter.next();
        }
        self.font_textures.deinit();
        self.textures.deinit();
        self.fonts.deinit();
    }
};
