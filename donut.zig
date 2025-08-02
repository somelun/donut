const std = @import("std");

var should_exit = std.atomic.Value(bool).init(false);

fn waitForEnter() !void {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    _ = try reader.readByte();

    should_exit.store(true, .seq_cst);
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    const N = 100;
    const buffer = try allocator.alloc(u8, N * N);
    defer allocator.free(buffer);

    std.debug.print("Running loop... Press ENTER to stop.\n", .{});
    _ = try std.Thread.spawn(.{}, waitForEnter, .{});

    while (!should_exit.load(.seq_cst)) {
        std.debug.print("Working...\n", .{});
        std.time.sleep(500 * std.time.ns_per_ms);
    }

    std.debug.print("Exited loop.\n", .{});
}
