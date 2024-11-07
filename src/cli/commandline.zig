const std = @import("std");
const heap = std.heap;
const process = std.process;
const mem = std.mem;
const debug = std.debug;
const builtin = @import("builtin");

pub const Args = struct {
    exe: ?[]const u8,
    cmd: ?[]const u8,
    argv: std.ArrayList([]const u8),
    // args: ?std.ArrayList(u8) = null,
};

fn display_help(exe: ?[]const u8) !void {
    std.debug.print("Usage: {?s} [command]\n", .{exe});
    std.debug.print("\nOptions:\n", .{});
    std.debug.print("  -e, -E  Enable/disable feature E\n", .{});
    std.debug.print("  -w, -s  Enable/disable features W and S\n", .{});
    std.debug.print("  -f FILE  Specify input file\n", .{});
    std.debug.print("  -h, --help  Print this help message\n", .{});
    std.debug.print("\nCommands:\n", .{});
    std.debug.print("  command1  Description of command 1\n", .{});
    std.debug.print("  command2  Description of command 2\n", .{});

    std.process.exit(0);
}

pub fn argv() (error{ OutOfMemory, Overflow, InvalidUsage })!Args {
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
    var args = try process.argsWithAllocator(alloc);

    const exe = args.next();
    const cmd = args.next() orelse {
        return error.InvalidUsage;
        // std.log.err("usage: {s} \"[command]\"", .{exe.?});
        // std.process.exit(0);
    };
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (mem.eql(u8, cmd, "help")) {
        try display_help(exe);
    }

    var result: Args = .{ .exe = exe, .cmd = cmd, .argv = std.ArrayList([]const u8).init(allocator) };
    // defer result.argv.deinit();

    while (args.next()) |arg| {
        try result.argv.append(arg);
    }

    // defer result.argv.deinit();

    return result;
}

pub fn argvx() (error{ OutOfMemory, Overflow, InvalidUsage })!Args {
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

    // Sample starts heretest "argsWithAllocator - get an iterator, use an allocator" {
    var args = try std.process.argsWithAllocator(alloc);
    //defer std.process.argsFree(alloc, args);
    // defer alloc.free(args);
    defer args.deinit();

    var result: Args = .{};
    var i: usize = 0;
    //const procname = args.next();
    // https://renatoathaydes.github.io/zig-common-tasks/#user-input
    while (args.next()) |arg| {
        // std.debug.print("--> {s}", .{arg});
        switch (arg[0]) {
            //'-',
            '-' => {
                switch (arg[1]) {
                    'e' => result.e = true,
                    'E' => result.E = true,
                    'w' => result.w = true,
                    's' => result.s = true,
                    // 'f' => {
                    //     if (i + 1 >= args.len) {
                    //         return error.InvalidUsage;
                    //     }
                    //     result.filename = .Some(args[i + 1]);
                    //     i += 1;
                    // },
                    'h', '?' => {},
                    else => return error.InvalidUsage,
                }
            },
            // else => result.filename = arg,
            // else => result.commands = result.commands ++ arg,

            else => {
                result.command = arg;
                if (mem.eql(u8, arg, "run")) {
                    while (args.next()) |ARGV| {
                        std.debug.print("argv: {?s}\n", .{ARGV});
                        // result.args.add(ARGV);
                    }
                    // const path = args.next();
                    // debug.print("run: {?s}", .{path});
                }
                //result.filename = arg;
                // std.debug.print("command: {?s}\n", .{result.command});
            },
        }
        i += 1;
    }
    return result;
}
