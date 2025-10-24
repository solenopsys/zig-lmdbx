const std = @import("std");
const lmdbx = @import("src/lmdbx.zig");

pub fn main() !void {
    std.debug.print("Test simple lmdbx\n", .{});

    // Cleanup
    std.fs.cwd().deleteFile("/tmp/test_simple.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_simple.db-lock") catch {};

    defer {
        std.fs.cwd().deleteFile("/tmp/test_simple.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_simple.db-lock") catch {};
    }

    var db = try lmdbx.Database.open("/tmp/test_simple.db");
    defer db.close();

    try db.put("key1", "value1");
    std.debug.print("Put OK\n", .{});

    const val = try db.get(std.heap.page_allocator, "key1");
    defer if (val) |v| std.heap.page_allocator.free(v);

    if (val) |v| {
        std.debug.print("Got: {s}\n", .{v});
    }

    std.debug.print("SUCCESS!\n", .{});
}
