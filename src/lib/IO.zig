const std = @import("std");

const debug = std.debug;
const testing = std.testing;
const mem = std.mem;

const heap = std.heap;
const process = std.process;
const fatal = process.fatal;
const io = std.io;
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const sv = @import("SV.zig");
const IV = sv.SV;
const SV = sv.SV;

const perlio = true;

pub const IO_funcs = struct {
    fsize: usize = 0,
    name: ?[]u8 = null,
    size: usize = 0,
    kind: u32 = 0,

    Pushed: ?fn (f: *IO, mode: []u8, arg: SV, tab: *IO_funcs) IV = null,
    Popped: ?fn (f: *IO) IV = null,
    Open: ?fn (tab: *IO_funcs, layers: *IO_list, n: IV, mode: []u8, fd: i32, imode: i32, perm: i32, old: *IO, narg: i32, args: [][]SV, mode: []u8, arg: SV) *IO = null,
    Binmode: ?fn (f: *IO) IV = null,

    // SV *(*Getarg) (pTHX_ PerlIO *f, CLONE_PARAMS *param, int flags);
    // IV (*Fileno) (pTHX_ PerlIO *f);
    // PerlIO *(*Dup) (pTHX_ PerlIO *f, PerlIO *o, CLONE_PARAMS *param, int flags);
    // /* Unix-like functions - cf sfio line disciplines */
    //  SSize_t(*Read) (pTHX_ PerlIO *f, void *vbuf, Size_t count);
    Read: ?fn (f: *IO, vbuf: []u8, count: usize) isize = null,
    Unread: ?fn (f: *IO, vbuf: []u8, count: usize) isize = null,
    Write: ?fn (f: *IO, vbuf: []u8, count: usize) isize = null,
    Seek: ?fn (f: *IO, offset: i32, whence: i32) IV = null,
    Tell: ?fn (f: *IO) i32 = null,
    Close: ?fn (f: *IO) IV = null,

    // /* Stdio-like buffered IO functions */
    // IV (*Flush) (pTHX_ PerlIO *f);
    // IV (*Fill) (pTHX_ PerlIO *f);
    // IV (*Eof) (pTHX_ PerlIO *f);
    // IV (*Error) (pTHX_ PerlIO *f);
    // void (*Clearerr) (pTHX_ PerlIO *f);
    // void (*Setlinebuf) (pTHX_ PerlIO *f);
    // /* Perl's snooping functions */
    // STDCHAR *(*Get_base) (pTHX_ PerlIO *f);
    //  Size_t(*Get_bufsiz) (pTHX_ PerlIO *f);
    // STDCHAR *(*Get_ptr) (pTHX_ PerlIO *f);
    //  SSize_t(*Get_cnt) (pTHX_ PerlIO *f);
    // void (*Set_ptrcnt) (pTHX_ PerlIO *f, STDCHAR * ptr, SSize_t cnt);

};

pub const IO_pair = struct { funs: IO_funcs, arg: []SV };

pub const IO_list = struct { refcnt: IV, cur: IV, len: IV, array: []IO_list };

pub const IO = struct {
    next: ?*IO = null,
    tab: ?IO_funcs = .{},
    flags: ?u32 = 0,
    err: ?i32 = 0,
    os_err: ?u32 = 0, // See https://github.com/Perl/perl5/blob/9a2ba7c5988c48321c87e36f614a11a3c585da61/perliol.h#L71
    head: ?*IO = null,

    pub fn Openn(layers: []u8, mode: []u8, fd: i32, imode: i32, perm: i32, old: *IO, narg: i32, args: []SV) *IO {
        _ = layers;
        _ = mode;
        _ = fd;
        _ = imode;
        _ = perm;
        _ = old;
        _ = narg;
        _ = args;
    }
    pub fn Valid(self: *IO) bool { // Oy
        _ = self;
        return true;
    }
    pub fn IO_or_fail(self: *IO, callback: []u8, args: SV) void {
        _ = callback;
        _ = args;
        if (self.Valid()) {
            // if(.tab and .tab.callback()){
            // (tab.callback()).;
            // }
            // else {

            // throw error
            // }
        }
    }
};

pub const IOBuf = struct {
    base: IO, // Base "class" info
    buf: []u8, // Start of buffer
    end: []u8, // End of valid part of buffer
    ptr: []u8, // Current position in buffer
    posn: i32, // Offset of buf into the file
    bufsiz: isize, // Real size of buffer
    oneword: IV, // Emergency buffer
};

pub fn open() void {}
pub fn close() void {}
pub fn read() void {}
pub fn write() void {}

pub fn IO_stdout() IO {
    // if (!perlio) {}
    // const stdout = io.getStdOut();

    // const outw = std.io.getStdOut().writer();
    // return outw;
    // return io[2].next;
    return .{};
}

test "basic" {
    try testing.expect(true);
    const stdout = IO_stdout();

    _ = stdout;
}
