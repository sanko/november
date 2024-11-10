const std = @import("std");
const testing = std.testing;

pub fn is_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

test "is_digit" {
    try testing.expect(is_digit('A') == false);
    try testing.expect(is_digit('1') == true);
}

pub fn is_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

test "is_alpha" {
    try testing.expect(is_alpha('A') == true);
    try testing.expect(is_alpha('_') == true);
    try testing.expect(is_alpha('1') == false);
    try testing.expect(is_alpha(' ') == false);
}

pub fn is_alphanumeric(c: u8) bool {
    return is_alpha(c) or is_digit(c);
}

test "is_alphanumeric" {
    try testing.expect(is_alphanumeric('A') == true);
    try testing.expect(is_alphanumeric('1') == true);
    try testing.expect(is_alphanumeric('A') == true);
    try testing.expect(is_alphanumeric('_') == true);
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
