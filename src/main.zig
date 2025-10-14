const std = @import("std");
const lmdbx = @import("lmdbx.zig");

// C API exports with lmdbx_ prefix
export fn lmdbx_open(path: [*:0]const u8, db_ptr: *?*anyopaque) c_int {
    const db = std.heap.c_allocator.create(lmdbx.Database) catch return -1;
    db.* = lmdbx.Database.open(std.mem.span(path)) catch |err| {
        std.heap.c_allocator.destroy(db);
        return switch (err) {
            lmdbx.MdbxError.CreateFailed => -2,
            lmdbx.MdbxError.OpenFailed => -3,
            else => -1,
        };
    };
    db_ptr.* = db;
    return 0;
}

export fn lmdbx_close(db_ptr: ?*anyopaque) void {
    if (db_ptr) |ptr| {
        const db: *lmdbx.Database = @alignCast(@ptrCast(ptr));
        db.close();
        std.heap.c_allocator.destroy(db);
    }
}

export fn lmdbx_put(db_ptr: ?*anyopaque, key: [*]const u8, key_len: usize, value: [*]const u8, value_len: usize) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    const k = key[0..key_len];
    const v = value[0..value_len];
    db.put(k, v) catch return -1;
    return 0;
}

export fn lmdbx_get(db_ptr: ?*anyopaque, key: [*]const u8, key_len: usize, value_ptr: *?[*]u8, value_len: *usize) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    const k = key[0..key_len];
    const result = db.get(std.heap.c_allocator, k) catch return -1;

    if (result) |data| {
        value_ptr.* = data.ptr;
        value_len.* = data.len;
        return 0;
    }
    return -2; // not found
}

export fn lmdbx_free(ptr: ?[*]u8, len: usize) void {
    if (ptr) |p| {
        std.heap.c_allocator.free(p[0..len]);
    }
}

export fn lmdbx_del(db_ptr: ?*anyopaque, key: [*]const u8, key_len: usize) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    const k = key[0..key_len];
    db.delete(k) catch |err| {
        return switch (err) {
            lmdbx.MdbxError.NotFound => -2,
            else => -1,
        };
    };
    return 0;
}

export fn lmdbx_flush(db_ptr: ?*anyopaque) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    db.flush() catch return -1;
    return 0;
}

export fn lmdbx_txn_begin(db_ptr: ?*anyopaque) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    db.beginTransaction() catch return -1;
    return 0;
}

export fn lmdbx_txn_commit(db_ptr: ?*anyopaque) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    db.commitTransaction() catch return -1;
    return 0;
}

export fn lmdbx_txn_abort(db_ptr: ?*anyopaque) void {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return));
    db.abortTransaction();
}

export fn lmdbx_cursor_open(db_ptr: ?*anyopaque, cursor_ptr: *?*anyopaque) c_int {
    const db: *lmdbx.Database = @alignCast(@ptrCast(db_ptr orelse return -1));
    const cursor_obj = std.heap.c_allocator.create(lmdbx.Cursor) catch return -1;
    cursor_obj.* = db.openCursor() catch {
        std.heap.c_allocator.destroy(cursor_obj);
        return -1;
    };
    cursor_ptr.* = cursor_obj;
    return 0;
}

export fn lmdbx_cursor_close(cursor_ptr: ?*anyopaque) void {
    if (cursor_ptr) |ptr| {
        const cursor: *lmdbx.Cursor = @alignCast(@ptrCast(ptr));
        lmdbx.Database.closeCursor(cursor.*);
        std.heap.c_allocator.destroy(cursor);
    }
}

export fn lmdbx_cursor_get(
    cursor_ptr: ?*anyopaque,
    key_ptr: *?[*]u8,
    key_len: *usize,
    value_ptr: *?[*]u8,
    value_len: *usize,
    op: c_int,
) c_int {
    const cursor: *lmdbx.Cursor = @alignCast(@ptrCast(cursor_ptr orelse return -1));
    var k: @import("lmdbx.zig").c.MDBX_val = undefined;
    var v: @import("lmdbx.zig").c.MDBX_val = undefined;

    const rc = @import("lmdbx.zig").c.mdbx_cursor_get(cursor.cursor, &k, &v, @intCast(op));
    if (rc != @import("lmdbx.zig").c.MDBX_SUCCESS) return rc;

    key_ptr.* = @ptrCast(k.iov_base);
    key_len.* = k.iov_len;
    value_ptr.* = @ptrCast(v.iov_base);
    value_len.* = v.iov_len;
    return 0;
}
