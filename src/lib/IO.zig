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

pub fn stderr(data: []const u8, length: usize, offset: isize) usize {
    _ = length;
    _ = offset;
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend std.io.getStdErr().writer().print("{s}", .{data}) catch return 0;
    return data.len;
}

pub fn stdout(data: []const u8, length: usize, offset: isize) usize {
    _ = length;
    _ = offset;
    nosuspend std.io.getStdOut().writer().print("{s}", .{data}) catch return 0;
    return data.len;
}

test "STDOUT" {
    _ = stdout("Oh, yeah", 7, 0);
    try testing.expect(true);
}

test "STDIN" {
    try testing.expect(true);
}
