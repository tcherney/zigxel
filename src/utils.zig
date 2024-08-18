const std = @import("std");

pub const Error = std.posix.GetRandomError;

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

pub var rand: std.Random = undefined;
pub fn gen_rand() Error!void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = prng.random();
}
