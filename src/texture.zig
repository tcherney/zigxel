const std = @import("std");
const utils = @import("utils.zig");
const image = @import("image");

pub const Error = error{} || std.mem.Allocator.Error || image.Error || utils.Error;
pub const Pixel = image.Pixel;

pub const Texture = struct {
    allocator: std.mem.Allocator,
    height: u32 = undefined,
    width: u32 = undefined,
    pixel_buffer: []Pixel = undefined,
    alpha_index: ?u8 = null,
    loaded: bool = false,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.pixel_buffer);
    }

    pub fn rect(self: *Self, width: u32, height: u32, r: u8, g: u8, b: u8, a: ?u8) Error!void {
        self.height = height;
        self.width = width;
        if (self.loaded) {
            self.allocator.free(self.pixel_buffer);
        }
        self.pixel_buffer = try self.allocator.alloc(Pixel, height * width);
        for (0..self.pixel_buffer.len) |i| {
            self.pixel_buffer[i] = .{ .r = r, .g = g, .b = b, .a = a };
        }
        self.loaded = true;
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
            self.pixel_buffer[i] = .{ .r = img.data.items[i].r, .g = img.data.items[i].g, .b = img.data.items[i].b, .a = img.data.items[i].a };
        }
        self.loaded = true;
    }
    //https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.
    pub fn load_ttf(self: *Self, file_name: []const u8) void {
        _ = self;
        _ = file_name;
    }
};

// test "cat" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     var img = image.Image(image.JPEGImage){};
//     try img.load("../img2ascii/tests/jpeg/cat.jpg", allocator);
//     var texture = Texture(ColorMode.color_256).init(allocator);
//     try texture.load_image(5, 5, img);
//     img.deinit();
//     texture.deinit();
//     if (gpa.deinit() == .leak) {
//         std.debug.print("Leaked!\n", .{});
//     }
// }
