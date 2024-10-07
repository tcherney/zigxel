const std = @import("std");
const texture = @import("texture.zig");
const image = @import("image");

pub const Texture = texture.Texture;

pub const AssetManager = struct {
    textures: std.StringHashMap(Texture),
    allocator: std.mem.Allocator,
    const Self = @This();
    pub const Error = error{TextureNotLoaded} || Texture.Error || std.mem.Allocator.Error || image.Error;
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .textures = std.StringHashMap(Texture).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn get(self: *Self, asset_name: []const u8) Error!*Texture {
        const entry = self.textures.getEntry(asset_name);
        if (entry) |e| {
            return e.value_ptr;
        } else {
            return Error.TextureNotLoaded;
        }
    }

    pub fn load(self: *Self, asset_name: []const u8, image_path: []const u8) Error!void {
        const last_indx = std.mem.lastIndexOf(u8, image_path, ".");
        if (last_indx) |indx| {
            const img_ext = image_path[indx + 1 ..];
            if (std.mem.eql(u8, img_ext, "png") or std.mem.eql(u8, img_ext, "PNG")) {
                var img: image.Image(image.PNGImage) = image.Image(image.PNGImage){};
                try img.load(image_path, self.allocator);
                const entry = try self.textures.getOrPut(asset_name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Texture.init(self.allocator);
                    try entry.value_ptr.load_image(img);
                }
                img.deinit();
            } else if (std.mem.eql(u8, img_ext, "bmp") or std.mem.eql(u8, img_ext, "BMP")) {
                var img: image.Image(image.BMPImage) = image.Image(image.BMPImage){};
                try img.load(image_path, self.allocator);
                const entry = try self.textures.getOrPut(asset_name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Texture.init(self.allocator);
                    try entry.value_ptr.load_image(img);
                }
                img.deinit();
            } else if (std.mem.eql(u8, img_ext, "jpg") or std.mem.eql(u8, img_ext, "JPG") or std.mem.eql(u8, img_ext, "jpeg") or std.mem.eql(u8, img_ext, "JPEG")) {
                var img: image.Image(image.JPEGImage) = image.Image(image.JPEGImage){};
                try img.load(image_path, self.allocator);
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
        var val_iter = self.textures.valueIterator();
        var iter: ?*Texture = val_iter.next();
        while (iter != null) {
            iter.?.deinit();
            iter = val_iter.next();
        }
        self.textures.deinit();
    }
};
