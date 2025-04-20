const std = @import("std");
const image = @import("image");

pub const Pixel = image.Pixel;

const TEXTURE_LOG = std.log.scoped(.texture);

pub const Texture = struct {
    allocator: std.mem.Allocator,
    height: u32 = undefined,
    width: u32 = undefined,
    pixel_buffer: []Pixel = undefined,
    background_pixel_buffer: []Pixel = undefined,
    is_ascii: bool = false,
    ascii_buffer: []u8 = undefined,
    alpha_index: ?u8 = null,
    loaded: bool = false,
    const Self = @This();
    pub const Error = error{} || std.mem.Allocator.Error || image.Error || std.posix.GetRandomError;
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.pixel_buffer);
        if (self.is_ascii) {
            self.allocator.free(self.ascii_buffer);
            self.allocator.free(self.background_pixel_buffer);
        }
    }

    pub fn rect(self: *Self, width: u32, height: u32, r: u8, g: u8, b: u8, a: u8) Error!void {
        self.height = height;
        self.width = width;
        if (self.loaded) {
            self.allocator.free(self.pixel_buffer);
            if (self.is_ascii) {
                self.allocator.free(self.ascii_buffer);
                self.allocator.free(self.background_pixel_buffer);
            }
        }
        self.pixel_buffer = try self.allocator.alloc(Pixel, height * width);
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i] = Pixel.init(r, g, b, a);
        }
        if (self.is_ascii) {
            self.ascii_buffer = try self.allocator.alloc(u8, height * width);
            for (0..self.ascii_buffer.len) |i| {
                self.ascii_buffer[i] = ' ';
            }
            self.background_pixel_buffer = try self.allocator.alloc(Pixel, height * width);
            for (0..self.background_pixel_buffer.len) |i| {
                self.background_pixel_buffer[i] = Pixel.init(0, 0, 0, 255);
            }
        }
        self.loaded = true;
    }

    pub fn copy(self: *Self) Error!*Self {
        var tex: *Self = try self.allocator.create(Self);
        tex.* = Self.init(self.allocator);
        tex.height = self.height;
        tex.width = self.width;
        tex.loaded = true;
        tex.pixel_buffer = try self.allocator.dupe(Pixel, self.pixel_buffer);
        if (self.is_ascii) {
            tex.ascii_buffer = try self.allocator.dupe(u8, self.ascii_buffer);
            tex.background_pixel_buffer = try self.allocator.dupe(Pixel, self.background_pixel_buffer);
            tex.is_ascii = true;
        }
        return tex;
    }

    // resize without adjusting where pixels lie
    pub fn resize(self: *Self, width: u32, height: u32) Error!void {
        TEXTURE_LOG.info("resizing from {d}x{d} to {d}x{d}\n", .{ self.width, self.height, width, height });
        var pixel_buffer = try self.allocator.alloc(Pixel, width * height);
        for (0..height) |i| {
            for (0..width) |j| {
                pixel_buffer[i * width + j] = Pixel.init(0, 0, 0, 0);
            }
        }
        for (0..self.height) |i| {
            for (0..self.width) |j| {
                if (i * width + j > pixel_buffer.len) continue;
                pixel_buffer[i * width + j] = self.pixel_buffer[i * self.width + j];
            }
        }
        self.allocator.free(self.pixel_buffer);
        self.pixel_buffer = pixel_buffer;
        self.width = width;
        self.height = height;
    }

    pub fn image_core(self: *Self) image.ImageCore {
        return image.ImageCore.init(self.allocator, self.width, self.height, self.pixel_buffer);
    }

    pub fn set_alpha(self: *Self, alpha_index: u8) void {
        self.alpha_index = alpha_index;
    }

    fn nearest_neighbor(self: *Self, width: u32, height: u32) Error!void {
        const new_buffer = try self.image_core().nearest_neighbor(width, height);

        self.width = width;
        self.height = height;
        self.allocator.free(self.pixel_buffer);
        self.pixel_buffer = new_buffer;
    }

    pub fn gaussian_blur(self: *Self, sigma: f32) Error!void {
        const blurred_buffer = try self.image_core().gaussian_blur(sigma);
        self.allocator.free(self.pixel_buffer);
        self.pixel_buffer = blurred_buffer;
    }

    fn bicubic(self: *Self, width: u32, height: u32) Error!void {
        const data_copy = try self.image_core().bicubic(width, height);
        self.width = width;
        self.height = height;
        self.allocator.free(self.pixel_buffer);
        self.pixel_buffer = data_copy;
    }

    fn bilinear(self: *Self, width: u32, height: u32) Error!void {
        const data_copy = try self.image_core().bilinear(width, height);
        self.width = width;
        self.height = height;
        self.allocator.free(self.pixel_buffer);
        self.pixel_buffer = data_copy;
    }

    pub fn scale(self: *Self, width: u32, height: u32) Error!void {
        return self.bicubic(width, height);
    }

    pub fn load_image(self: *Self, img: anytype) Error!void {
        self.width = img.width;
        self.height = img.height;
        if (self.loaded) {
            self.allocator.free(self.pixel_buffer);
        }
        self.pixel_buffer = try self.allocator.alloc(Pixel, self.width * self.height);
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i].v = img.data.items[i].v;
        }
        self.loaded = true;
    }
};
