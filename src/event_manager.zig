const std = @import("std");
const builtin = @import("builtin");
const common = @import("common");
const _xlib = @import("xlib.zig");

const EVENT_LOG = std.log.scoped(.event_manager);
const Xlib = _xlib.Xlib;

const win32 = struct {
    pub const EVENT_RECORD = extern union {
        KeyEvent: KEY_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
    };
    pub const KEY_EVENT_RECORD_CHAR = extern union { UnicodeChar: std.os.windows.WCHAR, AsciiChar: std.os.windows.CHAR };
    pub const KEY_EVENT_RECORD = extern struct {
        bKeyDown: std.os.windows.BOOL,
        wRepeatCount: std.os.windows.WORD,
        wVirtualKeyCode: std.os.windows.WORD,
        wVirtualScanCode: std.os.windows.WORD,
        uChar: KEY_EVENT_RECORD_CHAR,
        dwControlKeyState: std.os.windows.DWORD,
    };
    pub const MOUSE_EVENT_RECORD = extern struct {
        dwMousePosition: std.os.windows.COORD,
        dwButtonState: std.os.windows.DWORD,
        dwControlKeyState: std.os.windows.DWORD,
        dwEventFlags: std.os.windows.DWORD,
    };
    pub const WINDOW_BUFFER_SIZE_RECORD = extern struct {
        dwSize: std.os.windows.COORD,
    };
    pub const EventType = enum(u32) {
        KEY_EVENT = 0x0001,
        FOCUS_EVENT = 0x0010,
        MENU_EVENT = 0x0008,
        MOUSE_EVENT = 0x0002,
        WINDOW_BUFFER_SIZE = 0x0004,
    };
    pub const INPUT_RECORD = extern struct {
        EventType: std.os.windows.WORD,
        Event: EVENT_RECORD,
    };
    pub extern "kernel32" fn ReadConsoleInputW(hStdin: std.os.windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: std.os.windows.DWORD, lpNumberOfEventsRead: *std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
    pub extern "kernel32" fn PeekConsoleInputW(hStdin: std.os.windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: std.os.windows.DWORD, lpNumberOfEventsRead: *std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
    pub extern "kernel32" fn GetNumberOfConsoleInputEvents(hConsoleInput: std.os.windows.HANDLE, lpcNumberOfEvents: *std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
};

pub const KEYS = enum(u8) { KEY_0 = '0', KEY_1 = '1', KEY_2 = '2', KEY_3 = '3', KEY_4 = '4', KEY_5 = '5', KEY_6 = '6', KEY_7 = '7', KEY_8 = '8', KEY_9 = '9', KEY_A = 'A', KEY_B = 'B', KEY_C = 'C', KEY_D = 'D', KEY_E = 'E', KEY_F = 'F', KEY_G = 'G', KEY_H = 'H', KEY_I = 'I', KEY_J = 'J', KEY_K = 'K', KEY_L = 'L', KEY_M = 'M', KEY_N = 'N', KEY_O = 'O', KEY_P = 'P', KEY_Q = 'Q', KEY_R = 'R', KEY_S = 'S', KEY_T = 'T', KEY_U = 'U', KEY_V = 'V', KEY_W = 'W', KEY_X = 'X', KEY_Y = 'Y', KEY_Z = 'Z', KEY_a = 'a', KEY_b = 'b', KEY_c = 'c', KEY_d = 'd', KEY_e = 'e', KEY_f = 'f', KEY_g = 'g', KEY_h = 'h', KEY_i = 'i', KEY_j = 'j', KEY_k = 'k', KEY_l = 'l', KEY_m = 'm', KEY_n = 'n', KEY_o = 'o', KEY_p = 'p', KEY_q = 'q', KEY_r = 'r', KEY_s = 's', KEY_t = 't', KEY_u = 'u', KEY_v = 'v', KEY_w = 'w', KEY_x = 'x', KEY_y = 'y', KEY_z = 'z', KEY_enter = '\n', KEY_CR = '\r', KEY_TAB = 9, KEY_ESC = 27, KEY_SPACE = 32, KEY_TILDE = 192, PRNT_SCRN = 44, _ };

pub const WindowSize = struct {
    width: u32,
    height: u32,
};
pub const WindowChangeCallback = common.Callback(WindowSize);
pub const KeyChangeCallback = common.Callback(KEYS);
pub const MouseChangeCallback = common.Callback(MouseEvent);

pub const MouseEvent = struct {
    x: i16,
    y: i16,
    clicked: bool,
    scroll_up: bool,
    scroll_down: bool,
    ctrl_pressed: bool,
};

pub const EventManager = struct {
    main_thread: std.Thread = undefined,
    running: bool = false,
    key_up_callback: ?KeyChangeCallback = null,
    key_down_callback: ?KeyChangeCallback = null,
    key_press_callback: ?KeyChangeCallback = null,
    window_change_callback: ?WindowChangeCallback = null,
    mouse_event_callback: ?MouseChangeCallback = null,
    original_termios: termios = undefined,
    stdin: std.fs.File,
    xlib: Xlib = undefined,
    const Self = @This();
    pub const Error = error{ WindowsInit, WindowsRead, PosixInit, FileLocksNotSupported, FileBusy } || std.posix.TermiosGetError || std.posix.TermiosSetError || std.Thread.SpawnError || std.fs.File.Reader.NoEofError || std.posix.ReadError || std.posix.ReadLinkError || std.fs.SelfExePathError;
    pub const termios = switch (builtin.os.tag) {
        .windows => std.os.windows.DWORD,
        else => std.posix.termios,
    };
    pub fn init() EventManager {
        return EventManager{ .stdin = std.io.getStdIn() };
    }

    pub fn deinit(self: *Self) Error!void {
        try self.stop();
    }

    pub fn stop(self: *Self) Error!void {
        if (self.running) {
            self.running = false;
            self.main_thread.join();
            try self.cook();
        }
    }

    fn cook(self: *Self) Error!void {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleMode(self.stdin.handle, self.original_termios);
        } else {
            if (std.c.tcsetattr(self.stdin.handle, .FLUSH, &self.original_termios) == 1) {
                return Error.PosixInit;
            }
        }
    }

    fn raw_mode(self: *Self) Error!void {
        if (builtin.os.tag == .windows) {
            if (std.os.windows.kernel32.GetConsoleMode(self.stdin.handle, &self.original_termios) != std.os.windows.TRUE) {
                return Error.WindowsInit;
            }
            var raw: termios = self.original_termios;
            const ENABLE_ECHO_INPUT: std.os.windows.DWORD = 0x0004;
            const ENABLE_MOUSE_INPUT: std.os.windows.DWORD = 0x0010;
            const ENABLE_EXTENDED_FLAGS: std.os.windows.DWORD = 0x0080;
            const ENABLE_LINE_INPUT: std.os.windows.DWORD = 0x0002;
            const ENABLE_PROCESSED_INPUT: std.os.windows.DWORD = 0x0001;
            const ENABLE_WINDOW_INPUT: std.os.windows.DWORD = 0x0008;
            raw = 0;
            raw = raw & ~(ENABLE_ECHO_INPUT) | ENABLE_MOUSE_INPUT | (ENABLE_EXTENDED_FLAGS) & ~(ENABLE_LINE_INPUT) & ~(ENABLE_PROCESSED_INPUT) | ENABLE_WINDOW_INPUT;
            EVENT_LOG.info("old mode {x}\n", .{self.original_termios});
            EVENT_LOG.info("setting mode {x}\n", .{self.original_termios & ~(ENABLE_ECHO_INPUT) | ENABLE_MOUSE_INPUT | (ENABLE_EXTENDED_FLAGS) & ~(ENABLE_LINE_INPUT) & ~(ENABLE_PROCESSED_INPUT) | ENABLE_WINDOW_INPUT});
            if (std.os.windows.kernel32.SetConsoleMode(self.stdin.handle, raw) != std.os.windows.TRUE) {
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

            raw.cc[@as(usize, @intFromEnum(std.posix.V.TIME))] = 0;
            raw.cc[@as(usize, @intFromEnum(std.posix.V.MIN))] = 1;
            if (std.c.tcsetattr(self.stdin.handle, .FLUSH, &raw) == 1) {
                return Error.PosixInit;
            }
        }
    }

    pub fn start(self: *Self) Error!void {
        try self.raw_mode();
        self.running = true;
        self.main_thread = try std.Thread.spawn(.{}, event_loop, .{self});
    }

    fn event_loop(self: *Self) Error!void {
        if (builtin.os.tag == .windows) {
            var irInBuf: [128]win32.INPUT_RECORD = undefined;
            var numRead: u32 = undefined;
            while (self.running) {
                _ = win32.GetNumberOfConsoleInputEvents(self.stdin.handle, &numRead);
                if (numRead > 0) {
                    if (win32.ReadConsoleInputW(self.stdin.handle, &irInBuf, 128, &numRead) != std.os.windows.TRUE) {
                        return Error.WindowsRead;
                    } else {
                        //EVENT_LOG.info("{any}\n", .{irInBuf});
                        for (0..numRead) |i| {
                            EVENT_LOG.info("{any}\n", .{irInBuf[i].EventType});
                            switch (irInBuf[i].EventType) {
                                @intFromEnum(win32.EventType.KEY_EVENT) => {
                                    if (self.key_down_callback != null and irInBuf[i].Event.KeyEvent.bKeyDown == std.os.windows.TRUE) {
                                        self.key_down_callback.?.call(@enumFromInt(irInBuf[i].Event.KeyEvent.uChar.AsciiChar));
                                    } else if (self.key_up_callback != null and irInBuf[i].Event.KeyEvent.bKeyDown == std.os.windows.FALSE) {
                                        self.key_up_callback.?.call(@enumFromInt(irInBuf[i].Event.KeyEvent.uChar.AsciiChar));
                                    } else if (self.key_press_callback != null and irInBuf[i].Event.KeyEvent.bKeyDown == std.os.windows.FALSE) {
                                        self.key_press_callback.?.call(@enumFromInt(irInBuf[i].Event.KeyEvent.uChar.AsciiChar));
                                    }
                                },
                                @intFromEnum(win32.EventType.WINDOW_BUFFER_SIZE) => {
                                    if (self.window_change_callback != null) {
                                        EVENT_LOG.info("{any}\n", .{irInBuf[i].Event.WindowBufferSizeEvent.dwSize});
                                        self.window_change_callback.?.call(.{ .width = @as(u32, @bitCast(@as(i32, @intCast(irInBuf[i].Event.WindowBufferSizeEvent.dwSize.X)))), .height = @as(u32, @bitCast(@as(i32, @intCast(irInBuf[i].Event.WindowBufferSizeEvent.dwSize.Y)))) });
                                    }
                                },
                                @intFromEnum(win32.EventType.MOUSE_EVENT) => {
                                    if (self.mouse_event_callback != null) {
                                        EVENT_LOG.info("{any}\n", .{irInBuf[i].Event.MouseEvent});
                                        self.mouse_event_callback.?.call(.{
                                            .x = irInBuf[i].Event.MouseEvent.dwMousePosition.X,
                                            .y = irInBuf[i].Event.MouseEvent.dwMousePosition.Y,
                                            .clicked = (irInBuf[i].Event.MouseEvent.dwButtonState & 0x01) != 0,
                                            .scroll_up = ((irInBuf[i].Event.MouseEvent.dwButtonState & 0x10000000) != 0) and irInBuf[i].Event.MouseEvent.dwEventFlags & 0x04 != 0,
                                            .scroll_down = ((irInBuf[i].Event.MouseEvent.dwButtonState & 0x10000000) == 0) and irInBuf[i].Event.MouseEvent.dwEventFlags & 0x04 != 0,
                                            .ctrl_pressed = irInBuf[i].Event.MouseEvent.dwControlKeyState & 0x08 != 0,
                                        });
                                    }
                                },
                                //TODO ARROW KEYS
                                //TODO potenial to use  https://learn.microsoft.com/en-us/windows/console/setcurrentconsolefontex https://learn.microsoft.com/en-us/windows/console/getcurrentconsolefontex for zoom
                                //TODO handle non key events
                                else => {},
                            }
                        }
                    }
                }
            }
        } else {
            while (self.running) {
                self.xlib.next_event();
                switch (self.xlib.event_type) {
                    .KeyPress => {
                        const key: KEYS = @enumFromInt(self.xlib.get_event_key());
                        if (self.key_down_callback != null) {
                            self.key_down_callback.?.call(key);
                        }
                    },
                    .KeyRelease => {
                        const key: KEYS = @enumFromInt(self.xlib.get_event_key());
                        if (self.key_up_callback != null) {
                            self.key_up_callback.?.call(key);
                        }
                    },
                }
            }
        }
    }
};
