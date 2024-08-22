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

pub const ColorMode = enum {
    color_256,
    color_true,
};

fn colour_dist_sq(R: i32, G: i32, B: i32, r: i32, g: i32, b: i32) i32 {
    return ((R - r) * (R - r) + (G - g) * (G - g) + (B - b) * (B - b));
}

fn colour_to_6cube(v: u8) u8 {
    if (v < 48)
        return (0);
    if (v < 114)
        return (1);
    return ((v - 35) / 40);
}

const q2c: [6]u8 = [6]u8{ 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff };

pub fn rgb_256(r: u8, g: u8, b: u8) u8 {
    //std.debug.print("converting {d} {d} {d}\n", .{ r, g, b });
    var qr: u8 = undefined;
    var qg: u8 = undefined;
    var qb: u8 = undefined;
    var cr: u8 = undefined;
    var cg: u8 = undefined;
    var cb: u8 = undefined;
    var d: i32 = undefined;
    var gray: i32 = undefined;
    var gray_avg: i32 = undefined;
    var idx: usize = undefined;
    var gray_idx: usize = undefined;

    qr = colour_to_6cube(r);
    cr = q2c[qr];
    qg = colour_to_6cube(g);
    cg = q2c[qg];
    qb = colour_to_6cube(b);
    cb = q2c[qb];

    if (cr == r and cg == g and cb == b) {
        return @as(u8, @intCast(((16 + (36 * @as(usize, @intCast(qr))) + (6 * @as(usize, @intCast(qg))) + @as(usize, @intCast(qb))))));
    }

    gray_avg = @divFloor((@as(i32, @intCast(r)) + @as(i32, @intCast(g)) + @as(i32, @intCast(b))), 3);
    if (gray_avg > 238) {
        gray_idx = 23;
    } else {
        gray_idx = if (gray_avg >= 10) @as(usize, @intCast(@divFloor((gray_avg - 3), 10))) else 0;
    }
    gray = 8 + (10 * @as(i32, @intCast(gray_idx)));
    d = colour_dist_sq(@as(i32, @intCast(cr)), @as(i32, @intCast(cg)), @as(i32, @intCast(cb)), @as(i32, @intCast(r)), @as(i32, @intCast(g)), @as(i32, @intCast(b)));
    if (colour_dist_sq(gray, gray, gray, @as(i32, @intCast(r)), @as(i32, @intCast(g)), @as(i32, @intCast(b))) < d) {
        idx = 232 + gray_idx;
    } else {
        idx = 16 + (36 * @as(usize, @intCast(qr))) + (6 * @as(usize, @intCast(qg))) + @as(usize, @intCast(qb));
    }
    return @as(u8, @intCast(idx));
}

const color_table: [256]u32 = [_]u32{ 0x000000, 0x800000, 0x008000, 0x808000, 0x000080, 0x800080, 0x008080, 0xc0c0c0, 0x808080, 0xff0000, 0x00ff00, 0xffff00, 0x0000ff, 0xff00ff, 0x00ffff, 0xffffff, 0x000000, 0x00005f, 0x000087, 0x0000af, 0x0000d7, 0x0000ff, 0x005f00, 0x005f5f, 0x005f87, 0x005faf, 0x005fd7, 0x005fff, 0x008700, 0x00875f, 0x008787, 0x0087af, 0x0087d7, 0x0087ff, 0x00af00, 0x00af5f, 0x00af87, 0x00afaf, 0x00afd7, 0x00afff, 0x00d700, 0x00d75f, 0x00d787, 0x00d7af, 0x00d7d7, 0x00d7ff, 0x00ff00, 0x00ff5f, 0x00ff87, 0x00ffaf, 0x00ffd7, 0x00ffff, 0x5f0000, 0x5f005f, 0x5f0087, 0x5f00af, 0x5f00d7, 0x5f00ff, 0x5f5f00, 0x5f5f5f, 0x5f5f87, 0x5f5faf, 0x5f5fd7, 0x5f5fff, 0x5f8700, 0x5f875f, 0x5f8787, 0x5f87af, 0x5f87d7, 0x5f87ff, 0x5faf00, 0x5faf5f, 0x5faf87, 0x5fafaf, 0x5fafd7, 0x5fafff, 0x5fd700, 0x5fd75f, 0x5fd787, 0x5fd7af, 0x5fd7d7, 0x5fd7ff, 0x5fff00, 0x5fff5f, 0x5fff87, 0x5fffaf, 0x5fffd7, 0x5fffff, 0x870000, 0x87005f, 0x870087, 0x8700af, 0x8700d7, 0x8700ff, 0x875f00, 0x875f5f, 0x875f87, 0x875faf, 0x875fd7, 0x875fff, 0x878700, 0x87875f, 0x878787, 0x8787af, 0x8787d7, 0x8787ff, 0x87af00, 0x87af5f, 0x87af87, 0x87afaf, 0x87afd7, 0x87afff, 0x87d700, 0x87d75f, 0x87d787, 0x87d7af, 0x87d7d7, 0x87d7ff, 0x87ff00, 0x87ff5f, 0x87ff87, 0x87ffaf, 0x87ffd7, 0x87ffff, 0xaf0000, 0xaf005f, 0xaf0087, 0xaf00af, 0xaf00d7, 0xaf00ff, 0xaf5f00, 0xaf5f5f, 0xaf5f87, 0xaf5faf, 0xaf5fd7, 0xaf5fff, 0xaf8700, 0xaf875f, 0xaf8787, 0xaf87af, 0xaf87d7, 0xaf87ff, 0xafaf00, 0xafaf5f, 0xafaf87, 0xafafaf, 0xafafd7, 0xafafff, 0xafd700, 0xafd75f, 0xafd787, 0xafd7af, 0xafd7d7, 0xafd7ff, 0xafff00, 0xafff5f, 0xafff87, 0xafffaf, 0xafffd7, 0xafffff, 0xd70000, 0xd7005f, 0xd70087, 0xd700af, 0xd700d7, 0xd700ff, 0xd75f00, 0xd75f5f, 0xd75f87, 0xd75faf, 0xd75fd7, 0xd75fff, 0xd78700, 0xd7875f, 0xd78787, 0xd787af, 0xd787d7, 0xd787ff, 0xd7af00, 0xd7af5f, 0xd7af87, 0xd7afaf, 0xd7afd7, 0xd7afff, 0xd7d700, 0xd7d75f, 0xd7d787, 0xd7d7af, 0xd7d7d7, 0xd7d7ff, 0xd7ff00, 0xd7ff5f, 0xd7ff87, 0xd7ffaf, 0xd7ffd7, 0xd7ffff, 0xff0000, 0xff005f, 0xff0087, 0xff00af, 0xff00d7, 0xff00ff, 0xff5f00, 0xff5f5f, 0xff5f87, 0xff5faf, 0xff5fd7, 0xff5fff, 0xff8700, 0xff875f, 0xff8787, 0xff87af, 0xff87d7, 0xff87ff, 0xffaf00, 0xffaf5f, 0xffaf87, 0xffafaf, 0xffafd7, 0xffafff, 0xffd700, 0xffd75f, 0xffd787, 0xffd7af, 0xffd7d7, 0xffd7ff, 0xffff00, 0xffff5f, 0xffff87, 0xffffaf, 0xffffd7, 0xffffff, 0x080808, 0x121212, 0x1c1c1c, 0x262626, 0x303030, 0x3a3a3a, 0x444444, 0x4e4e4e, 0x585858, 0x626262, 0x6c6c6c, 0x767676, 0x808080, 0x8a8a8a, 0x949494, 0x9e9e9e, 0xa8a8a8, 0xb2b2b2, 0xbcbcbc, 0xc6c6c6, 0xd0d0d0, 0xdadada, 0xe4e4e4, 0xeeeeee };
pub fn indx_rgb(indx: u8) struct { r: u8, b: u8, g: u8 } {
    const rgb = color_table[indx];
    return .{
        .r = @as(u8, @intCast((rgb >> 4) & 0xFF)),
        .g = @as(u8, @intCast((rgb >> 2) & 0xFF)),
        .b = @as(u8, @intCast(rgb & 0xFF)),
    };
}

pub var rand: std.Random = undefined;
pub fn gen_rand() Error!void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = prng.random();
}
