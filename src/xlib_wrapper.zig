const std = @import("std");

pub const XExtData = extern struct {
    number: i32,
    next: ?*XExtData,
    free_private: *const fn () callconv(.C) c_int,
    private_data: XPointer,
};

pub const ScreenFormat = extern struct {
    ext_data: *XExtData,
    depth: i32,
    bits_per_pixel: i32,
    scan_line_pad: i32,
};

pub const KeyCode = u8;

pub const XmodifierKeymap = extern struct {
    max_keypermod: i32,
    modifiermap: [*]KeyCode,
};

pub const FreeFuncType = *const fn (display: ?*Display) callconv(.C) void;
pub const FreeModmapType = *const fn (xmodifier_keymap: *XmodifierKeymap) callconv(.C) c_int;

pub const XFreeFuncs = extern struct {
    atoms: FreeFuncType,
    modifiermap: FreeModmapType,
    key_bindings: FreeFuncType,
    context_db: FreeFuncType,
    defaultCCCs: FreeFuncType,
    clientCmaps: FreeFuncType,
    intensityMaps: FreeFuncType,
    im_filters: FreeFuncType,
    xkb: FreeFuncType,
};

pub const XSQEvent = extern struct { next: *XSQEvent, event: XEvent, qserial_num: u32 };

pub const XrmQuark = extern struct {};

pub const NTable = extern struct {
    next: *NTable,
    name: XrmQuark,
    tight: u32 = 1,
    leaf: u32 = 1,
    hasloose: u32 = 1,
    hasany: u32 = 1,
    pad: u32 = 4,
    mask: u32 = 8,
    entries: u32 = 16,
};
pub const XmbInitProc = *const fn (state: XPointer) callconv(.C) void;
pub const XmbCharProc = *const fn (state: XPointer, str: XPointer, lenp: *i32) callconv(.C) u8;
pub const XmbFinishProc = *const fn (state: XPointer) callconv(.C) void;
pub const XlcNameProc = *const fn (state: XPointer) callconv(.C) XPointer;
pub const XrmDestroyProc = *const fn (state: XPointer) callconv(.C) void;

pub const XrmMethods = extern struct {
    mbinit: XmbInitProc,
    mbchar: XmbCharProc,
    mbfinish: XmbFinishProc,
    lcname: XlcNameProc,
    destroy: XrmDestroyProc,
};

// XTHREADS LockInfoRec linfo
pub const XrmHashBucketRec = extern struct {
    table: NTable,
    mbstate: XPointer,
    methods: XrmMethods,
};

pub const Depth = extern struct {
    depth: i32,
    nvisuals: i32,
    visuals: [*]Visual,
};

pub const Visual = extern struct {
    ext_data: *XExtData,
    visualid: VisualID,
    class: i32,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    bits_per_rgb: i32,
    map_entries: i32,
};

pub const GC = extern struct {
    ext_data: *XExtData,
    gid: GContext,
};

pub const Screen = extern struct {
    ext_data: *XExtData,
    display: ?*Display,
    root: Window,
    width: i32,
    height: i32,
    mwidth: i32,
    mheight: i32,
    ndepths: i32,
    depths: [*]Depth,
    root_depth: i32,
    root_visual: *Visual,
    default_gc: GC,
    cmap: Colormap,
    white_pixel: u32,
    black_pixel: u32,
    max_maps: i32,
    min_maps: i32,
    backing_store: i32,
    save_unders: bool,
    root_input_mask: i32,
};

pub const XExtCodes = extern struct {
    extension: i32,
    major_opcode: i32,
    first_event: i32,
    first_error: i32,
};

pub const XFontProp = extern struct {
    name: Atom,
    card32: u32,
};

pub const XCharStruct = extern struct {
    lbearing: i16,
    rbearing: i16,
    width: i16,
    ascent: i16,
    descent: i16,
    attributes: u16,
};

pub const XFontStruct = extern struct {
    ext_data: *XExtData,
    fid: Font,
    direction: u8,
    min_char_or_byte2: u8,
    max_char_or_byte2: u8,
    min_byte1: u8,
    max_byte1: u8,
    all_chars_exist: bool,
    default_char: u8,
    n_properties: i32,
    properties: [*]XFontProp,
    min_bounds: XCharStruct,
    max_bounds: XCharStruct,
    per_char: *XCharStruct,
    ascent: i32,
    descent: i32,
};

pub const XError = extern struct {
    type: u8,
    errorCode: u8,
    sequenceNumber: u16,
    resourceID: u32,
    minorCode: u16,
    majorCode: u8,
    pad1: u8,
    pad3: u32,
    pad4: u32,
    pad5: u32,
    pad6: u32,
    pad7: u32,
};

pub const XExten = extern struct {
    next: *XExten,
    codes: XExtCodes,
    create_GC: *const fn (?*Display, GC, *XExtCodes) callconv(.C) i32,
    copy_GC: *const fn (?*Display, GC, *XExtCodes) callconv(.C) i32,
    flush_GC: *const fn (?*Display, GC, *XExtCodes) callconv(.C) i32,
    free_GC: *const fn (?*Display, GC, *XExtCodes) callconv(.C) i32,
    create_Font: *const fn (?*Display, *XFontStruct, *XExtCodes) callconv(.C) i32,
    free_Font: *const fn (?*Display, *XFontStruct, *XExtCodes) callconv(.C) i32,
    close_display: *const fn (?*Display, *XExtCodes) callconv(.C) i32,
    err: *const fn (?*Display, *XError, *XExtCodes, *i32) callconv(.C) i32,
    error_string: *const fn (?*Display, i32, *XExtCodes, XPointer, i32) callconv(.C) i32,
    name: XPointer,
    error_values: *const fn (?*Display, *XErrorEvent, *anyopaque) callconv(.C) i32,
    before_flush: *const fn (?*Display, *XExtCodes, XPointer, i32) callconv(.C) i32,
};

pub const xEvent = extern struct {};

pub const XLockInfo = extern struct {};

pub const XInternalAsync = extern struct {};

pub const XLockPtrs = extern struct {};

pub const XKeytrans = extern struct {};

pub const XDisplayAtoms = extern struct {};

pub const XContextDB = extern struct {};

pub const XIMFilter = extern struct {};

pub const XConnectionInfo = extern struct {};

pub const XConnWatchInfo = extern struct {};

pub const XkbInfoRec = extern struct {};

pub const XtransConnInfo = extern struct {};

pub const XsetWindowAttributes = extern struct {};

// https://cgit.freedesktop.org/xorg/proto/xproto/tree/Xproto.h

//pub const Display = extern struct {};

pub const Display = extern struct {
    ext_data: *XExtData,
    free_funcs: *XFreeFuncs,
    fd: i32,
    conn_checker: i32,
    proto_major_version: i32,
    proto_minor_version: i32,
    vendor: XPointer,
    resource_base: u32,
    resource_mask: u32,
    resource_id: u32,
    resource_shift: i32,
    resource_alloc: *const fn (?*Display) callconv(.C) u32,
    byte_order: i32,
    bitmap_unit: i32,
    bitmap_pad: i32,
    bitmap_bit_order: i32,
    nformats: i32,
    pixmap_format: ScreenFormat,
    vnumber: i32,
    release: i32,
    head: *XSQEvent,
    tail: *XSQEvent,
    qlen: i32,
    last_request_read: u32,
    request: u32,
    last_req: XPointer,
    buffer: XPointer,
    bufptr: XPointer,
    bufmax: XPointer,
    max_request_size: u32,
    db: *XrmHashBucketRec,
    synchandler: *const fn (?*Display) callconv(.C) i32,
    display_name: XPointer,
    default_screen: i32,
    nscreens: i32,
    screens: [*]Screen,
    motion_buffer: u32,
    flags: u32,
    min_keycode: i32,
    max_keycode: i32,
    keysyms: [*]KeySym,
    modifiermap: *XmodifierKeymap,
    keysyms_per_keycode: i32,
    xdefaults: XPointer,
    scratch_buffer: XPointer,
    scratch_length: u32,
    ext_number: i32,
    ext_procs: *XExten,
    event_vec: *const fn (?*Display, *XEvent, *xEvent) callconv(.C) bool,
    wire_vec: *const fn (?*Display, *XEvent, *xEvent) callconv(.C) i32,
    lock_meaning: KeySym,
    lock: *XLockInfo,
    async_handlers: *XInternalAsync,
    bigreq_size: u32,
    lock_fns: *XLockPtrs,
    idlist_alloc: *const fn (?*Display, u32, i32) callconv(.C) void,
    key_bindings: *XKeytrans,
    cursor_font: Font,
    atoms: *XDisplayAtoms,
    mode_switch: u32,
    num_lock: u32,
    context_db: *XContextDB,
    error_vec: *const *fn (?*Display, *XErrorEvent, *XError) callconv(.C) bool,
    cms: extern struct { defaultCCCs: XPointer, clientCmaps: XPointer, perVisualIntensityMaps: XPointer },
    im_filters: *XIMFilter,
    qfree: *XSQEvent,
    next_event_serial_num: u32,
    flushes: *XExten,
    im_fd_info: *XConnectionInfo,
    im_fd_length: i32,
    conn_watchers: *XConnWatchInfo,
    watcher_count: i32,
    filedes: XPointer,
    savedsynchandler: *const fn (?*Display) callconv(.C) i32,
    resource_max: u32,
    xcmisc_opcode: i32,
    xkb_info: *XkbInfoRec,
    trans_conn: *XtransConnInfo,
};

pub const Window = c_ulong;
pub const Drawable = u32;
pub const Time = u32;
pub const Atom = u32;
pub const Colormap = u32;
pub const XPointer = [*]u8;
pub const VisualID = u32;
pub const GContext = u32;
pub const KeySym = u32;
pub const Font = u32;

//TODO might need to convert bool to int type
pub const XAnyEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
};

pub const XKeyEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    keycode: u32,
    same_screen: bool,
};

pub const XButtonEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    keycode: u32,
    same_screen: bool,
};

pub const XMotionEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    keycode: u32,
    same_screen: bool,
};

pub const XCrossingEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    mode: i32,
    detail: i32,
    same_screen: bool,
    focus: bool,
    state: u32,
};

pub const XFocusChangeEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    mode: i32,
    detail: i32,
};

pub const XExposeEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    count: i32,
};

pub const XGraphicsExposeEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    drawable: Drawable,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    count: i32,
    major_code: i32,
    minor_code: i32,
};

pub const XNoExposeEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    drawable: Drawable,
    major_code: i32,
    minor_code: i32,
};

pub const XVisibilityEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    state: i32,
};

pub const XCreateWindowEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    parent: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    override_redirect: bool,
};

pub const XDestroyWindowEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
};

pub const XUnmapEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
    from_configure: bool,
};

pub const XMapEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
    override_redirect: bool,
};

pub const XMapRequestEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    parent: Window,
    window: Window,
};

pub const XReparentEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
    parent: Window,
    x: i32,
    y: i32,
    override_redirect: bool,
};

pub const XConfigureEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    above: Window,
    override_redirect: bool,
};

pub const XGravityEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
    x: i32,
    y: i32,
};

pub const XResizeRequestEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    width: i32,
    height: i32,
};

pub const XConfigureRequestEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    parent: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    above: Window,
    detail: i32,
    value_mask: u32,
};

pub const XCirculateEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    event: Window,
    window: Window,
    place: i32,
};

pub const XCirculateRequestEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    parent: Window,
    window: Window,
    place: i32,
};

pub const XPropertyEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    atom: Atom,
    time: Time,
    state: i32,
};

pub const XSelectionClearEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    selection: Atom,
    time: Time,
};

pub const XSelectionRequestEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    owner: Window,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const XSelectionEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const XColormapEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    colormap: Colormap,
    new: bool,
    state: i32,
};

pub const XClientMessageEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    message_type: Atom,
    format: i32,
    data: Data,
    pub const Data = extern union {
        b: [20]u8,
        s: [10]u16,
        l: [5]u32,
    };
};

pub const XMappingEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    request: i32,
    first_keycode: i32,
    count: i32,
};

pub const XErrorEvent = extern struct {
    type: i32,
    display: ?*Display,
    serial: u32,
    error_code: u8,
    request_code: u8,
    minor_code: u8,
    resource_id: u32,
};

pub const XKeymapEvent = extern struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: ?*Display,
    window: Window,
    key_vector: [32]u8,
};

pub const EventMask = enum(i32) {
    KeyPressMask = 1,
    KeyReleaseMask = 2,
};

pub const EventType = enum(c_int) {
    KeyPress = 2,
    KeyRelease = 3,
};

pub const WindowClass = enum(c_int) {
    InputOnly = 2,
};

pub const XEvent = extern struct {
    type: i32,
    xany: XAnyEvent,
    xkey: XKeyEvent,
    xbutton: XButtonEvent,
    xmotion: XMotionEvent,
    xcrossing: XCrossingEvent,
    xfocus: XFocusChangeEvent,
    xexpose: XExposeEvent,
    xgraphicsexpose: XGraphicsExposeEvent,
    xnoexpose: XNoExposeEvent,
    xvisibility: XVisibilityEvent,
    xcreatewindow: XCreateWindowEvent,
    xdestroywindow: XDestroyWindowEvent,
    xunmap: XUnmapEvent,
    xmap: XMapEvent,
    xmaprequest: XMapRequestEvent,
    xreparent: XReparentEvent,
    xconfigure: XConfigureEvent,
    xgravity: XGravityEvent,
    xresizerequest: XResizeRequestEvent,
    xconfigurerequest: XConfigureRequestEvent,
    xcirculate: XCirculateEvent,
    xcirculaterequest: XCirculateRequestEvent,
    xproperty: XPropertyEvent,
    xselectionclear: XSelectionClearEvent,
    xselectionrequest: XSelectionRequestEvent,
    xselection: XSelectionEvent,
    xcolormap: XColormapEvent,
    xclient: XClientMessageEvent,
    xmapping: XMappingEvent,
    xerror: XErrorEvent,
    xkeymap: XKeymapEvent,
    pad: [24]i32,
};

pub const CurrentTime: Time = 0;

pub extern fn XOpenDisplay(display_name: ?[*:0]const u8) ?*Display;
pub extern fn XSelectInput(display: ?*Display, w: Window, event_mask: c_int) c_int;
pub extern fn XNextEvent(display: ?*Display, event_return: ?*XEvent) c_int;
pub extern fn XDefaultRootWindow(?*Display) Window;
pub extern fn XCloseDisplay(?*Display) c_int;
pub extern fn XMapWindow(?*Display, Window) c_int;
pub extern fn XGrabKeyboard(?*Display, Window, bool, c_int, c_int, Time) c_int;
pub extern fn XSetErrorHandler(*const fn (?*Display, ?*XErrorEvent) callconv(.C) c_int) c_int;
pub extern fn XCreateWindow(?*Display, Window, c_int, c_int, c_ulong, c_ulong, c_ulong, c_int, c_ulong, ?*Visual, c_ulong, ?*XsetWindowAttributes) Window;

//pub extern "C" fn XSelectInput(display: *Display, root_window: Window) i32;

pub fn handler(_: ?*Display, e: ?*XErrorEvent) callconv(.C) c_int {
    std.debug.print("error {any}\n", .{e});
    return 0;
}

// test "open" {
//     var res = XSetErrorHandler(handler);
//     std.debug.print("function success\n", .{});
//     std.debug.print("res {any}\n", .{res});
//     const display: ?*Display = XOpenDisplay(null);
//     std.debug.print("function success\n", .{});
//     const root_window = XDefaultRootWindow(display);
//     const window = XCreateWindow(display, root_window,-99, -99, 1, 1, 0, 0, @intFromEnum(WindowClass.InputOnly),null,0, null);
//     std.debug.print("function success\n", .{});
//     std.debug.print("window {any}\n", .{window});
//     res = XSelectInput(display, window, @intFromEnum(EventMask.KeyPressMask) | @intFromEnum(EventMask.KeyReleaseMask));
//     std.debug.print("function success\n", .{});
//     std.debug.print("res {any}\n", .{res});
//     res = XMapWindow(display, window);
//     std.debug.print("function success\n", .{});
//     std.debug.print("res {any}\n", .{res});
//     res = XGrabKeyboard(display, window, false, 1, 1, CurrentTime);
//     std.debug.print("function success\n", .{});
//     std.debug.print("res {any}\n", .{res});
//     var running: bool = true;
//     var event: XEvent = undefined;
//     std.debug.print("starting loop\n",.{});
//     while (running) {
//         res = XNextEvent(display, &event);
//         std.debug.print("event type {any}\n", .{event.type});
//         if (event.type == @intFromEnum(EventType.KeyPress)) {
//             std.debug.print("keycode {any}\n", .{event.xkey.keycode});
//             if (event.xkey.keycode == 0x09 or event.xkey.keycode == 113) {
//                 running = false;
//             }
//         }
//     }
//     res = XCloseDisplay(display);
//     std.debug.print("function success\n", .{});
//     std.debug.print("res {any}\n", .{res});
// }
