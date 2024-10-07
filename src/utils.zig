const std = @import("std");

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

pub fn CallbackError(comptime DATA_TYPE: type, comptime Error: type) type {
    return struct {
        function: *const fn (context: *anyopaque, DATA_TYPE) Error!void,
        context: *anyopaque,
        const Self = @This();
        pub fn init(comptime T: type, function: *const fn (context: *T, DATA_TYPE) Error!void, context: *T) Self {
            return Self{ .function = @ptrCast(function), .context = context };
        }

        pub fn call(callback: Self, data: DATA_TYPE) Error!void {
            return try callback.function(callback.context, data);
        }
    };
}
pub fn Point(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,
        const Self = @This();
        pub fn eql(lhs: Self, rhs: Self) bool {
            return lhs.x == rhs.x and lhs.y == rhs.y;
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
pub fn gen_rand() std.posix.GetRandomError!void {
    prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = prng.random();
}
