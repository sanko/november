const std = @import("std");
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;

const ascii = std.ascii;
const unicode = std.unicode;
const debug = std.debug;
const testing = std.testing;
const filesystem = std.fs;
const heap = std.heap;

const builtin = @import("builtin");
const native_os = builtin.os.tag;

const Async = @import("Async.zig");

const Chunk = @import("Chunk.zig");
const FFI = @import("FFI.zig");
const handy = @import("handy.zig");

const IO = @import("IO.zig");

const Scanner = @import("Scanner.zig");
const SV = @import("SV.zig");
const token = @import("Token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const version = std.SemanticVersion.parse("0.0.1-dev0");
const use_gpa = (!builtin.link_libc) and native_os != .wasi;

pub fn generate_allocator() Allocator {
    const allocator = gp: {
        if (native_os == .wasi) {
            break :gp heap.wasm_allocator;
        }
        if (use_gpa) {
            var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
            //general_purpose_allocator.deinit();
            break :gp general_purpose_allocator.allocator();
        }
        // We would prefer to use raw libc allocator here, but cannot
        // use it if it won't support the alignment we need.
        if (@alignOf(std.c.max_align_t) < @max(@alignOf(i128), std.atomic.cache_line)) {
            break :gp std.heap.c_allocator;
        }
        break :gp std.heap.raw_c_allocator;
    };
    return allocator;
}

test "hello_world" {
    const alloc = init: { // https://zig.guide/standard-library/allocators
        if (builtin.is_test) {
            break :init std.testing.allocator;
        } else if (builtin.os.tag == .wasi) {
            var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
            break :init general_purpose_allocator.allocator();
        } else {
            break :init heap.page_allocator;
        }
    };

    const source = try filesystem.cwd().readFileAlloc(alloc, "eg/hello_world.br", std.math.maxInt(usize));
    defer alloc.free(source);

    // const it = unicode.Utf8View.initComptime("こんにちは、世界！Hello, World!");
    const it = unicode.Utf8View.initUnchecked(source);
    var it1 = it.iterator();
    try testing.expect(mem.eql(u8, "s", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "u", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "b", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, " ", it1.nextCodepointSlice().?));
    // try testing.expect(mem.eql(u8, "こ", it1.nextCodepointSlice().?));
}

test {
    testing.refAllDecls(@This());
}

test {
    _ = Async;
    _ = Chunk;
    _ = FFI;
    _ = handy;
    _ = IO;
    _ = Scanner;
    _ = SV;
    _ = Token;
    // const Async = @import("Async.zig");

    // const Chunk = @import("Chunk.zig");
    // const handy = @import("handy.zig");

    // const IO = @import("IO.zig");

    // const Scanner = @import("Scanner.zig");
    // const SV = @import("SV.zig");
    // const token = @import("Token.zig");
    // const Token = token.Token;
    // const TokenType = token.TokenType;
}
