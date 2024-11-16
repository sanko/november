//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const testing = std.testing;

pub const rocken = @import("root.zig");
pub const vm = @import("vm.zig");

pub const VM = vm.VM;

const CP_UTF8 = 65001;
var prevWinConsoleOutputCP: u32 = undefined;

const use_gpa = (!builtin.link_libc) and native_os != .wasi;

var rvm: rocken.VM = undefined;

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

    try rvm.init(allocator);
    defer rvm.deinit();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
