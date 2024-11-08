const std = @import("std");
const heap = std.heap;
const process = std.process;
const fatal = process.fatal;
const mem = std.mem;
const debug = std.debug;
const io = std.io;
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

    var result: Args = .{ .exe = exe, .cmd = cmd, .argv = std.ArrayList([]const u8).init(allocator) };
    // defer result.argv.deinit();

    while (args.next()) |arg| {
        try result.argv.append(arg);
    }

    if (mem.eql(u8, cmd, "build")) {} else if (mem.eql(u8, cmd, "clean")) {} else if (mem.eql(u8, cmd, "docs")) {} else if (mem.eql(u8, cmd, "env")) {} else if (mem.eql(u8, cmd, "fmt")) {} else if (mem.eql(u8, cmd, "help")) {
        try display_help(exe);
    } else if (mem.eql(u8, cmd, "install")) {} else if (mem.eql(u8, cmd, "run")) {} else if (mem.eql(u8, cmd, "repl")) {} else if (mem.eql(u8, cmd, "new")) {} else if (mem.eql(u8, cmd, "test")) {} else if (mem.eql(u8, cmd, "version")) {}

    // defer result.argv.deinit();

    return result;
}

pub const Init = struct { cmd: []const u8, exe: []const u8, verbose: bool = false, prefix: ?[]const u8 = null, argv: ?[]const []const u8 = null };

pub fn argv_2() !void {
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

    const args = try process.argsAlloc(alloc);
    defer process.argsFree(alloc, args);

    // skip my own exe name
    var arg_idx: usize = 0;

    var builder = Init{
        .exe = nextArg(args, &arg_idx) orelse
            fatalWithHint("missing compiler path", .{}),
        .cmd = nextArg(args, &arg_idx) orelse
            fatalWithHint("missing compiler command", .{}),
        .argv =

        //  std.ArrayList([]const u8).init(alloc)

        argsRest(args, arg_idx),
    };
    // defer builder.deinit();

    std.debug.print("exe: {s}\n", .{builder.exe});
    std.debug.print("cmd: {s}\n", .{builder.cmd});

    var output_tmp_nonce: ?[16]u8 = null;
    var help_menu: bool = false;

    while (nextArg(args, &arg_idx)) |arg| {
        std.debug.print("arg[{}]: {s}\n", .{ arg_idx, builder.exe });
        if (mem.startsWith(u8, arg, "-Z")) {
            if (arg.len != 18) fatalWithHint("bad argument: '{s}'", .{arg});
            output_tmp_nonce = arg[2..18].*;
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                help_menu = true;
            }
            // else if (mem.eql(u8, arg, "-I") or mem.eql(u8, arg, "--prefix")) {
            //     builder.prefix = nextArgOrFatal(args, &arg_idx);
            // }
            else {
                fatalWithHint("unrecognized argument: '{s}'", .{arg});
            }
        } else {
            // try builder.argv.append(arg);
        }
    }

    //
    const stdout_writer = io.getStdOut().writer();

    if (help_menu)
        return usage(builder, stdout_writer);
}

test "Here we go..." {
    return;
}

fn nextArg(args: [][:0]const u8, idx: *usize) ?[:0]const u8 {
    if (idx.* >= args.len) return null;
    defer idx.* += 1;
    return args[idx.*];
}

fn nextArgOrFatal(args: [][:0]const u8, idx: *usize) [:0]const u8 {
    return nextArg(args, idx) orelse {
        std.debug.print("expected argument after '{s}'\n  access the help menu with 'zig build -h'\n", .{args[idx.* - 1]});
        process.exit(1);
    };
}

fn argsRest(args: [][:0]const u8, idx: usize) ?[][:0]const u8 {
    if (idx >= args.len) return null;
    return args[idx..];
}

/// Perhaps in the future there could be an Advanced Options flag such as
/// --debug-build-runner-leaks which would make this function return instead of
/// calling exit.
fn cleanExit() void {
    std.debug.lockStdErr();
    process.exit(0);
}

/// Perhaps in the future there could be an Advanced Options flag such as
/// --debug-build-runner-leaks which would make this function return instead of
/// calling exit.
fn uncleanExit() error{UncleanExit} {
    std.debug.lockStdErr();
    process.exit(1);
}

fn fatalWithHint(comptime f: []const u8, args: anytype) noreturn {
    std.debug.print(f ++ "\n  access the help menu with 'brocken help'\n", args);
    process.exit(1);
}

fn usage(b: Init, out_stream: anytype) !void {
    try out_stream.print(
        \\Usage: {s} [command] [options]
        \\
        \\Steps:
        \\
    , .{b.exe});
    // for (b.argv) |arg| {
    // try out_stream.print("item: {s}", .{arg});
    // }
    // try steps(b, out_stream);

    // try out_stream.writeAll(
    //     \\
    //     \\General Options:
    //     \\  -p, --prefix [path]          Where to install files (default: zig-out)
    //     \\  --prefix-lib-dir [path]      Where to install libraries
    //     \\  --prefix-exe-dir [path]      Where to install executables
    //     \\  --prefix-include-dir [path]  Where to install C header files
    //     \\
    //     \\  --release[=mode]             Request release mode, optionally specifying a
    //     \\                               preferred optimization mode: fast, safe, small
    //     \\
    //     \\  -fdarling,  -fno-darling     Integration with system-installed Darling to
    //     \\                               execute macOS programs on Linux hosts
    //     \\                               (default: no)
    //     \\  -fqemu,     -fno-qemu        Integration with system-installed QEMU to execute
    //     \\                               foreign-architecture programs on Linux hosts
    //     \\                               (default: no)
    //     \\  --glibc-runtimes [path]      Enhances QEMU integration by providing glibc built
    //     \\                               for multiple foreign architectures, allowing
    //     \\                               execution of non-native programs that link with glibc.
    //     \\  -frosetta,  -fno-rosetta     Rely on Rosetta to execute x86_64 programs on
    //     \\                               ARM64 macOS hosts. (default: no)
    //     \\  -fwasmtime, -fno-wasmtime    Integration with system-installed wasmtime to
    //     \\                               execute WASI binaries. (default: no)
    //     \\  -fwine,     -fno-wine        Integration with system-installed Wine to execute
    //     \\                               Windows programs on Linux hosts. (default: no)
    //     \\
    //     \\  -h, --help                   Print this help and exit
    //     \\  -l, --list-steps             Print available steps
    //     \\  --verbose                    Print commands before executing them
    //     \\  --color [auto|off|on]        Enable or disable colored error messages
    //     \\  --prominent-compile-errors   Buffer compile errors and display at end
    //     \\  --summary [mode]             Control the printing of the build summary
    //     \\    all                        Print the build summary in its entirety
    //     \\    new                        Omit cached steps
    //     \\    failures                   (Default) Only print failed steps
    //     \\    none                       Do not print the build summary
    //     \\  -j<N>                        Limit concurrent jobs (default is to use all CPU cores)
    //     \\  --maxrss <bytes>             Limit memory usage (default is to use available memory)
    //     \\  --skip-oom-steps             Instead of failing, skip steps that would exceed --maxrss
    //     \\  --fetch                      Exit after fetching dependency tree
    //     \\  --watch                      Continuously rebuild when source files are modified
    //     \\  --fuzz                       Continuously search for unit test failures
    //     \\  --debounce <ms>              Delay before rebuilding after changed file detected
    //     \\     -fincremental             Enable incremental compilation
    //     \\  -fno-incremental             Disable incremental compilation
    //     \\
    //     \\Project-Specific Options:
    //     \\
    // );

    // const arena = b.allocator;
    // if (b.available_options_list.items.len == 0) {
    //     try out_stream.print("  (none)\n", .{});
    // } else {
    //     for (b.available_options_list.items) |option| {
    //         const name = try fmt.allocPrint(arena, "  -D{s}=[{s}]", .{
    //             option.name,
    //             @tagName(option.type_id),
    //         });
    //         try out_stream.print("{s:<30} {s}\n", .{ name, option.description });
    //         if (option.enum_options) |enum_options| {
    //             const padding = " " ** 33;
    //             try out_stream.writeAll(padding ++ "Supported Values:\n");
    //             for (enum_options) |enum_option| {
    //                 try out_stream.print(padding ++ "  {s}\n", .{enum_option});
    //             }
    //         }
    //     }
    // }

    // try out_stream.writeAll(
    //     \\
    //     \\System Integration Options:
    //     \\  --search-prefix [path]       Add a path to look for binaries, libraries, headers
    //     \\  --sysroot [path]             Set the system root directory (usually /)
    //     \\  --libc [file]                Provide a file which specifies libc paths
    //     \\
    //     \\  --system [pkgdir]            Disable package fetching; enable all integrations
    //     \\  -fsys=[name]                 Enable a system integration
    //     \\  -fno-sys=[name]              Disable a system integration
    //     \\
    //     \\  Available System Integrations:                Enabled:
    //     \\
    // );
    // if (b.graph.system_library_options.entries.len == 0) {
    //     try out_stream.writeAll("  (none)                                        -\n");
    // } else {
    //     for (b.graph.system_library_options.keys(), b.graph.system_library_options.values()) |k, v| {
    //         const status = switch (v) {
    //             .declared_enabled => "yes",
    //             .declared_disabled => "no",
    //             .user_enabled, .user_disabled => unreachable, // already emitted error
    //         };
    //         try out_stream.print("    {s:<43} {s}\n", .{ k, status });
    //     }
    // }

    // try out_stream.writeAll(
    //     \\
    //     \\Advanced Options:
    //     \\  -freference-trace[=num]      How many lines of reference trace should be shown per compile error
    //     \\  -fno-reference-trace         Disable reference trace
    //     \\  -fallow-so-scripts           Allows .so files to be GNU ld scripts
    //     \\  -fno-allow-so-scripts        (default) .so files must be ELF files
    //     \\  --build-file [file]          Override path to build.zig
    //     \\  --cache-dir [path]           Override path to local Zig cache directory
    //     \\  --global-cache-dir [path]    Override path to global Zig cache directory
    //     \\  --zig-lib-dir [arg]          Override path to Zig lib directory
    //     \\  --build-runner [file]        Override path to build runner
    //     \\  --seed [integer]             For shuffling dependency traversal order (default: random)
    //     \\  --debug-log [scope]          Enable debugging the compiler
    //     \\  --debug-pkg-config           Fail if unknown pkg-config flags encountered
    //     \\  --debug-rt                   Debug compiler runtime libraries
    //     \\  --verbose-link               Enable compiler debug output for linking
    //     \\  --verbose-air                Enable compiler debug output for Zig AIR
    //     \\  --verbose-llvm-ir[=file]     Enable compiler debug output for LLVM IR
    //     \\  --verbose-llvm-bc=[file]     Enable compiler debug output for LLVM BC
    //     \\  --verbose-cimport            Enable compiler debug output for C imports
    //     \\  --verbose-cc                 Enable compiler debug output for C compilation
    //     \\  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
    //     \\
    // );
}
