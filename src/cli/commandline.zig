const std = @import("std");
const heap = std.heap;
const process = std.process;
const fatal = process.fatal;
const mem = std.mem;
const debug = std.debug;
const io = std.io;
const builtin = @import("builtin");
const native_os = builtin.os.tag;

pub fn argv() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};

    const use_gpa = (!builtin.link_libc) and native_os != .wasi;
    const gpa = gpa: {
        if (native_os == .wasi) {
            break :gpa std.heap.wasm_allocator;
        }
        if (use_gpa) {
            break :gpa general_purpose_allocator.allocator();
        }
        // We would prefer to use raw libc allocator here, but cannot
        // use it if it won't support the alignment we need.
        if (@alignOf(std.c.max_align_t) < @max(@alignOf(i128), std.atomic.cache_line)) {
            break :gpa std.heap.c_allocator;
        }
        break :gpa std.heap.raw_c_allocator;
    };
    defer if (use_gpa) {
        _ = general_purpose_allocator.deinit();
    };
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try process.argsAlloc(arena);
    var env_map = try process.getEnvMap(arena);
    defer env_map.deinit();
    return mainArgs(gpa, arena, args, env_map);
}
test "help" {
    const gpa = std.testing.allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args = &.{ "fake.exe", "help" };
    try std.testing.expectEqual(1, 1);
    var env_map = try process.getEnvMap(arena);
    defer env_map.deinit();
    try mainArgs(gpa, arena, args, env_map);
    try std.testing.expectEqual(1, 1);
}
test "help help" {
    const gpa = std.testing.allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args = &.{ "fake.exe", "help", "help" };
    try std.testing.expectEqual(1, 1);
    var env_map = try process.getEnvMap(arena);
    defer env_map.deinit();
    try mainArgs(gpa, arena, args, env_map);
    try std.testing.expectEqual(1, 1);
}
test "help run" {
    const gpa = std.testing.allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args = &.{ "fake.exe", "help", "run" };
    try std.testing.expectEqual(1, 1);
    var env_map = try process.getEnvMap(arena);
    defer env_map.deinit();
    try mainArgs(gpa, arena, args, env_map);
    try std.testing.expectEqual(1, 1);
}

fn mainArgs(gpa: mem.Allocator, arena: mem.Allocator, args: []const []const u8, env: process.EnvMap) !void {
    // const tr = tracy.trace(@src());
    // defer tr.end();
    _ = arena;
    _ = gpa;
    _ = env;

    if (args.len <= 1 and !builtin.is_test) {
        // usage(args[0], null);
        // fatal("TODO: kick off REPL", .{});
        repl();
    }

    const cmd = args[1];
    const cmd_args = args[2..];

    // std.debug.print("cmd: {s}\n", .{cmd});

    if (cmd_args.len > 0 and std.mem.eql(u8, cmd_args[0], "--zig-integration")) {}

    if (mem.eql(u8, cmd, "build-exe")) {

        //return try process.execve(arena, modified_args, &env);
        // dev.check(.build_exe_command);
        // return buildOutputType(gpa, arena, args, .{ .build = .Exe });
    }
    if (mem.eql(u8, cmd, "build-lib")) {
        // dev.check(.build_lib_command);
        // return buildOutputType(gpa, arena, args, .{ .build = .Lib });
    } else if (mem.eql(u8, cmd, "version")) {
        // dev.check(.version_command);
        // try std.io.getStdOut().writeAll(build_options.version ++ "\n");
        // Check libc++ linkage to make sure Zig was built correctly, but only
        // for "env" and "version" to avoid affecting the startup time for
        // build-critical commands (check takes about ~10 μs)
        // return verifyLibcxxCorrectlyLinked();
    } else if (mem.eql(u8, cmd, "env")) {
        // dev.check(.env_command);
        // verifyLibcxxCorrectlyLinked();
        // return @import("print_env.zig").cmdEnv(arena, cmd_args, io.getStdOut().writer());
    } else if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "-h") or mem.eql(u8, cmd, "--help")) {
        std.log.info("arg count: {}", .{cmd_args.len});

        var help: ?[]const u8 = null;
        if (cmd_args.len > 0) {
            help = args[2];
        }

        usage(args[0], help);

        // dev.check(.help_command);
        // return io.getStdOut().writeAll(usage);
    } else if (mem.eql(u8, cmd, "repl")) {
        repl();
    } else {
        // std.debug.print("{s}", .{usage});
        usage(args[0], null);
        fatalWithHint("unknown command: {s}", .{args[1]});
    }
}

fn cleanExit() void {
    std.debug.lockStdErr();
    process.exit(0);
}

fn uncleanExit() error{UncleanExit} {
    std.debug.lockStdErr();
    process.exit(1);
}

fn fatalWithHint(comptime f: []const u8, args: anytype) noreturn {
    std.debug.print(f ++ "\n  access the help menu with 'brocken help'\n", args);
    process.exit(1);
}

fn usage(exe: []const u8, cmd: ?[]const u8) void {
    std.debug.print("exe: {?s}\n", .{exe});
    std.debug.print("cmd: {?s}\n", .{cmd});

    if (cmd) |a| {
        if (mem.eql(u8, a, "repl")) {
            return std.debug.print(
                \\Brocken. Squint.
                \\Usage: {?s} repl [options]
                \\
                \\Run a REPL. Same as running without a command
                \\
                \\General Options:
                \\
                \\  -h, --help       Print command-specific usage
                \\    
            , .{exe});
        }
        if (mem.eql(u8, a, "run")) {
            return std.debug.print(
                \\Brocken. Squint.
                \\Usage: {?s} run [options]
                \\
                \\Create executable and run immediately 
                \\
                \\General Options:
                \\
                \\  -h, --help       Print command-specific usage
                \\
            , .{exe});
        }
    }

    return std.debug.print(
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
        \\  doc              Display documentation for a package or symbol
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
        \\  std              View standard library documentation in a browser
        \\  version          Print version number and exit
        \\
        \\General Options:
        \\
        \\  -h, --help       Print command-specific usage
        \\
    , .{exe});

    // if (mem.eql(u8, cmd, "env")) {
    //     return std.log.info("{s}", .{exe});
    // }
    // if (mem.eql(u8, cmd, "env")) {
    //     return std.log.info("{s}", .{exe});
    // }
    // if (mem.eql(u8, cmd, "env")) {
    //     return std.log.info("{s}", .{exe});
    // }
}

fn repl() void {
    var stdin = io.getStdIn();
    // var stdout = io.getStdOut();
    while (true) {
        std.debug.print("> ", .{});
        var line = mem.zeroes([1024]u8);
        const n = stdin.read(&line);

        if (n == error.ReadError) {
            //break;
            // if (n == 0) break;

            cleanExit();
        }

        // ... (lex, parse, and interpret the input)
        const result = line;
        std.debug.print("{?s}\n", .{result});
    }
    return;
}
