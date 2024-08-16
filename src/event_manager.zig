//https://gist.github.com/technoscavenger/7ffb72acdee9ff32daf85bec1c35d5d8
const std = @import("std");
const builtin = @import("builtin");

const win32 = struct {
    pub const EVENT_RECORD = extern union { KeyEvent: KEY_EVENT_RECORD };
    pub const KEY_EVENT_RECORD_CHAR = extern union { UnicodeChar: std.os.windows.WCHAR, AsciiChar: std.os.windows.CHAR };
    pub const KEY_EVENT_RECORD = extern struct {
        bKeyDown: std.os.windows.BOOL,
        wRepeatCount: std.os.windows.WORD,
        wVirtualKeyCode: std.os.windows.WORD,
        wVirtualScanCode: std.os.windows.WORD,
        uChar: KEY_EVENT_RECORD_CHAR,
        dwControlKeyState: std.os.windows.DWORD,
    };
    pub const INPUT_RECORD = extern struct {
        EventType: std.os.windows.WORD,
        Event: EVENT_RECORD,
    };
    pub extern "kernel32" fn ReadConsoleInputW(hStdin: std.os.windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: std.os.windows.DWORD, lpNumberOfEventsRead: *std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
    pub extern "kernel32" fn PeekConsoleInputW(hStdin: std.os.windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: std.os.windows.DWORD, lpNumberOfEventsRead: *std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
};

pub const KEYS = enum(u8) {
    KEY_0 = '0',
    KEY_1 = '1',
    KEY_2 = '2',
    KEY_3 = '3',
    KEY_4 = '4',
    KEY_5 = '5',
    KEY_6 = '6',
    KEY_7 = '7',
    KEY_8 = '8',
    KEY_9 = '9',
    KEY_A = 'A',
    KEY_B = 'B',
    KEY_C = 'C',
    KEY_D = 'D',
    KEY_E = 'E',
    KEY_F = 'F',
    KEY_G = 'G',
    KEY_H = 'H',
    KEY_I = 'I',
    KEY_J = 'J',
    KEY_K = 'K',
    KEY_L = 'L',
    KEY_M = 'M',
    KEY_N = 'N',
    KEY_O = 'O',
    KEY_P = 'P',
    KEY_Q = 'Q',
    KEY_R = 'R',
    KEY_S = 'S',
    KEY_T = 'T',
    KEY_U = 'U',
    KEY_V = 'V',
    KEY_W = 'W',
    KEY_X = 'X',
    KEY_Y = 'Y',
    KEY_Z = 'Z',
    KEY_a = 'a',
    KEY_b = 'b',
    KEY_c = 'c',
    KEY_d = 'd',
    KEY_e = 'e',
    KEY_f = 'f',
    KEY_g = 'g',
    KEY_h = 'h',
    KEY_i = 'i',
    KEY_j = 'j',
    KEY_k = 'k',
    KEY_l = 'l',
    KEY_m = 'm',
    KEY_n = 'n',
    KEY_o = 'o',
    KEY_p = 'p',
    KEY_q = 'q',
    KEY_r = 'r',
    KEY_s = 's',
    KEY_t = 't',
    KEY_u = 'u',
    KEY_v = 'v',
    KEY_w = 'w',
    KEY_x = 'x',
    KEY_y = 'y',
    KEY_z = 'z',
    KEY_enter = '\n',
    KEY_CR = '\r',
};

pub const Error = error{ WindowsInit, WindowsRead };

pub const EventManager = struct {
    main_thread: std.Thread = undefined,
    running: bool = false,
    key_up_callback: ?*const fn (KEYS) void = null,
    key_down_callback: ?*const fn (KEYS) void = null,
    key_press_callback: ?*const fn (KEYS) void = null,
    original_termios: termios = undefined,
    stdin: std.fs.File,
    const Self = @This();
    pub const termios = switch (builtin.os.tag) {
        .windows => std.os.windows.DWORD,
        else => std.posix.termios,
    };
    pub fn init() EventManager {
        return EventManager{ .stdin = std.io.getStdIn() };
    }

    pub fn deinit(self: *Self) !void {
        try self.stop();
    }

    pub fn stop(self: *Self) !void {
        if (self.running) {
            self.running = false;
            self.main_thread.join();
            try self.cook();
        }
    }

    fn cook(self: *Self) !void {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleMode(self.stdin.handle, self.original_termios);
        } else {
            try std.posix.tcsetattr(self.stdin.handle, .FLUSH, self.original_termios);
        }
    }

    fn raw_mode(self: *Self) !void {
        if (builtin.os.tag == .windows) {
            if (std.os.windows.kernel32.GetConsoleMode(self.stdin.handle, &self.original_termios) != std.os.windows.TRUE) {
                return Error.WindowsInit;
            }
        } else {
            self.original_termios = try std.posix.tcgetattr(self.stdin.handle);
            var raw = self.original_termios;
            raw.lflag.ECHO = false;
            raw.lflag.ICANON = false;
            raw.lflag.ISIG = false;
            raw.lflag.IEXTEN = false;

            raw.iflag.IXON = false;
            raw.iflag.ICRNL = false;
            raw.iflag.BRKINT = false;
            raw.iflag.INPCK = false;
            raw.iflag.ISTRIP = false;

            raw.cc[std.posix.V.TIME] = 0;
            raw.cc[std.posix.V.MIN] = 1;
            try std.c.tcsetattr(self.stdin.handle, .FLUSH, raw);
        }
    }

    pub fn start(self: *Self) !void {
        try self.raw_mode();
        self.running = true;
        self.main_thread = try std.Thread.spawn(.{}, event_loop, .{self});
    }

    fn event_loop(self: *Self) !void {
        if (builtin.os.tag == .windows) {
            var irInBuf: [128]win32.INPUT_RECORD = undefined;
            var numRead: u32 = undefined;
            while (self.running) {
                if (win32.ReadConsoleInputW(self.stdin.handle, &irInBuf, 128, &numRead) != std.os.windows.TRUE) {
                    return Error.WindowsRead;
                } else {
                    if (self.key_press_callback != null) {
                        self.key_press_callback.?(@enumFromInt(irInBuf[0].Event.KeyEvent.uChar.AsciiChar));
                    }
                }
            }
        } else {
            const stdin: std.fs.File.Reader = self.stdin.reader();
            while (self.running) {
                const byte = try stdin.readByte();
                if (self.key_press_callback != null) {
                    self.key_press_callback.?(@enumFromInt(byte));
                }
            }
        }
    }
};
var running: bool = false;
pub fn on_key_press(key: KEYS) void {
    std.debug.print("{}\n", .{key});
    if (key == KEYS.KEY_q) {
        std.debug.print("running now false\n", .{});
        running = false;
    }
}

test "input" {
    var event_manager = EventManager.init();
    event_manager.key_press_callback = on_key_press;
    try event_manager.start();
    running = true;
    while (running) {}
    try event_manager.deinit();
}
