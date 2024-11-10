const std = @import("std");
const math = std.math;
const mem = std.mem;
const ascii = std.ascii;
const unicode = std.unicode;
const debug = std.debug;
const testing = std.testing;
const filesystem = std.fs;
const heap = std.heap;

const token = @import("Token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const Scanner = @import("Scanner.zig");

const builtin = @import("builtin");

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
