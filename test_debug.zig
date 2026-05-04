const std = @import("std");
const lmdbx = @import("src/lmdbx.zig");

pub fn main() !void {
    std.debug.print("Testing lmdbx.zig directly\n", .{});

    // Cleanup
    std.Io.Dir.cwd().deleteFile(std.Options.debug_io, "/tmp/test_debug.db") catch {};
    std.Io.Dir.cwd().deleteFile(std.Options.debug_io, "/tmp/test_debug.db-lock") catch {};

    defer {
        std.Io.Dir.cwd().deleteFile(std.Options.debug_io, "/tmp/test_debug.db") catch {};
        std.Io.Dir.cwd().deleteFile(std.Options.debug_io, "/tmp/test_debug.db-lock") catch {};
    }

    std.debug.print("Opening database...\n", .{});
    var db = lmdbx.Database.open("/tmp/test_debug.db") catch |err| {
        std.debug.print("ERROR opening database: {}\n", .{err});
        return err;
    };
    defer db.close();
    std.debug.print("Database opened!\n", .{});

    try db.put("key1", "value1");
    std.debug.print("Put OK\n", .{});

    const val = try db.get(std.heap.page_allocator, "key1");
    defer if (val) |v| std.heap.page_allocator.free(v);

    if (val) |v| {
        std.debug.print("Got: {s}\n", .{v});
    }

    std.debug.print("SUCCESS!\n", .{});
}
