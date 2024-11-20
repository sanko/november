//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const build_options = @import("build_options");
const std = @import("std");
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const process = std.process;
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const testing = std.testing;
pub const rocken = @import("root.zig");
pub const vm = @import("vm.zig");
pub const VM = vm.VM;
pub const Chunk = @import("chunk.zig").Chunk;

// https://utf8everywhere.org/
const CP_UTF8 = 65001;
var prevWinConsoleOutputCP: u32 = undefined;

const use_gpa = (!builtin.link_libc) and native_os != .wasi;

var exe: []const u8 = undefined;
var rvm: rocken.VM = undefined;

const usage: []const u8 =
    \\Brocken. Squint.
    \\Usage: {?s} [command] [options]
    \\
    \\Commands:
    \\
    \\  run              Create executable and run immediately 
    \\  repl             Run a REPL. Same as running without a command
    \\ 
    \\  build            Build project from meta.json
    \\  fetch            Copy a package into global cache and print its hash
    \\  init             Initialize a package in the current directory
    \\  docs             Display documentation for a package or symbol
    \\
    \\  build-exe        Create executable from source or object files
    \\  build-lib        Create library from source or object files
    \\  build-obj        Create object from source or object files
    \\  test             Perform unit testing
    \\
    \\  fmt              Reformat source into canonical form
    \\
    \\  env              Print lib path, std path, cache directory, and version
    \\  help             Print this help and exit
    \\  version          Print version number and exit
    \\
    \\General Options:
    \\
    \\  -h, --help       Print command-specific usage
    \\
;

const usage_help_run: []const u8 =
    \\Brocken. Squint.
    \\Usage: {?s} run [options]
    \\
    \\Commands:
    \\
    \\  run              Create executable and run immediately 
    \\
    \\General Options:
    \\
    \\  -h, --help       Print command-specific usage
    \\
;

pub fn main() !void {
    if (builtin.os.tag == .windows) {
        prevWinConsoleOutputCP = std.os.windows.kernel32.GetConsoleOutputCP();
        _ = std.os.windows.kernel32.SetConsoleOutputCP(CP_UTF8);
    }
    defer {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(prevWinConsoleOutputCP);
        }
    }

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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    // std.debug.print("args.length: {d}\n", .{args.len});

    var env = try process.getEnvMap(allocator);
    defer env.deinit();

    exe = args[0];

    try exit(try mainArgs(allocator, args[1..], env));
}

fn mainArgs(allocator: mem.Allocator, args: []const []const u8, env: process.EnvMap) !u8 {
    _ = env;

    std.debug.print("args.length: {d}\n", .{args.len});

    // //  clear ; zig build run -- test
    // var i: usize = 1;
    for (args[0..], 1..) |arg, i| {
        std.debug.print("{d}: {s}\n", .{ i, arg });

        if (std.mem.eql(u8, arg, "build")) {} else if (std.mem.eql(u8, arg, "fetch")) {} else if (std.mem.eql(u8, arg, "init")) {} else if (std.mem.eql(u8, arg, "docs")) {} else if (std.mem.eql(u8, arg, "build-exe")) {} else if (std.mem.eql(u8, arg, "build-lib")) {} else if (std.mem.eql(u8, arg, "build-obj")) {} else if (std.mem.eql(u8, arg, "test")) {} else if (std.mem.eql(u8, arg, "fmt")) {} else if (std.mem.eql(u8, arg, "help")) {
            if (args.len > 1 and std.mem.eql(u8, args[1], "run"))
                std.debug.print(usage_help_run, .{exe})
            else
                std.debug.print(usage, .{exe});
        } else if (std.mem.eql(u8, arg, "repl")) {} else if (std.mem.eql(u8, arg, "run")) {} else if (std.mem.eql(u8, arg, "env")) {} else if (std.mem.eql(u8, arg, "version")) {
            std.debug.print("Brocken v{s}", .{if (builtin.is_test) "ersion unknown in test build" else build_options.version});
            try exit(0);
        } else if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "--help")) {}
        } else {
            std.debug.print("Error: Unknown parameter ({s})", .{arg});
        }
    }

    // try rvm.init(allocator);
    // defer rvm.deinit();

    var chunky = try Chunk.init(allocator);
    defer chunky.deinit();

    try rvm.init(allocator, chunky);
    defer rvm.deinit();

    return 0;
    // exit(0);

}
test "help" {
    const alloc = std.testing.allocator;
    const args = &.{"help"};
    var env = try process.getEnvMap(alloc);
    defer env.deinit();
    try testing.expectEqual(0, try mainArgs(alloc, args, env));
}
test "help run" {
    const alloc = std.testing.allocator;
    const args = &.{ "help", "run" };
    var env = try process.getEnvMap(alloc);
    defer env.deinit();
    try testing.expectEqual(0, try mainArgs(alloc, args, env));
}

test "version" {
    const alloc = std.testing.allocator;
    const args = &.{"version"};
    var env = try process.getEnvMap(alloc);
    defer env.deinit();
    try testing.expectEqual(0, try mainArgs(alloc, args, env));
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

fn exit(code: u8) error{UncleanExit}!noreturn {
    std.debug.lockStdErr();
    process.exit(code);
    if (code != 0)
        return error{UncleanExit};
}
