const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const native_os = builtin.os.tag;
const testing = std.testing;
const heap = std.heap;

/// While a release is in development, this string should contain the version in development
/// with the "-dev" suffix.
/// When a release is tagged, the "-dev" suffix should be removed for the commit that gets tagged.
/// Directly after the tagged commit, the version should be bumped and the "-dev" suffix added.
const version = "0.0.1-dev";

const use_gpa = (!builtin.link_libc) and native_os != .wasi;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const full_version = blk: {
        if (mem.endsWith(u8, version, "-dev")) {
            var ret: u8 = undefined;

            const git_describe_long = b.runAllowFail(
                &.{ "git", "-C", b.build_root.path orelse ".", "describe", "--long", "--all" },
                &ret,
                .Inherit,
            ) catch break :blk version;

            var it = mem.splitSequence(u8, mem.trim(u8, git_describe_long, &std.ascii.whitespace), "-");
            _ = it.next().?; // previous tag
            const commit_count = it.next().?;
            const commit_hash = it.next().?;
            // assert(it.next() == null);
            // assert(commit_hash[0] == 'g');

            // Follow semantic versioning, e.g. 0.2.0-dev.42+d1cf95b
            break :blk b.fmt(version ++ ".{s}+{s}", .{ commit_count, commit_hash[1..] });
        } else {
            break :blk version;
        }
    };

    const lib = b.addStaticLibrary(.{
        .name = "roken",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const exe = b.addExecutable(.{ .name = "brocken", .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize, .version = .{ .major = 0, .minor = 14, .patch = 0 } });

    const options = b.addOptions();
    options.addOption([]const u8, "version", full_version);
    exe.root_module.addOptions("build_options", options);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .test_runner = b.path("src/test.zig"),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .test_runner = b.path("src/test.zig"),
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    const step =
        add_t(b, target, optimize) catch {
        return;
    };

    test_step.dependOn(step);
}

pub fn add_t(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step {
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

    const test_step = b.step(
        "t",
        "Run unit tests",
    );

    var dir = try std.fs.cwd().openDir("t", .{ .iterate = true });
    defer dir.close();
    // var dirIterator = dir.iterate();

    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        // std.debug.print("{s}|{s}\n", .{ entry.path, entry.basename });

        if (entry.kind == .file) {
            // test_count += 1;
            const mock_gen = b.addTest(.{
                .name = entry.basename,
                .root_source_file = b.path(try std.fs.path.join(allocator, &[_][]const u8{ "t", entry.path })),
                .target = target,
                .optimize = optimize,
                .test_runner = b.path("src/test.zig"),
            });
            // mock_gen.setMainPkgPath(".");
            const mock_gen_run = b.addRunArtifact(mock_gen);
            // test_step.dependOn(&r
            test_step.dependOn(&mock_gen_run.step);
        }
    }
    return test_step;
}
