const std = @import("std");
const lmdbx = @import("lmdbx.zig");

test "cursor seekPrefix and next" {
    const allocator = std.testing.allocator;

    std.debug.print("\n[TEST] cursor seekPrefix and next\n", .{});

    // Cleanup
    std.fs.cwd().deleteFile("/tmp/test_cursor.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_cursor.db-lock") catch {};
    defer {
        std.fs.cwd().deleteFile("/tmp/test_cursor.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_cursor.db-lock") catch {};
    }

    var db = try lmdbx.Database.open("/tmp/test_cursor.db");
    defer db.close();

    // Put some test data with prefixes
    try db.put("apple_1", "value1");
    try db.put("apple_2", "value2");
    try db.put("apple_3", "value3");
    try db.put("banana_1", "value4");
    try db.put("banana_2", "value5");
    try db.put("cherry", "value6");

    // Test seekPrefix for "apple_"
    const cursor = try db.openCursor();
    defer lmdbx.Database.closeCursor(cursor);

    const entry1 = try cursor.seekPrefix(allocator, "apple_");
    try std.testing.expect(entry1 != null);
    defer if (entry1) |e| {
        allocator.free(e.key);
        allocator.free(e.value);
    };

    try std.testing.expectEqualStrings("apple_1", entry1.?.key);
    try std.testing.expectEqualStrings("value1", entry1.?.value);

    // Test next
    const entry2 = try cursor.next(allocator);
    try std.testing.expect(entry2 != null);
    defer if (entry2) |e| {
        allocator.free(e.key);
        allocator.free(e.value);
    };

    try std.testing.expectEqualStrings("apple_2", entry2.?.key);
    try std.testing.expectEqualStrings("value2", entry2.?.value);

    // Test next again
    const entry3 = try cursor.next(allocator);
    try std.testing.expect(entry3 != null);
    defer if (entry3) |e| {
        allocator.free(e.key);
        allocator.free(e.value);
    };

    try std.testing.expectEqualStrings("apple_3", entry3.?.key);
    try std.testing.expectEqualStrings("value3", entry3.?.value);

    std.debug.print("[TEST] ✅ PASSED\n", .{});
}

test "cursor seekPrefix not found" {
    const allocator = std.testing.allocator;

    std.debug.print("\n[TEST] cursor seekPrefix not found\n", .{});

    std.fs.cwd().deleteFile("/tmp/test_cursor2.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_cursor2.db-lock") catch {};
    defer {
        std.fs.cwd().deleteFile("/tmp/test_cursor2.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_cursor2.db-lock") catch {};
    }

    var db = try lmdbx.Database.open("/tmp/test_cursor2.db");
    defer db.close();

    try db.put("apple", "value1");
    try db.put("banana", "value2");

    const cursor = try db.openCursor();
    defer lmdbx.Database.closeCursor(cursor);

    // Seek for non-existent prefix
    const entry = try cursor.seekPrefix(allocator, "zebra");
    try std.testing.expect(entry == null);

    std.debug.print("[TEST] ✅ PASSED\n", .{});
}

test "cursor next until end" {
    const allocator = std.testing.allocator;

    std.debug.print("\n[TEST] cursor next until end\n", .{});

    std.fs.cwd().deleteFile("/tmp/test_cursor3.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_cursor3.db-lock") catch {};
    defer {
        std.fs.cwd().deleteFile("/tmp/test_cursor3.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_cursor3.db-lock") catch {};
    }

    var db = try lmdbx.Database.open("/tmp/test_cursor3.db");
    defer db.close();

    try db.put("key1", "value1");
    try db.put("key2", "value2");

    const cursor = try db.openCursor();
    defer lmdbx.Database.closeCursor(cursor);

    // Seek to first
    const entry1 = try cursor.seekPrefix(allocator, "key");
    try std.testing.expect(entry1 != null);
    defer if (entry1) |e| {
        allocator.free(e.key);
        allocator.free(e.value);
    };

    // Next
    const entry2 = try cursor.next(allocator);
    try std.testing.expect(entry2 != null);
    defer if (entry2) |e| {
        allocator.free(e.key);
        allocator.free(e.value);
    };

    // Next should return null (end of data)
    const entry3 = try cursor.next(allocator);
    try std.testing.expect(entry3 == null);

    std.debug.print("[TEST] ✅ PASSED\n", .{});
}
