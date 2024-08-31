const std = @import("std");

pub const Error = std.posix.GetRandomError;

pub fn Callback(comptime DATA_TYPE: type) type {
    return struct {
        function: *const fn (context: *anyopaque, DATA_TYPE) void,
        context: *anyopaque,
        const Self = @This();
        pub fn init(comptime T: type, function: *const fn (context: *T, DATA_TYPE) void, context: *T) Self {
            return Self{ .function = @ptrCast(function), .context = context };
        }

        pub fn call(callback: Self, data: DATA_TYPE) void {
            return callback.function(callback.context, data);
        }
    };
}

pub fn CallbackError(comptime DATA_TYPE: type) type {
    return struct {
        function: *const fn (context: *anyopaque, DATA_TYPE) anyerror!void,
        context: *anyopaque,
        const Self = @This();
        pub fn init(comptime T: type, function: *const fn (context: *T, DATA_TYPE) anyerror!void, context: *T) Self {
            return Self{ .function = @ptrCast(function), .context = context };
        }

        pub fn call(callback: Self, data: DATA_TYPE) anyerror!void {
            return try callback.function(callback.context, data);
        }
    };
}

pub const Rectangle = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub const ColorMode = enum {
    color_256,
    color_true,
};

var prng: std.Random.Xoshiro256 = undefined;
pub var rand: std.Random = undefined;
pub fn gen_rand() Error!void {
    prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = prng.random();
}
