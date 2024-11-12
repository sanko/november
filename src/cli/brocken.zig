const std = @import("std");
const heap = std.heap;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");

const cmdline = @import("commandline.zig");

pub fn main() (error{ OutOfMemory, Overflow, InvalidUsage, FileSystem, InvalidExe, ExecvError, InvalidCharacter, DoesntTakeValue, MissingValue, MissingCommand, NameNotPartOfEnum, MissingArg1 } || std.fs.File.OpenError || std.fs.File.ReadError || std.fs.File.WriteError)!void {
    try cmdline.argv();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test {
    std.testing.refAllDecls(@This());
}
