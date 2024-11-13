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
    is_done: bool = false,

    fsize: usize = 0,
    name: ?[]const u8 = null,
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
    func: ?fn (value: SV) SV = null,
    Write: ?fn (f: IO, vbuf: []u8, count: usize) isize = null,
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

    // f: IO, vbuf: []u8, count: usize) isize
    pub fn init(comptime fun: fn (value: SV) SV) IO_funcs {
        return .{ .func = fun };
    }

    fn deinit(self: IO_funcs) !void {
        //  self.out
        _ = self;
    }
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

    pub fn intmode2str(rawmode: i32, mode: []u8, writing: []i32) i32 {
        _ = rawmode;
        _ = mode;
        _ = writing;
        return 0;
    }
    // pub fn apply_layers()
    // int
    // PerlIO_apply_layers(pTHX_ PerlIO *f, const char *mode, const char *names)
    // int
    // PerlIO_binmode(pTHX_ PerlIO *fp, int iotype, int mode, const char *names)

    // PerlIO *
    // PerlIO_fdupopen(pTHX_ PerlIO *f, CLONE_PARAMS *param, int flags)

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
    // SSize_t
    // Perl_PerlIO_write(pTHX_ PerlIO *f, const void *vbuf, Size_t count)
    // {
    //      PERL_ARGS_ASSERT_PERLIO_WRITE;

    //      Perl_PerlIO_or_fail(f, Write, -1, (aTHX_ f, vbuf, count));
    // }
    // int
    // PerlIO_vprintf(PerlIO *f, const char *fmt, va_list ap)
    // {
    //     dTHX;
    //     SV * sv;
    //     const char *s;
    //     STRLEN len;
    //     SSize_t wrote;
    // #ifdef NEED_VA_COPY
    //     va_list apc;
    //     Perl_va_copy(ap, apc);
    //     sv = vnewSVpvf(fmt, &apc);
    //     va_end(apc);
    // #else
    //     sv = vnewSVpvf(fmt, &ap);
    // #endif
    //     s = SvPV_const(sv, len);
    //     wrote = PerlIO_write(f, s, len);
    //     SvREFCNT_dec(sv);
    //     return wrote;
    // }

    // #undef PerlIO_printf
    // int
    // PerlIO_printf(PerlIO *f, const char *fmt, ...)
    // {
    //     va_list ap;
    //     int result;
    //     va_start(ap, fmt);
    //     result = PerlIO_vprintf(f, fmt, ap);
    //     va_end(ap);
    //     return result;
    // }
    //     int
    // PerlIO_stdoutf(const char *fmt, ...)
    // {
    //     dTHX;
    //     va_list ap;
    //     int result;
    //     va_start(ap, fmt);
    //     result = PerlIO_vprintf(PerlIO_stdout(), fmt, ap);
    //     va_end(ap);
    //     return result;
    // }
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

fn _write(f: IO, vbuf: []u8, count: usize) isize {
    _ = f;
    _ = vbuf;
    _ = count;
    return 0;
}

// const S = struct {
pub fn foo(value: SV) SV {
    std.debug.print("Hi!\n", .{});
    return value;
}
// };

pub fn IO_stdout() IO {
    // if (!perlio) {}
    // const stdout = io.getStdOut();

    // const outw = std.io.getStdOut().writer();
    // return outw;
    // return io[2].next;
    return .{
        .tab = IO_funcs.init(foo),
        //fn (f: IO, vbuf: []u8, count: usize) isize{
        // _ = f;
        // _ = vbuf;
        // _ = count;
        // return 0},
        // .Write = fn (f: *IO, vbuf: []u8, count: usize) isize{return f},
        // .Write = fn (f: *IO, vbuf: []u8, count: usize) isize{return 1;},
        // ?fn (f: *IO, vbuf: []u8, count: usize) isize

        // },
    };
}

test "basic" {
    try testing.expect(true);
    const stdout = IO_stdout();
    _ = stdout.tab.?.func.?(.{ .IV = 3 });

    // ?fn (f: IO, vbuf: []u8, count: usize) isize
    // stdout.tab?.func(.{ .IV = 3 });
}
