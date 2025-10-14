const std = @import("std");

// C API from liblmdbx.so - точно такие же сигнатуры как в main.zig
extern fn lmdbx_open(path: [*:0]const u8, db_ptr: *?*anyopaque) c_int;
extern fn lmdbx_close(db_ptr: ?*anyopaque) void;
extern fn lmdbx_put(db_ptr: ?*anyopaque, key: [*]const u8, key_len: usize, value: [*]const u8, value_len: usize) c_int;
extern fn lmdbx_get(db_ptr: ?*anyopaque, key: [*]const u8, key_len: usize, value_ptr: *?[*]u8, value_len: *usize) c_int;
extern fn lmdbx_del(db_ptr: ?*anyopaque, key: [*]const u8, key_len: usize) c_int;
extern fn lmdbx_cursor_open(db_ptr: ?*anyopaque, cursor_ptr: *?*anyopaque) c_int;
extern fn lmdbx_cursor_close(cursor_ptr: ?*anyopaque) void;
extern fn lmdbx_cursor_get(cursor_ptr: ?*anyopaque, key_ptr: *?[*]u8, key_len: *usize, value_ptr: *?[*]u8, value_len: *usize, op: c_int) c_int;

test "C API: open, put, get, close" {
    std.debug.print("\n[TEST] C API basic operations\n", .{});

    std.fs.cwd().deleteFile("/tmp/test_c_api.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_c_api.db-lock") catch {};
    defer {
        std.fs.cwd().deleteFile("/tmp/test_c_api.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_c_api.db-lock") catch {};
    }

    // Open
    var db_ptr: ?*anyopaque = null;
    const open_result = lmdbx_open("/tmp/test_c_api.db", &db_ptr);
    try std.testing.expectEqual(@as(c_int, 0), open_result);
    defer lmdbx_close(db_ptr);

    // Put
    const key = "test_key";
    const value = "test_value";
    const put_result = lmdbx_put(db_ptr, key.ptr, key.len, value.ptr, value.len);
    try std.testing.expectEqual(@as(c_int, 0), put_result);

    // Get
    var value_ptr: ?[*]u8 = null;
    var value_len: usize = 0;
    const get_result = lmdbx_get(db_ptr, key.ptr, key.len, &value_ptr, &value_len);
    try std.testing.expectEqual(@as(c_int, 0), get_result);

    const retrieved = (value_ptr orelse return error.NullValue)[0..value_len];
    try std.testing.expectEqualStrings(value, retrieved);

    std.debug.print("[TEST] ✅ PASSED\n", .{});
}

test "C API: cursor operations" {
    std.debug.print("\n[TEST] C API cursor operations\n", .{});

    std.fs.cwd().deleteFile("/tmp/test_c_cursor.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_c_cursor.db-lock") catch {};
    defer {
        std.fs.cwd().deleteFile("/tmp/test_c_cursor.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_c_cursor.db-lock") catch {};
    }

    // Open database
    var db_ptr: ?*anyopaque = null;
    var result = lmdbx_open("/tmp/test_c_cursor.db", &db_ptr);
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer lmdbx_close(db_ptr);

    // Put test data
    result = lmdbx_put(db_ptr, "apple_1".ptr, 7, "value1".ptr, 6);
    try std.testing.expectEqual(@as(c_int, 0), result);

    result = lmdbx_put(db_ptr, "apple_2".ptr, 7, "value2".ptr, 6);
    try std.testing.expectEqual(@as(c_int, 0), result);

    result = lmdbx_put(db_ptr, "banana".ptr, 6, "value3".ptr, 6);
    try std.testing.expectEqual(@as(c_int, 0), result);

    // Open cursor
    var cursor_ptr: ?*anyopaque = null;
    result = lmdbx_cursor_open(db_ptr, &cursor_ptr);
    std.debug.print("cursor_open result: {d}\n", .{result});
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer lmdbx_cursor_close(cursor_ptr);

    // Get first entry with cursor (MDBX_FIRST = 0)
    var key_ptr: ?[*]u8 = null;
    var key_len: usize = 0;
    var value_ptr: ?[*]u8 = null;
    var value_len: usize = 0;

    result = lmdbx_cursor_get(cursor_ptr, &key_ptr, &key_len, &value_ptr, &value_len, 0);
    std.debug.print("cursor_get result: {d}\n", .{result});
    try std.testing.expectEqual(@as(c_int, 0), result);

    const key = (key_ptr orelse return error.NullKey)[0..key_len];
    const value = (value_ptr orelse return error.NullValue)[0..value_len];
    std.debug.print("First key: {s}, value: {s}\n", .{ key, value });

    std.debug.print("[TEST] ✅ PASSED\n", .{});
}

test "C API: delete operation" {
    std.debug.print("\n[TEST] C API delete operation\n", .{});

    std.fs.cwd().deleteFile("/tmp/test_c_del.db") catch {};
    std.fs.cwd().deleteFile("/tmp/test_c_del.db-lock") catch {};
    defer {
        std.fs.cwd().deleteFile("/tmp/test_c_del.db") catch {};
        std.fs.cwd().deleteFile("/tmp/test_c_del.db-lock") catch {};
    }

    // Open
    var db_ptr: ?*anyopaque = null;
    var result = lmdbx_open("/tmp/test_c_del.db", &db_ptr);
    try std.testing.expectEqual(@as(c_int, 0), result);
    defer lmdbx_close(db_ptr);

    // Put
    const key = "key_to_delete";
    result = lmdbx_put(db_ptr, key.ptr, key.len, "value".ptr, 5);
    try std.testing.expectEqual(@as(c_int, 0), result);

    // Delete
    result = lmdbx_del(db_ptr, key.ptr, key.len);
    try std.testing.expectEqual(@as(c_int, 0), result);

    // Try to get - should fail
    var value_ptr: ?[*]u8 = null;
    var value_len: usize = 0;
    result = lmdbx_get(db_ptr, key.ptr, key.len, &value_ptr, &value_len);
    try std.testing.expect(result != 0); // Should fail

    std.debug.print("[TEST] ✅ PASSED\n", .{});
}
