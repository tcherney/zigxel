const std = @import("std");

//TODO we may want to return to this idea, call everything from c then just build a wrapper around the event struct
// const c = @cImport({
//     @cInclude("X11/Xlib.h");
// });

// struct _XDisplay
// {
// 	XExtData *ext_data;	/* hook for extension to hang data */
// 	struct _XFreeFuncs *free_funcs; /* internal free functions */
// 	int fd;			/* Network socket. */
// 	int conn_checker;         /* ugly thing used by _XEventsQueued */
// 	int proto_major_version;/* maj. version of server's X protocol */
// 	int proto_minor_version;/* minor version of server's X protocol */
// 	char *vendor;		/* vendor of the server hardware */
//         XID resource_base;	/* resource ID base */
// 	XID resource_mask;	/* resource ID mask bits */
// 	XID resource_id;	/* allocator current ID */
// 	int resource_shift;	/* allocator shift to correct bits */
// 	XID (*resource_alloc)(	/* allocator function */
// 		struct _XDisplay*
// 		);
// 	int byte_order;		/* screen byte order, LSBFirst, MSBFirst */
// 	int bitmap_unit;	/* padding and data requirements */
// 	int bitmap_pad;		/* padding requirements on bitmaps */
// 	int bitmap_bit_order;	/* LeastSignificant or MostSignificant */
// 	int nformats;		/* number of pixmap formats in list */
// 	ScreenFormat *pixmap_format;	/* pixmap format list */
// 	int vnumber;		/* Xlib's X protocol version number. */
// 	int release;		/* release of the server */
// 	struct _XSQEvent *head, *tail;	/* Input event queue. */
// 	int qlen;		/* Length of input event queue */
// 	unsigned long last_request_read; /* seq number of last event read */
// 	unsigned long request;	/* sequence number of last request. */
// 	char *last_req;		/* beginning of last request, or dummy */
// 	char *buffer;		/* Output buffer starting address. */
// 	char *bufptr;		/* Output buffer index pointer. */
// 	char *bufmax;		/* Output buffer maximum+1 address. */
// 	unsigned max_request_size; /* maximum number 32 bit words in request*/
// 	struct _XrmHashBucketRec *db;
// 	int (*synchandler)(	/* Synchronization handler */
// 		struct _XDisplay*
// 		);
// 	char *display_name;	/* "host:display" string used on this connect*/
// 	int default_screen;	/* default screen for operations */
// 	int nscreens;		/* number of screens on this server*/
// 	Screen *screens;	/* pointer to list of screens */
// 	unsigned long motion_buffer;	/* size of motion buffer */
// 	unsigned long flags;	   /* internal connection flags */
// 	int min_keycode;	/* minimum defined keycode */
// 	int max_keycode;	/* maximum defined keycode */
// 	KeySym *keysyms;	/* This server's keysyms */
// 	XModifierKeymap *modifiermap;	/* This server's modifier keymap */
// 	int keysyms_per_keycode;/* number of rows */
// 	char *xdefaults;	/* contents of defaults from server */
// 	char *scratch_buffer;	/* place to hang scratch buffer */
// 	unsigned long scratch_length;	/* length of scratch buffer */
// 	int ext_number;		/* extension number on this display */
// 	struct _XExten *ext_procs; /* extensions initialized on this display */
// 	/*
// 	 * the following can be fixed size, as the protocol defines how
// 	 * much address space is available. 
// 	 * While this could be done using the extension vector, there
// 	 * may be MANY events processed, so a search through the extension
// 	 * list to find the right procedure for each event might be
// 	 * expensive if many extensions are being used.
// 	 */
// 	Bool (*event_vec[128])(	/* vector for wire to event */
// 		Display *	/* dpy */,
// 		XEvent *	/* re */,
// 		xEvent *	/* event */
// 		);
// 	Status (*wire_vec[128])( /* vector for event to wire */
// 		Display *	/* dpy */,
// 		XEvent *	/* re */,
// 		xEvent *	/* event */
// 		);
// 	KeySym lock_meaning;	   /* for XLookupString */
// 	struct _XLockInfo *lock;   /* multi-thread state, display lock */
// 	struct _XInternalAsync *async_handlers; /* for internal async */
// 	unsigned long bigreq_size; /* max size of big requests */
// 	struct _XLockPtrs *lock_fns; /* pointers to threads functions */
// 	void (*idlist_alloc)(	   /* XID list allocator function */
// 		Display *	/* dpy */,
// 		XID *		/* ids */,
// 		int		/* count */
// 		);
// 	/* things above this line should not move, for binary compatibility */
// 	struct _XKeytrans *key_bindings; /* for XLookupString */
// 	Font cursor_font;	   /* for XCreateFontCursor */
// 	struct _XDisplayAtoms *atoms; /* for XInternAtom */
// 	unsigned int mode_switch;  /* keyboard group modifiers */
// 	unsigned int num_lock;  /* keyboard numlock modifiers */
// 	struct _XContextDB *context_db; /* context database */
// 	Bool (**error_vec)(	/* vector for wire to error */
// 		Display     *	/* display */,
// 		XErrorEvent *	/* he */,
// 		xError      *	/* we */
// 		);
// 	/*
// 	 * Xcms information
// 	 */
// 	struct {
// 	   XPointer defaultCCCs;  /* pointer to an array of default XcmsCCC */
// 	   XPointer clientCmaps;  /* pointer to linked list of XcmsCmapRec */
// 	   XPointer perVisualIntensityMaps;
// 				  /* linked list of XcmsIntensityMap */
// 	} cms;
// 	struct _XIMFilter *im_filters;
// 	struct _XSQEvent *qfree; /* unallocated event queue elements */
// 	unsigned long next_event_serial_num; /* inserted into next queue elt */
// 	struct _XExten *flushes; /* Flush hooks */
// 	struct _XConnectionInfo *im_fd_info; /* _XRegisterInternalConnection */
// 	int im_fd_length;	/* number of im_fd_info */
// 	struct _XConnWatchInfo *conn_watchers; /* XAddConnectionWatch */
// 	int watcher_count;	/* number of conn_watchers */
// 	XPointer filedes;	/* struct pollfd cache for _XWaitForReadable */
// 	int (*savedsynchandler)( /* user synchandler when Xlib usurps */
// 		Display *	/* dpy */
// 		);
// 	XID resource_max;	/* allocator max ID */
// 	int xcmisc_opcode;	/* major opcode for XC-MISC */
// 	struct _XkbInfoRec *xkb_info; /* XKB info */
// 	struct _XtransConnInfo *trans_conn; /* transport connection object */
// };

pub const Display = struct {
    //TODO
};
pub const Window = u32;
pub const Drawable = u32;
pub const Time = u32;
pub const Atom = u32;
pub const Colormap = u32;

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
