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
pub fn Point(comptime size: comptime_int, comptime data_type: type) type {
    switch (size) {
        2 => {
            return struct {
                x: data_type = 0,
                y: data_type = 0,
                const Self = @This();
                pub fn eql(lhs: Self, rhs: Self) bool {
                    return lhs.x == rhs.x and lhs.y == rhs.y;
                }
            };
        },
        3 => {
            return struct {
                x: data_type = 0,
                y: data_type = 0,
                z: data_type = 0,
                const Self = @This();
                pub fn eql(lhs: Self, rhs: Self) bool {
                    return lhs.x == rhs.x and lhs.y == rhs.y and lhs.z == rhs.z;
                }
            };
        },
        else => unreachable,
    }
}

pub const Rectangle = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,
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
