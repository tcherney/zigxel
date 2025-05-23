const std = @import("std");

//TODO we may want to return to this idea, call everything from c then just build a wrapper around the event struct
// const c = @cImport({
//     @cInclude("X11/Xlib.h");
// });

pub const XExtData = struct {
    number: i32,
    next: *Self,
    free_private: fn() i32,
    private_data: XPointer,
    pub const Self = @This();
};

pub const ScreenFormat = struct {
    ext_data: *XExtData,
    depth: i32,
    bits_per_pixel: i32,
    scan_line_pad: i32,
};

pub const KeyCode = u8;

pub const XmodifierKeymap = struct {
    max_keypermod: i32,
    modifiermap: [*]KeyCode,
};

pub const FreeFuncType = fn(display: *Display) void;
pub const FreeModmapType = fn(xmodifier_keymap: *XmodifierKeymap) i32;

pub const XFreeFuncs = struct {
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

pub const XSQEvent = struct {
    next: *XSQEvent,
    event: XEvent,
    qserial_num: u32
};

pub const NTable = struct {
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
pub const XmbInitProc = fn(state: XPointer) void;
pub const XmbCharProc = fn(state: XPointer, str: XPointer, lenp: *i32) u8;
pub const XmbFinishProc = fn(state: XPointer) void;
pub const XlcNameProc = fn(state: XPointer) XPointer;
pub const XrmDestroyProc = fn(state: XPointer) void;

pub const XrmMethods = struct {
    mbinit: XmbInitProc,
    mbchar: XmbCharProc,
    mbfinish: XmbFinishProc,
    lcname: XlcNameProc,
    destroy: XrmDestroyProc,
};

// XTHREADS LockInfoRec linfo
pub const XrmHashBucketRec = struct {
    table: NTable,
    mbstate: XPointer,
    methods: XrmMethods,
};

pub const Depth = struct {
    depth: i32,
    nvisuals: i32,
    visuals: [*]Visual,
};

pub const Visual = struct {
    ext_data: *XExtData,
    visualid: VisualID,
    class: i32,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    bits_per_rgb: i32,
    map_entries: i32,
};

pub const GC = struct {
    ext_data: *XExtData,
    gid: GContext,
};

pub const Screen = struct {
    ext_data: *XExtData,
    display: *Display,
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

pub const Display = struct {
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
    resource_alloc: fn (Self) u32,
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
    synchandler: fn(*Self) i32,
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
	int keysyms_per_keycode;/* number of rows */
	char *xdefaults;	/* contents of defaults from server */
	char *scratch_buffer;	/* place to hang scratch buffer */
	unsigned long scratch_length;	/* length of scratch buffer */
	int ext_number;		/* extension number on this display */
	struct _XExten *ext_procs; /* extensions initialized on this display */
	/*
	 * the following can be fixed size, as the protocol defines how
	 * much address space is available. 
	 * While this could be done using the extension vector, there
	 * may be MANY events processed, so a search through the extension
	 * list to find the right procedure for each event might be
	 * expensive if many extensions are being used.
	 */
	Bool (*event_vec[128])(	/* vector for wire to event */
		Display *	/* dpy */,
		XEvent *	/* re */,
		xEvent *	/* event */
		);
	Status (*wire_vec[128])( /* vector for event to wire */
		Display *	/* dpy */,
		XEvent *	/* re */,
		xEvent *	/* event */
		);
	KeySym lock_meaning;	   /* for XLookupString */
	struct _XLockInfo *lock;   /* multi-thread state, display lock */
	struct _XInternalAsync *async_handlers; /* for internal async */
	unsigned long bigreq_size; /* max size of big requests */
	struct _XLockPtrs *lock_fns; /* pointers to threads functions */
	void (*idlist_alloc)(	   /* XID list allocator function */
		Display *	/* dpy */,
		XID *		/* ids */,
		int		/* count */
		);
	/* things above this line should not move, for binary compatibility */
	struct _XKeytrans *key_bindings; /* for XLookupString */
	Font cursor_font;	   /* for XCreateFontCursor */
	struct _XDisplayAtoms *atoms; /* for XInternAtom */
	unsigned int mode_switch;  /* keyboard group modifiers */
	unsigned int num_lock;  /* keyboard numlock modifiers */
	struct _XContextDB *context_db; /* context database */
	Bool (**error_vec)(	/* vector for wire to error */
		Display     *	/* display */,
		XErrorEvent *	/* he */,
		xError      *	/* we */
		);
	/*
	 * Xcms information
	 */
	struct {
	   XPointer defaultCCCs;  /* pointer to an array of default XcmsCCC */
	   XPointer clientCmaps;  /* pointer to linked list of XcmsCmapRec */
	   XPointer perVisualIntensityMaps;
				  /* linked list of XcmsIntensityMap */
	} cms;
	struct _XIMFilter *im_filters;
	struct _XSQEvent *qfree; /* unallocated event queue elements */
	unsigned long next_event_serial_num; /* inserted into next queue elt */
	struct _XExten *flushes; /* Flush hooks */
	struct _XConnectionInfo *im_fd_info; /* _XRegisterInternalConnection */
	int im_fd_length;	/* number of im_fd_info */
	struct _XConnWatchInfo *conn_watchers; /* XAddConnectionWatch */
	int watcher_count;	/* number of conn_watchers */
	XPointer filedes;	/* struct pollfd cache for _XWaitForReadable */
	int (*savedsynchandler)( /* user synchandler when Xlib usurps */
		Display *	/* dpy */
		);
	XID resource_max;	/* allocator max ID */
	int xcmisc_opcode;	/* major opcode for XC-MISC */
	struct _XkbInfoRec *xkb_info; /* XKB info */
	struct _XtransConnInfo *trans_conn; /* transport connection object */
    const Self = @This();
};
pub const Window = u32;
pub const Drawable = u32;
pub const Time = u32;
pub const Atom = u32;
pub const Colormap = u32;
pub const XPointer = [*]u8;
pub const VisualID = u32;
pub const GContext = u32;
pub const KeySym = u32;

//TODO might need to convert bool to int type
pub const XAnyEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
};

pub const XKeyEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
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

pub const XButtonEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
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

pub const XMotionEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
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

pub const XCrossingEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
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

pub const XFocusChangeEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    mode: i32,
    detail: i32,
};

pub const XExposeEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    count: i32,
};

pub const XGraphicsExposeEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    drawable: Drawable,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    count: i32,
    major_code: i32,
    minor_code: i32,
};

pub const XNoExposeEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    drawable: Drawable,
    major_code: i32,
    minor_code: i32,
};

pub const XVisibilityEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    state: i32,
};

pub const XCreateWindowEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    parent: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    override_redirect: bool,
};

pub const XDestroyWindowEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    event: Window,
    window: Window,
};

pub const XUnmapEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    event: Window,
    window: Window,
    from_configure: bool,
};

pub const XMapEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    event: Window,
    window: Window,
    override_redirect: bool,
};

pub const XMapRequestEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    parent: Window,
    window: Window,
};

pub const XReparentEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    event: Window,
    window: Window,
    parent: Window,
    x: i32,
    y: i32,
    override_redirect: bool,
};

pub const XConfigureEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
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

pub const XGravityEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    event: Window,
    window: Window,
    x: i32,
    y: i32,
};

pub const XResizeRequestEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    width: i32,
    height: i32,
};

pub const XConfigureRequestEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
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

pub const XCirculateEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    event: Window,
    window: Window,
    place: i32,
};

pub const XCirculateRequestEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    parent: Window,
    window: Window,
    place: i32,
};

pub const XPropertyEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    atom: Atom,
    time: Time,
    state: i32,
};

pub const XSelectionClearEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    selection: Atom,
    time: Time,
};

pub const XSelectionRequestEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    owner: Window,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const XSelectionEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const XColormapEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    colormap: Colormap,
    new: bool,
    state: i32,
};

pub const XClientMessageEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    message_type: Atom,
    format: i32,
    data: Data,
    pub const Data = union {
        b: [20]u8,
        s: [10]u16,
        l: [5]u32,
    };
};

pub const XMappingEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    request: i32,
    first_keycode: i32,
    count: i32,
};

pub const XErrorEvent = struct {
    type: i32,
    display: *Display,
    serial: u32,
    error_code: u8,
    request_code: u8,
    minor_code: u8,
    resource_id: u32,
};

pub const XKeymapEvent = struct {
    type: i32,
    serial: u32,
    send_event: bool,
    display: *Display,
    window: Window,
    key_vector: [32]u8,
};

pub const XEvent = struct {
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

pub extern fn XOpenDisplay(display_name: ?[*:0]const u8) *Display;
pub extern fn XSelectInput(display: *Display, w: Window, event_mask: c_int) c_int;
pub extern fn XNextEvent(display: *Display, event_return: *XEvent) c_int;

//pub extern "C" fn XSelectInput(display: *Display, root_window: Window) i32;

test "open" {
    const display: *Display = XOpenDisplay(null);
    std.debug.print("function success\n", .{});
    std.debug.print("display {any}\n", .{display});
}
