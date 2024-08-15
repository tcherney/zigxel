// Heavily inspired by https://github.com/const-void/DOOM-fire-zig

const builtin = @import("builtin");
const std = @import("std");

const TIOCGWINSZ = std.c.T.IOCGWINSZ; // ioctl flag

//term size
const Size = struct { height: usize, width: usize };

//ansi escape codes
const ESC = "\x1B";
const CSI = ESC ++ "[";

pub const CURSOR_SAVE = ESC ++ "7";
pub const CURSOR_LOAD = ESC ++ "8";

pub const CURSOR_SHOW = CSI ++ "?25h"; //h=high
pub const CURSOR_HIDE = CSI ++ "?25l"; //l=low
pub const CURSOR_HOME = CSI ++ "1;1H"; //1,1

pub const SCREEN_CLEAR = CSI ++ "2J";
pub const SCREEN_BUF_ON = CSI ++ "?1049h"; //h=high
pub const SCREEN_BUF_OFF = CSI ++ "?1049l"; //l=low

pub const LINE_CLEAR_TO_EOL = CSI ++ "0K";

pub const COLOR_RESET = CSI ++ "0m";
pub const COLOR_FG = "38;5;";
pub const COLOR_BG = "48;5;";

pub const COLOR_FG_DEF = CSI ++ COLOR_FG ++ "15m"; // white
pub const COLOR_BG_DEF = CSI ++ COLOR_BG ++ "0m"; // black
pub const COLOR_DEF = COLOR_BG_DEF ++ COLOR_FG_DEF;
pub const COLOR_ITALIC = CSI ++ "3m";
pub const COLOR_NOT_ITALIC = CSI ++ "23m";

pub const TERM_ON = SCREEN_BUF_ON ++ CURSOR_HIDE ++ CURSOR_HOME ++ SCREEN_CLEAR ++ COLOR_DEF;
pub const TERM_OFF = SCREEN_BUF_OFF ++ CURSOR_SHOW ++ N1;

//handy characters
pub const N1 = "\n";
pub const SEP = '▏';

//colors
pub const MAX_COLOR = 256;
pub const LAST_COLOR = MAX_COLOR - 1;

fn init_color(color_code: []const u8) [MAX_COLOR][]u8 {
    var color_idx: u16 = 0;
    var colors: [MAX_COLOR][]u8 = undefined;
    while (color_idx < MAX_COLOR) : (color_idx += 1) {
        colors[color_idx] = std.fmt.comptimePrint(color_code, .{ CSI, color_idx });
    }
}

pub const FG: [MAX_COLOR][]u8 = init_color("{s}38;5;{d}m");
pub const BG: [MAX_COLOR][]u8 = init_color("{s}48;5;{d}m");

const win32 = struct {
    pub const BOOL = i32;
    pub const HANDLE = std.os.windows.HANDLE;
    pub const COORD = extern struct {
        X: i16,
        Y: i16,
    };
    pub const SMALL_RECT = extern struct {
        Left: i16,
        Top: i16,
        Right: i16,
        Bottom: i16,
    };
    pub const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
        dwSize: COORD,
        dwCursorPosition: COORD,
        wAttributes: u16,
        srWindow: SMALL_RECT,
        dwMaximumWindowSize: COORD,
    };
    pub extern "kernel32" fn GetConsoleScreenBufferInfo(
        hConsoleOutput: ?HANDLE,
        lpConsoleScreenBufferInfo: ?*CONSOLE_SCREEN_BUFFER_INFO,
    ) callconv(std.os.windows.WINAPI) BOOL;
};

pub const Term = struct {
    size: Size = undefined,
    allocator: std.mem.Allocator = undefined,
    stdout: std.fs.File.Writer = undefined,
    stdin: std.fs.File.Reader = undefined,
    buffer: []u8 = undefined,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const stdout = std.io.getStdOut().writer();
        const stdin = std.io.getStdIn().reader();
        const ret = Self{
            .size = try get_Size(stdout.context.handle),
            .allocator = allocator,
            .stdout = stdout,
            .stdin = stdin,
        };
        try ret.out(TERM_ON);
        return ret;
    }

    pub fn deinit(self: *Self) !void {
        try self.out(TERM_OFF);
    }

    // const px = "▀";
    // fn initBuf(self: *Self) !void {
    //     const px_char_sz = px.len;
    //     const px_color_sz = BG[LAST_COLOR].len + FG[LAST_COLOR].len;
    //     const px_sz = px_color_sz + px_char_sz;
    //     const screen_sz: u64 = @as(u64, px_sz * self.size.width * self.size.width);
    //     const overflow_sz: u64 = px_char_sz * 100;
    //     const bs_sz: u64 = screen_sz + overflow_sz;
    //     self.buffer = try self.allocator.alloc(u8, bs_sz * 2);
    // }

    pub fn out(self: *const Self, s: []const u8) !void {
        _ = try self.stdout.write(s);
    }

    pub fn out_fmt(self: *const Self, comptime s: []const u8, args: anytype) !void {
        const t = try std.fmt.allocPrint(self.allocator, s, args);
        defer self.allocator.free(t);
        try self.out(t);
    }
    fn get_Size(tty: std.posix.fd_t) !Size {
        if (builtin.os.tag == .windows) {
            //Microsoft Windows Case
            var info: win32.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (0 == win32.GetConsoleScreenBufferInfo(tty, &info)) switch (std.os.windows.kernel32.GetLastError()) {
                else => |e| return std.os.windows.unexpectedError(e),
            };

            return Size{
                .height = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
                .width = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
            };
        } else {
            //Linux-MacOS Case
            var winsz = std.posix.winsize{ .col = 0, .row = 0, .xpixel = 0, .ypixel = 0 };
            const rv = std.c.ioctl(tty, TIOCGWINSZ, @intFromPtr(&winsz));
            const err = std.posix.errno(rv);

            if (rv >= 0) {
                return Size{ .height = winsz.row, .width = winsz.col };
            } else {
                std.process.exit(0);
                return std.posix.unexpectedErrno(err);
            }
        }
    }
};

test "hello world" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var term = try Term.init(allocator);
    try term.out("hello world\n");
    _ = try term.stdin.readByte();
    try term.deinit();

    if (gpa.deinit() == .leak) {
        std.debug.print("Leaked!\n", .{});
    }
}
