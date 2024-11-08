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
    const env_map = try process.getEnvMap(arena);

    return mainArgs(gpa, arena, args, env_map);
}

test "wow" {
    const gpa = std.testing.allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args = &.{ "fake.exe", "help", "c", "d" };
    try std.testing.expectEqual(1, 1);
    const env_map = try process.getEnvMap(arena);
    try mainArgs(gpa, arena, args, env_map);
    try std.testing.expectEqual(1, 1);
}

const usage =
    \\Usage: brocken [command] [options]
    \\
    \\Commands:
    \\
    \\  build            Build project from meta.json
    \\  fetch            Copy a package into global cache and print its hash
    \\  init             Initialize a package in the current directory
    \\
    \\  build-exe        Create executable from source or object files
    \\  build-lib        Create library from source or object files
    \\  build-obj        Create object from source or object files
    \\  test             Perform unit testing
    \\  run              Create executable and run immediately
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
;

fn mainArgs(gpa: mem.Allocator, arena: mem.Allocator, args: []const []const u8, env: process.EnvMap) !void {
    // const tr = tracy.trace(@src());
    // defer tr.end();
    _ = gpa;

    if (args.len <= 1 and !builtin.is_test) {
        std.log.info("{s}", .{usage});
        fatalWithHint("expected command argument", .{});
    }

    if (process.can_execv and std.posix.getenvZ("ZIG_IS_DETECTING_LIBC_PATHS") != null) {
        // dev.check(.cc_command);
        // In this case we have accidentally invoked ourselves as "the system C compiler"
        // to figure out where libc is installed. This is essentially infinite recursion
        // via child process execution due to the CC environment variable pointing to Zig.
        // Here we ignore the CC environment variable and exec `cc` as a child process.
        // However it's possible Zig is installed as *that* C compiler as well, which is
        // why we have this additional environment variable here to check.

        const inf_loop_env_key = "ZIG_IS_TRYING_TO_NOT_CALL_ITSELF";
        if (env.get(inf_loop_env_key) != null) {
            fatalWithHint("The compilation links against libc, but Zig is unable to provide a libc " ++
                "for this operating system, and no --libc " ++
                "parameter was provided, so Zig attempted to invoke the system C compiler " ++
                "in order to determine where libc is installed. However the system C " ++
                "compiler is `zig cc`, so no libc installation was found.", .{});
        }
        try env.put(inf_loop_env_key, "1");

        // Some programs such as CMake will strip the `cc` and subsequent args from the
        // CC environment variable. We detect and support this scenario here because of
        // the ZIG_IS_DETECTING_LIBC_PATHS environment variable.
        if (mem.eql(u8, args[1], "cc")) {
            //return process.execve(arena, args[1..], &env);
        } else {
            const modified_args = try arena.dupe([]const u8, args);
            modified_args[0] = "cc";
            //return process.execve(arena, modified_args, &env);
        }
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
        // dev.check(.help_command);
        // return io.getStdOut().writeAll(usage);
    } else {
        std.log.info("{s}", .{usage});
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
