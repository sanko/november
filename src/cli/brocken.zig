const std = @import("std");
const heap = std.heap;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");

const cmdline = @import("commandline.zig");

pub fn main() (error{ OutOfMemory, Overflow, InvalidUsage } || std.fs.File.OpenError || std.fs.File.ReadError || std.fs.File.WriteError)!void {
    if (0 == 1) {
        try cmdline.argv_2();
        const args = try cmdline.argv();

        std.debug.print("exe: {?s}\n", .{args.exe});

        if (mem.eql(u8, args.cmd.?, "run")) {
            std.debug.print("command is {?s}\n", .{args.cmd});
            for (args.argv.items) |arg| {
                std.debug.print("   arg: {s}\n", .{arg});
            }
        }

        // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
        std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

        // stdout is for the actual output of your application, for example if you
        // are implementing gzip, then only the compressed bytes should be sent to
        // stdout, not any debugging messages.
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        const stdout = bw.writer();

        try stdout.print("Run `zig build test` to run the tests.\n", .{});

        try bw.flush(); // don't forget to flush!
    } else {
        try cmdline.argv_2();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
