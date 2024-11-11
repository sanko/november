const std = @import("std");
const ascii = std.ascii;
const testing = std.testing;

const heap = std.heap;
const process = std.process;
const fatal = process.fatal;
const mem = std.mem;
const debug = std.debug;
const io = std.io;
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const use_gpa = (!builtin.link_libc) and native_os != .wasi;
pub const allocator = allocator: {
    if (native_os == .wasi) {
        break :allocator heap.wasm_allocator;
    }
    if (use_gpa) {
        var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
        _ = general_purpose_allocator.deinit();
        break :allocator general_purpose_allocator.allocator();
    }
    // We would prefer to use raw libc allocator here, but cannot
    // use it if it won't support the alignment we need.
    if (@alignOf(std.c.max_align_t) < @max(@alignOf(i128), std.atomic.cache_line)) {
        break :allocator std.heap.c_allocator;
    }
    break :allocator std.heap.raw_c_allocator;
};

pub fn is_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

test "is_digit" {
    try testing.expect(is_digit('A') == false);
    try testing.expect(is_digit('1') == true);
}

pub fn is_alpha(c: u8) bool {
    return ascii.isAlphabetic(c)
    // or c == '_'
    ;
}

test "is_alpha" {
    try testing.expect(is_alpha('A') == true);
    try testing.expect(is_alpha('_') == false);
    try testing.expect(is_alpha('1') == false);
    try testing.expect(is_alpha(' ') == false);
}

pub fn is_graphical(c: u8) bool {
    return c <= 0x7e and (c >= (' ' + 1));
}
test "is_graphical" {
    try testing.expect(is_graphical('A') == true);
    try testing.expect(is_graphical('_') == true);
    try testing.expect(is_graphical('1') == true);
    try testing.expect(is_graphical(' ') == false);
    try testing.expect(is_graphical(0x7f) == false);
}

pub fn is_lowercase(c: u8) bool {
    return ascii.isLower(c);
}

test "is_lowercase" {
    try testing.expect(is_lowercase('A') == false);
    try testing.expect(is_lowercase('a') == true);
}
pub fn is_uppercase(c: u8) bool {
    return ascii.isUpper(c);
}
test "is_uppercase" {
    try testing.expect(is_uppercase('A') == true);
    try testing.expect(is_uppercase('a') == false);
}

pub fn is_alphanumeric(c: u8) bool {
    return is_alpha(c) or is_digit(c);
}
test "is_alphanumeric" {
    try testing.expect(is_alphanumeric('A') == true);
    try testing.expect(is_alphanumeric('1') == true);
    try testing.expect(is_alphanumeric('A') == true);
    try testing.expect(is_alphanumeric('_') == false);
    try testing.expect(is_alphanumeric(' ') == false);
}

pub fn is_blank(c: u8) bool {
    return c == ' ' or c == '\t';
}

test "is_blank" {
    try testing.expect(is_blank('A') == false);
    try testing.expect(is_blank('\n') == false);
    try testing.expect(is_blank('\t') == true);
    try testing.expect(is_blank(' ') == true);
}

pub fn is_space(c: u8) bool {
    return is_blank(c) //
    or c == 0xb // \v: https://github.com/ziglang/zig/issues/21564
    or c == 0xc // \f
    or c == ' ' or c == '\n' or c == '\r' or c == '\t';
}

test "is_space" {
    try testing.expect(is_space('A') == false);
    try testing.expect(is_space('\n') == true);
    try testing.expect(is_space('\t') == true);
    try testing.expect(is_space(' ') == true);
    try testing.expect(is_space('\r') == true);
    try testing.expect(is_space(0xb) == true);
    try testing.expect(is_space(0xc) == true);
}
// https://github.com/Perl/perl5/blob/c1d61760c1693ea2eb474ef0c5864b85fc7b95e6/handy.h#L1730
