// https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b
// https://github.com/ziglang/zig/blob/862266514ae184eb743959bd0a67db0628b5247a/lib/compiler/test_runner.zig#L92
// https://testanything.org/tap-version-13-specification.html
const std = @import("std");
const process = std.process;
const builtin = @import("builtin");
const debug = std.debug;

const Allocator = std.mem.Allocator;

// use in custom panic handler
var current_test: ?[]const u8 = null;

pub fn main() !void {
    @disableInstrumentation();
    const test_fn_list = builtin.test_functions;
    var mem: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&mem);

    const allocator = fba.allocator();

    const env = Env.init(allocator);
    defer env.deinit(allocator);

    var slowest = SlowTracker.init(allocator, 5);
    defer slowest.deinit();

    var pass: usize = 0;
    var fail: usize = 0;
    var skip: usize = 0;
    var leak: usize = 0;
    // var current: usize = 0;

    const tap = TAP.init();
    // tap.fmt("\r\x1b[0K", .{}); // beginning of line and clear to end of line
    tap.fmt("1..{d}\n", .{test_fn_list.len});

    for (test_fn_list, 1..) |t, current| {
        const friendly_name = friendlyName(t.name);
        tap.fmt("# SUBTEST: {s}\n", .{friendly_name});

        if (isSetup(t)) {
            t.func() catch |err| {
                tap.status(.fail, "Bail out! Setup for \"{s}\" failed: {}\n", .{ t.name, err });
                return err;
            };
        }
        if (isTeardown(t)) {
            continue;
        }

        var status = Status.pass;
        slowest.startTiming();

        const is_unnamed_test = isUnnamed(t);
        if (env.filter) |f| {
            if (!is_unnamed_test and std.mem.indexOf(u8, t.name, f) == null) {
                continue;
            }
        }

        std.testing.allocator_instance = .{};
        const result = t.func();
        current_test = null;

        if (is_unnamed_test) {
            continue;
        }

        const ns_taken = slowest.endTiming(friendly_name);

        if (std.testing.allocator_instance.deinit() == .leak) {
            leak += 1;
            // tap.status(.fail, "Memory Leak\n{s}\n", .{ friendly_name });
        }

        if (result) |_| {
            pass += 1;
            tap.status(.pass, "ok {d} - {s}\n", .{ current, friendly_name });
        } else |err| switch (err) {
            TAP.SKIP => {
                skip += 1;
                status = .skip;
                tap.status(.skip, "ok {d} # skip {s}\n", .{ current, friendly_name });
            },
            TAP.TODO => {},
            else => {
                status = .fail;
                fail += 1;
                tap.status(.fail, "{s}\n{s}\n", .{
                    friendly_name,
                    @errorName(err),
                });
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                if (env.fail_first) {
                    break;
                }
            },
        }

        if (env.verbose) {
            const ms = @as(f64, @floatFromInt(ns_taken)) / 1_000_000.0;
            tap.status(status, "# {d:.2}ms\n", .{ms});
        } else {
            tap.status(status, ".", .{});
        }
    }

    for (builtin.test_functions, 1..) |t, i| {
        if (isTeardown(t)) {
            current_test = friendlyName(t.name);
            t.func() catch |err| {
                tap.status(.fail, "\nteardown \"{s}\" failed: {}\n", .{ t.name, err });
                return err;
            };
        }
        tap.status(.pass, "    ok {d} - {s}\n", .{ i, t.name });
    }

    const total_tests = pass + fail;
    const status = if (fail == 0)
        Status.pass
    else
        Status.fail;
    tap.status(status, "\n{d} of {d} test{s} passed\n", .{ pass, total_tests, if (total_tests != 1) "s" else "" });
    if (skip > 0) {
        tap.status(.skip, "{d} test{s} skipped\n", .{ skip, if (skip != 1) "s" else "" });
    }
    if (leak > 0) {
        tap.status(.fail, "{d} test{s} leaked\n", .{ leak, if (leak != 1) "s" else "" });
    }
    tap.fmt("\n", .{});
    try slowest.display(tap);
    tap.fmt("\n", .{});
    if (fail == 0) {
        return cleanExit();
    }
    return uncleanExit();
}

fn friendlyName(name: []const u8) []const u8 {
    var it = std.mem.splitScalar(u8, name, '.');
    while (it.next()) |value| {
        if (std.mem.eql(u8, value, "test")) {
            const rest = it.rest();
            return if (rest.len > 0) rest else name;
        }
    }
    return name;
}

const have_tty = std.io.getStdErr().isTty();

pub const TAP = struct {
    pub const TODO = error.TODO;
    pub const SKIP = error.SKIP;

    out: std.fs.File.Writer,
    pass: usize = 0,
    fail: usize = 0,
    skip: usize = 0,
    depth: usize = 0,

    fn init() TAP {
        return .{
            .out = std.io.getStdErr().writer(),
        };
    }
    fn deinit(self: TAP) !void {
        //  self.out
        _ = self;
    }

    fn fmt(self: TAP, comptime format: []const u8, args: anytype) void {
        // if (!have_tty) {
        std.fmt.format(self.out, format, args) catch unreachable;
        // }
    }

    fn status(self: TAP, s: Status, comptime format: []const u8, args: anytype) void {
        const color = switch (s) {
            .pass => "\x1b[32m",
            .fail => "\x1b[31m",
            .skip => "\x1b[33m",
            else => "",
        };
        const out = self.out;
        out.writeAll(color) catch @panic("writeAll failed?!");
        std.fmt.format(out, format, args) catch @panic("std.fmt.format failed?!");
        self.fmt("\x1b[0m", .{});
    }
};

const Status = enum {
    pass,
    fail,
    skip,
    text,
};

const SlowTracker = struct {
    const SlowestQueue = std.PriorityDequeue(TestInfo, void, compareTiming);
    max: usize,
    slowest: SlowestQueue,
    timer: std.time.Timer,

    fn init(allocator: Allocator, count: u32) SlowTracker {
        const timer = std.time.Timer.start() catch @panic("failed to start timer");
        var slowest = SlowestQueue.init(allocator, {});
        slowest.ensureTotalCapacity(count) catch @panic("OOM");
        return .{
            .max = count,
            .timer = timer,
            .slowest = slowest,
        };
    }

    const TestInfo = struct {
        ns: u64,
        name: []const u8,
    };

    fn deinit(self: SlowTracker) void {
        self.slowest.deinit();
    }

    fn startTiming(self: *SlowTracker) void {
        self.timer.reset();
    }

    fn endTiming(self: *SlowTracker, test_name: []const u8) u64 {
        var timer = self.timer;
        const ns = timer.lap();

        var slowest = &self.slowest;

        if (slowest.count() < self.max) {
            // Capacity is fixed to the # of slow tests we want to track
            // If we've tracked fewer tests than this capacity, than always add
            slowest.add(TestInfo{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
            return ns;
        }

        {
            // Optimization to avoid shifting the dequeue for the common case
            // where the test isn't one of our slowest.
            const fastest_of_the_slow = slowest.peekMin() orelse unreachable;
            if (fastest_of_the_slow.ns > ns) {
                // the test was faster than our fastest slow test, don't add
                return ns;
            }
        }

        // the previous fastest of our slow tests, has been pushed off.
        _ = slowest.removeMin();
        slowest.add(TestInfo{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
        return ns;
    }

    fn display(self: *SlowTracker, tap: TAP) !void {
        var slowest = self.slowest;
        const count = slowest.count();
        tap.fmt("Slowest {d} test{s}: \n", .{ count, if (count != 1) "s" else "" });
        while (slowest.removeMinOrNull()) |info| {
            const ms = @as(f64, @floatFromInt(info.ns)) / 1_000_000.0;
            tap.fmt("  {d:.2}ms\t{s}\n", .{ ms, info.name });
        }
    }

    fn compareTiming(context: void, a: TestInfo, b: TestInfo) std.math.Order {
        _ = context;
        return std.math.order(a.ns, b.ns);
    }
};

const Env = struct {
    verbose: bool,
    fail_first: bool,
    filter: ?[]const u8,

    fn init(allocator: Allocator) Env {
        return .{
            .verbose = readEnvBool(allocator, "TEST_VERBOSE", true),
            .fail_first = readEnvBool(allocator, "TEST_FAIL_FIRST", false),
            .filter = readEnv(allocator, "TEST_FILTER"),
        };
    }

    fn deinit(self: Env, allocator: Allocator) void {
        if (self.filter) |f| {
            allocator.free(f);
        }
    }

    fn readEnv(allocator: Allocator, key: []const u8) ?[]const u8 {
        const v = std.process.getEnvVarOwned(allocator, key) catch |err| {
            if (err == error.EnvironmentVariableNotFound) {
                return null;
            }
            std.log.warn("failed to get env var {s} due to err {}", .{ key, err });
            return null;
        };
        return v;
    }

    fn readEnvBool(allocator: Allocator, key: []const u8, deflt: bool) bool {
        const value = readEnv(allocator, key) orelse return deflt;
        defer allocator.free(value);
        return std.ascii.eqlIgnoreCase(value, "true");
    }
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    if (current_test) |ct| {
        std.debug.print("\x1b[31m\npanic running \"{s}\"\x1b[0m\n", .{ct});
    }
    std.debug.defaultPanic(msg, error_return_trace, ret_addr);
}

fn isUnnamed(t: std.builtin.TestFn) bool {
    const marker = ".test_";
    const test_name = t.name;
    const index = std.mem.indexOf(u8, test_name, marker) orelse return false;
    _ = std.fmt.parseInt(u32, test_name[index + marker.len ..], 10) catch return false;
    return true;
}

fn isSetup(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:beforeAll");
}

fn isTeardown(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:afterAll");
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
