const std = @import("std");
const utils = @import("utils.zig");
const image = @import("image");

pub const Error = error{} || std.mem.Allocator.Error;

pub const ColorMode = enum {
    color_256,
    color_true,
};

pub fn Texture(comptime T: ColorMode) type {
    return struct {
        allocator: std.mem.Allocator,
        x: i32 = undefined,
        y: i32 = undefined,
        height: usize = undefined,
        width: usize = undefined,
        pixel_buffer: []PixelType = undefined,
        alpha_index: ?u8 = null,
        pub const PixelType: type = switch (T) {
            .color_256 => u8,
            .color_true => struct { r: u8, g: u8, b: u8, a: ?u8 = null },
        };
        const Self = @This();
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.pixel_buffer);
        }

        pub fn rect(self: *Self, x: i32, y: i32, width: i32, height: i32, r: u8, g: u8, b: u8) Error!void {
            self.x = x;
            self.y = y;
            self.height = height;
            self.width = width;
            self.pixel_buffer = try self.allocator.alloc(PixelType, height * width);
            for (0..self.pixel_buffer.len) |i| {
                switch (T) {
                    .color_256 => self.pixel_buffer[i] = utils.rgb_256(r, g, b),
                    .color_true => self.pixel_buffer[i] = .{ .r = r, .g = g, .b = b },
                }
            }
        }

        pub fn set_alpha(self: *Self, alpha_index: u8) void {
            self.alpha_index = alpha_index;
        }

        pub fn load_image(self: *Self, x: i32, y: i32, img: anytype) Error!void {
            self.x = x;
            self.y = y;
            self.width = @as(usize, @intCast(img.width));
            self.height = @as(usize, @intCast(img.height));
            self.pixel_buffer = try self.allocator.alloc(PixelType, self.width * self.height);
            for (0..self.pixel_buffer.len) |i| {
                switch (T) {
                    .color_256 => self.pixel_buffer[i] = utils.rgb_256(img.data.items[i].r, img.data.items[i].g, img.data.items[i].b),
                    .color_true => self.pixel_buffer[i] = .{ .r = img.data.items[i].r, .g = img.data.items[i].g, .b = img.data.items[i].b, .a = if (img.data.items[i].a != null) img.data.items[i].a.? else null },
                }
            }
        }
        //https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.
        pub fn load_ttf(self: *Self, file_name: []const u8) void {
            _ = self;
            _ = file_name;
        }
    };
}

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

// test "256" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     var texture = Texture(ColorMode.color_256).init(allocator);
//     try texture.rect(5, 5, 10, 10, 255, 0, 0);
//     std.debug.print("{}\n", .{texture});
//     try std.testing.expect(texture.pixel_buffer[0] == 196);
//     texture.deinit();
//     if (gpa.deinit() == .leak) {
//         std.debug.print("Leaked!\n", .{});
//     }
// }

// test "true" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     var texture = Texture(ColorMode.color_true).init(allocator);
//     try texture.rect(5, 5, 10, 10, 255, 0, 0);
//     std.debug.print("{}\n", .{texture});
//     try std.testing.expect(texture.pixel_buffer[0].r == 255);
//     texture.deinit();
//     if (gpa.deinit() == .leak) {
//         std.debug.print("Leaked!\n", .{});
//     }
// }
