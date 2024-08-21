const std = @import("std");
const utils = @import("utils.zig");
const image = @import("image");

pub const Error = error{} || std.mem.Allocator.Error;

pub fn Texture(comptime T: utils.ColorMode) type {
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
            .color_true => struct {
                r: u8 = 0,
                g: u8 = 0,
                b: u8 = 0,
                a: ?u8 = null,
            },
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

        fn nearest_neighbor(self: *Self, width: usize, height: usize) Error!void {
            var new_buffer = try self.allocator.alloc(PixelType, width * height);
            switch (T) {
                .color_256 => {
                    for (0..height) |y| {
                        for (0..width) |x| {
                            const src_x: usize = @min(self.width - 1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(width)) * @as(f32, @floatFromInt(self.width)))));
                            const src_y: usize = @min(self.height - 1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(height)) * @as(f32, @floatFromInt(self.height)))));
                            new_buffer[y * width + x] = self.pixel_buffer[src_y * self.width + src_x];
                        }
                    }
                },
                .color_true => {
                    for (0..height) |y| {
                        for (0..width) |x| {
                            const src_x: usize = @min(self.width - 1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(width)) * @as(f32, @floatFromInt(self.width)))));
                            const src_y: usize = @min(self.height - 1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(height)) * @as(f32, @floatFromInt(self.height)))));
                            new_buffer[y * width + x] = .{ .r = self.pixel_buffer[src_y * self.width + src_x].r, .g = self.pixel_buffer[src_y * self.width + src_x].g, .b = self.pixel_buffer[src_y * self.width + src_x].b, .a = self.pixel_buffer[src_y * self.width + src_x].a };
                        }
                    }
                },
            }
            self.width = width;
            self.height = height;
            self.allocator.free(self.pixel_buffer);
            self.pixel_buffer = new_buffer;
        }

        inline fn gaussian_kernel(x: i32, y: i32, sigma: f32) f32 {
            const coeff: f32 = 1.0 / (2.0 * std.math.pi * sigma * sigma);
            const exponent: f32 = -(@as(f32, @floatFromInt(x)) * @as(f32, @floatFromInt(x)) + @as(f32, @floatFromInt(y)) * @as(f32, @floatFromInt(y))) / (2.0 * sigma * sigma);
            return coeff * std.math.exp(exponent);
        }

        fn gaussian_kernel_2d(self: *Self, sigma: f32) Error![]f32 {
            var kernel_size: usize = @as(usize, @intFromFloat(@ceil(2 * sigma + 1)));
            if (kernel_size % 2 == 0) {
                kernel_size += 1;
            }
            var kernel_2d: []f32 = try self.allocator.alloc(f32, kernel_size * kernel_size);
            var sum: f32 = 0.0;
            for (0..kernel_size) |i| {
                for (0..kernel_size) |j| {
                    const x: i32 = @as(i32, @intCast(@as(i64, @bitCast(j)))) - @divFloor(@as(i32, @intCast(@as(i64, @bitCast(kernel_size)))), 2);
                    const y: i32 = @as(i32, @intCast(@as(i64, @bitCast(i)))) - @divFloor(@as(i32, @intCast(@as(i64, @bitCast(kernel_size)))), 2);
                    const val: f32 = gaussian_kernel(x, y, sigma);
                    kernel_2d[i * kernel_size + j] = val;
                    sum += val;
                }
            }

            for (0..kernel_size) |i| {
                for (0..kernel_size) |j| {
                    kernel_2d[i * kernel_size + j] /= sum;
                }
            }
            return kernel_2d;
        }

        pub fn gaussian_blur(self: *Self, sigma: f32) Error!void {
            const kernel_2d = try self.gaussian_kernel_2d(sigma);
            defer self.allocator.free(kernel_2d);
            var kernel_size: usize = @as(usize, @intFromFloat(@ceil(2 * sigma + 1)));
            if (kernel_size % 2 == 0) {
                kernel_size += 1;
            }

            for (kernel_size / 2..self.height - kernel_size / 2) |y| {
                for (kernel_size / 2..self.width - kernel_size / 2) |x| {
                    var r: f32 = 0.0;
                    var g: f32 = 0.0;
                    var b: f32 = 0.0;
                    var a: f32 = 0.0;
                    for (0..kernel_size) |i| {
                        for (0..kernel_size) |j| {
                            var curr_pixel: PixelType = undefined;
                            if (T == .color_256) {
                                curr_pixel = utils.indx_rgb(self.pixel_buffer[(y + i - kernel_size / 2) * self.width + (x + j - kernel_size / 2)]);
                            } else {
                                curr_pixel = self.pixel_buffer[(y + i - kernel_size / 2) * self.width + (x + j - kernel_size / 2)];
                            }
                            r += kernel_2d[i * kernel_size + j] * @as(f32, @floatFromInt(curr_pixel.r));
                            g += kernel_2d[i * kernel_size + j] * @as(f32, @floatFromInt(curr_pixel.g));
                            b += kernel_2d[i * kernel_size + j] * @as(f32, @floatFromInt(curr_pixel.b));
                            a += if (curr_pixel.a != null) kernel_2d[i * kernel_size + j] * @as(f32, @floatFromInt(curr_pixel.a.?)) else 0.0;
                        }
                    }
                    if (T == .color_256) {
                        self.pixel_buffer[y * self.width + x] = utils.rgb_256(@as(u8, @intFromFloat(r)), @as(u8, @intFromFloat(g)), @as(u8, @intFromFloat(b)));
                    } else {
                        self.pixel_buffer[y * self.width + x].r = @as(u8, @intFromFloat(r));
                        self.pixel_buffer[y * self.width + x].g = @as(u8, @intFromFloat(g));
                        self.pixel_buffer[y * self.width + x].b = @as(u8, @intFromFloat(b));
                        self.pixel_buffer[y * self.width + x].a = if (self.pixel_buffer[y * self.width + x].a != null) @as(u8, @intFromFloat(a)) else null;
                    }
                }
            }
        }

        const BicubicPixel = struct {
            r: f32 = 0,
            g: f32 = 0,
            b: f32 = 0,
            a: ?f32 = null,
            pub fn sub(self: *const BicubicPixel, other: BicubicPixel) BicubicPixel {
                return .{
                    .r = self.r - other.r,
                    .g = self.g - other.g,
                    .b = self.b - other.b,
                    .a = if (self.a != null and other.a != null) self.a.? - other.a.? else null,
                };
            }
            pub fn add(self: *const BicubicPixel, other: BicubicPixel) BicubicPixel {
                return .{
                    .r = self.r + other.r,
                    .g = self.g + other.g,
                    .b = self.b + other.b,
                    .a = if (self.a != null and other.a != null) self.a.? + other.a.? else null,
                };
            }
            pub fn scale(self: *const BicubicPixel, scalar: f32) BicubicPixel {
                return .{
                    .r = self.r * scalar,
                    .g = self.g * scalar,
                    .b = self.b * scalar,
                    .a = if (self.a != null) self.a.? * scalar else null,
                };
            }
        };

        fn bicubic_get_pixel(self: *Self, y: i64, x: i64) BicubicPixel {
            if (x < self.width and y < self.height and x > 0 and y > 0) {
                if (T == .color_256) {
                    const color = utils.indx_rgb(self.pixel_buffer[@as(usize, @bitCast(y)) * self.width + @as(usize, @bitCast(x))]);
                    return BicubicPixel{
                        .r = @as(f32, @floatFromInt(color.r)),
                        .g = @as(f32, @floatFromInt(color.g)),
                        .b = @as(f32, @floatFromInt(color.b)),
                    };
                } else {
                    return BicubicPixel{
                        .r = @as(f32, @floatFromInt(self.pixel_buffer[@as(usize, @bitCast(y)) * self.width + @as(usize, @bitCast(x))].r)),
                        .g = @as(f32, @floatFromInt(self.pixel_buffer[@as(usize, @bitCast(y)) * self.width + @as(usize, @bitCast(x))].g)),
                        .b = @as(f32, @floatFromInt(self.pixel_buffer[@as(usize, @bitCast(y)) * self.width + @as(usize, @bitCast(x))].b)),
                    };
                }
            } else {
                return BicubicPixel{};
            }
        }

        fn bicubic(self: *Self, width: usize, height: usize) Error!void {
            var new_buffer = try self.allocator.alloc(PixelType, width * height);
            const width_scale: f32 = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(width));
            const height_scale: f32 = @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(height));
            var C: [5]BicubicPixel = undefined;
            for (0..5) |i| {
                C[i] = BicubicPixel{};
            }
            for (0..height) |y| {
                for (0..width) |x| {
                    const src_x: i64 = @as(i64, @intFromFloat(@as(f32, @floatFromInt(x)) * width_scale));
                    const src_y: i64 = @as(i64, @intFromFloat(@as(f32, @floatFromInt(y)) * height_scale));
                    const dx: f32 = width_scale * @as(f32, @floatFromInt(x)) - @as(f32, @floatFromInt(src_x));
                    const dy: f32 = height_scale * @as(f32, @floatFromInt(y)) - @as(f32, @floatFromInt(src_y));
                    var new_pixel: BicubicPixel = BicubicPixel{};
                    for (0..4) |jj| {
                        const z: i64 = src_y + @as(i64, @bitCast(jj)) - 1;
                        const a0 = self.bicubic_get_pixel(z, src_x);
                        const d0 = self.bicubic_get_pixel(z, src_x - 1).sub(a0);
                        const d2 = self.bicubic_get_pixel(z, src_x + 1).sub(a0);
                        const d3 = self.bicubic_get_pixel(z, src_x + 2).sub(a0);

                        const a1 = d0.scale(-1.0 / 3.0).add(d2.sub(d3.scale(1.0 / 6.0)));
                        const a2 = d0.scale(1.0 / 2.0).add(d2.scale(1.0 / 2.0));
                        const a3 = d0.scale(-1.0 / 6.0).sub(d2.scale(1.0 / 2.0).add(d3.scale(1.0 / 6.0)));

                        C[jj] = a0.add(a1.scale(dx)).add(a2.scale(dx * dx)).add(a3.scale(dx * dx * dx));
                    }
                    const d0 = C[0].sub(C[1]);
                    const d2 = C[2].sub(C[1]);
                    const d3 = C[3].sub(C[1]);
                    const a0 = C[1];

                    const a1 = d0.scale(-1.0 / 3.0).add(d2.sub(d3.scale(1.0 / 6.0)));
                    const a2 = d0.scale(1.0 / 2.0).add(d2.scale(1.0 / 2.0));
                    const a3 = d0.scale(-1.0 / 6.0).sub(d2.scale(1.0 / 2.0).add(d3.scale(1.0 / 6.0)));
                    new_pixel = a0.add(a1.scale(dy)).add(a2.scale(dy * dy)).add(a3.scale(dy * dy * dy));
                    if (T == .color_256) {
                        new_buffer[y * width + x] = utils.rgb_256(@as(u8, @intFromFloat(new_pixel.r)), @as(u8, @intFromFloat(new_pixel.g)), @as(u8, @intFromFloat(new_pixel.b)));
                    } else {
                        new_buffer[y * width + x].r = @as(u8, @intFromFloat(new_pixel.r));
                        new_buffer[y * width + x].g = @as(u8, @intFromFloat(new_pixel.g));
                        new_buffer[y * width + x].b = @as(u8, @intFromFloat(new_pixel.b));
                        new_buffer[y * width + x].a = if (new_pixel.a != null) @as(u8, @intFromFloat(new_pixel.a.?)) else null;
                    }
                }
            }

            self.width = width;
            self.height = height;
            self.allocator.free(self.pixel_buffer);
            self.pixel_buffer = new_buffer;
        }

        fn bilinear(self: *Self, width: usize, height: usize) Error!void {
            var new_buffer = try self.allocator.alloc(PixelType, width * height);
            const width_scale: f32 = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(width));
            const height_scale: f32 = @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(height));
            switch (T) {
                .color_256 => {
                    for (0..height) |y| {
                        for (0..width) |x| {
                            const src_x: f32 = @as(f32, @floatFromInt(x)) * width_scale;
                            const src_y: f32 = @as(f32, @floatFromInt(y)) * height_scale;
                            const src_x_floor: f32 = @floor(src_x);
                            const src_x_ceil: f32 = @min(@as(f32, @floatFromInt(self.width)) - 1.0, @ceil(src_x));
                            const src_y_floor: f32 = @floor(src_y);
                            const src_y_ceil: f32 = @min(@as(f32, @floatFromInt(self.height)) - 1.0, @ceil(src_y));
                            const src_x_floor_indx: usize = @as(usize, @intFromFloat(src_x_floor));
                            const src_x_ceil_indx: usize = @as(usize, @intFromFloat(src_x_ceil));
                            const src_y_floor_indx: usize = @as(usize, @intFromFloat(src_y_floor));
                            const src_y_ceil_indx: usize = @as(usize, @intFromFloat(src_y_ceil));
                            var new_pixel: PixelType = 0;
                            if (src_x_ceil == src_x_floor and src_y_ceil == src_y_floor) {
                                new_pixel = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx];
                            } else if (src_x_ceil == src_x_floor) {
                                const q1 = utils.indx_rgb(self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx]);
                                const q2 = utils.indx_rgb(self.pixel_buffer[src_y_ceil_indx * self.width + src_x_floor_indx]);
                                const r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.r)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.r)) * (src_y - src_y_floor))));
                                const g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.g)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.g)) * (src_y - src_y_floor))));
                                const b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.b)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.b)) * (src_y - src_y_floor))));
                                new_pixel = utils.rgb_256(r, g, b);
                            } else if (src_y_ceil == src_y_floor) {
                                const q1 = utils.indx_rgb(self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx]);
                                const q2 = utils.indx_rgb(self.pixel_buffer[src_y_ceil_indx * self.width + src_x_ceil_indx]);
                                const r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.r)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.r)) * (src_x - src_x_floor))));
                                const g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.g)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.g)) * (src_x - src_x_floor))));
                                const b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.b)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.b)) * (src_x - src_x_floor))));
                                new_pixel = utils.rgb_256(r, g, b);
                            } else {
                                const v1 = utils.indx_rgb(self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx]);
                                const v2 = utils.indx_rgb(self.pixel_buffer[src_y_floor_indx * self.width + src_x_ceil_indx]);
                                const v3 = utils.indx_rgb(self.pixel_buffer[src_y_ceil_indx * self.width + src_x_floor_indx]);
                                const v4 = utils.indx_rgb(self.pixel_buffer[src_y_ceil_indx * self.width + src_x_ceil_indx]);

                                const q1 = .{
                                    .r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.r)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.r)) * (src_x - src_x_floor)))),
                                    .g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.g)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.g)) * (src_x - src_x_floor)))),
                                    .b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.b)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.b)) * (src_x - src_x_floor)))),
                                };
                                const q2 = .{
                                    .r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.r)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.r)) * (src_x - src_x_floor)))),
                                    .g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.g)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.g)) * (src_x - src_x_floor)))),
                                    .b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.b)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.b)) * (src_x - src_x_floor)))),
                                };
                                const r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.r)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.r)) * (src_y - src_y_floor))));
                                const g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.g)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.g)) * (src_y - src_y_floor))));
                                const b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.b)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.b)) * (src_y - src_y_floor))));
                                new_pixel = utils.rgb_256(r, g, b);
                            }
                            new_buffer[y * width + x] = new_pixel;
                        }
                    }
                },
                .color_true => {
                    for (0..height) |y| {
                        for (0..width) |x| {
                            const src_x: f32 = @as(f32, @floatFromInt(x)) * width_scale;
                            const src_y: f32 = @as(f32, @floatFromInt(y)) * height_scale;
                            const src_x_floor: f32 = @floor(src_x);
                            const src_x_ceil: f32 = @min(@as(f32, @floatFromInt(self.width)) - 1.0, @ceil(src_x));
                            const src_y_floor: f32 = @floor(src_y);
                            const src_y_ceil: f32 = @min(@as(f32, @floatFromInt(self.height)) - 1.0, @ceil(src_y));
                            const src_x_floor_indx: usize = @as(usize, @intFromFloat(src_x_floor));
                            const src_x_ceil_indx: usize = @as(usize, @intFromFloat(src_x_ceil));
                            const src_y_floor_indx: usize = @as(usize, @intFromFloat(src_y_floor));
                            const src_y_ceil_indx: usize = @as(usize, @intFromFloat(src_y_ceil));
                            var new_pixel: PixelType = PixelType{};
                            if (src_x_ceil == src_x_floor and src_y_ceil == src_y_floor) {
                                new_pixel.r = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx].r;
                                new_pixel.g = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx].g;
                                new_pixel.b = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx].b;
                                new_pixel.a = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx].a;
                            } else if (src_x_ceil == src_x_floor) {
                                const q1 = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx];
                                const q2 = self.pixel_buffer[src_y_ceil_indx * self.width + src_x_floor_indx];
                                new_pixel.r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.r)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.r)) * (src_y - src_y_floor))));
                                new_pixel.g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.g)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.g)) * (src_y - src_y_floor))));
                                new_pixel.b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.b)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.b)) * (src_y - src_y_floor))));
                                new_pixel.a = if (q1.a != null and q2.a != null) @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.a.?)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.a.?)) * (src_y - src_y_floor)))) else null;
                            } else if (src_y_ceil == src_y_floor) {
                                const q1 = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx];
                                const q2 = self.pixel_buffer[src_y_ceil_indx * self.width + src_x_ceil_indx];
                                new_pixel.r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.r)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.r)) * (src_x - src_x_floor))));
                                new_pixel.g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.g)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.g)) * (src_x - src_x_floor))));
                                new_pixel.b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.b)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.b)) * (src_x - src_x_floor))));
                                new_pixel.a = if (q1.a != null and q2.a != null) @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.a.?)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(q2.a.?)) * (src_x - src_x_floor)))) else null;
                            } else {
                                const v1 = self.pixel_buffer[src_y_floor_indx * self.width + src_x_floor_indx];
                                const v2 = self.pixel_buffer[src_y_floor_indx * self.width + src_x_ceil_indx];
                                const v3 = self.pixel_buffer[src_y_ceil_indx * self.width + src_x_floor_indx];
                                const v4 = self.pixel_buffer[src_y_ceil_indx * self.width + src_x_ceil_indx];

                                const q1 = .{
                                    .r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.r)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.r)) * (src_x - src_x_floor)))),
                                    .g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.g)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.g)) * (src_x - src_x_floor)))),
                                    .b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.b)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.b)) * (src_x - src_x_floor)))),
                                    .a = if (v1.a != null and v2.a != null) @as(u8, @intFromFloat((@as(f32, @floatFromInt(v1.a.?)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v2.a.?)) * (src_x - src_x_floor)))) else null,
                                };
                                const q2 = .{
                                    .r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.r)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.r)) * (src_x - src_x_floor)))),
                                    .g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.g)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.g)) * (src_x - src_x_floor)))),
                                    .b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.b)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.b)) * (src_x - src_x_floor)))),
                                    .a = if (v3.a != null and v4.a != null) @as(u8, @intFromFloat((@as(f32, @floatFromInt(v3.a.?)) * (src_x_ceil - src_x)) + (@as(f32, @floatFromInt(v4.a.?)) * (src_x - src_x_floor)))) else null,
                                };
                                new_pixel.r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.r)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.r)) * (src_y - src_y_floor))));
                                new_pixel.g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.g)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.g)) * (src_y - src_y_floor))));
                                new_pixel.b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.b)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.b)) * (src_y - src_y_floor))));
                                new_pixel.a = if (q1.a != null and q2.a != null) @as(u8, @intFromFloat((@as(f32, @floatFromInt(q1.a.?)) * (src_y_ceil - src_y)) + (@as(f32, @floatFromInt(q2.a.?)) * (src_y - src_y_floor)))) else null;
                            }

                            new_buffer[y * width + x].r = new_pixel.r;
                            new_buffer[y * width + x].g = new_pixel.g;
                            new_buffer[y * width + x].b = new_pixel.b;
                            new_buffer[y * width + x].a = new_pixel.a;
                        }
                    }
                },
            }
            self.width = width;
            self.height = height;
            self.allocator.free(self.pixel_buffer);
            self.pixel_buffer = new_buffer;
        }

        pub fn scale(self: *Self, width: usize, height: usize) Error!void {
            return self.bicubic(width, height);
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
                    .color_true => self.pixel_buffer[i] = .{ .r = img.data.items[i].r, .g = img.data.items[i].g, .b = img.data.items[i].b, .a = img.data.items[i].a },
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
