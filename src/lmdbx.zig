/// High-level Zig API for LMDBX - pure Zig types, no C headers
const std = @import("std");
const ffi = @import("lmdbx_pure.zig");

pub const MdbxError = error{
    CreateFailed,
    OpenFailed,
    TxnBeginFailed,
    TxnCommitFailed,
    DbiOpenFailed,
    PutFailed,
    MapFull,
    GetFailed,
    NotFound,
    DeleteFailed,
    CursorOpenFailed,
};

const mib: isize = 1024 * 1024;

fn parseMiBEnv(name: []const u8, fallback_mib: isize) isize {
    const raw = std.posix.getenv(name) orelse return fallback_mib;
    const parsed = std.fmt.parseInt(isize, raw, 10) catch return fallback_mib;
    if (parsed <= 0) return fallback_mib;
    return parsed;
}

fn geometryFromEnv() struct {
    lower: isize,
    now: isize,
    upper: isize,
    growth: isize,
    shrink: isize,
} {
    const lower_mib = parseMiBEnv("LMDBX_MAP_LOWER_MIB", 1);
    const now_mib = parseMiBEnv("LMDBX_MAP_NOW_MIB", 1);
    const upper_mib = parseMiBEnv("LMDBX_MAP_UPPER_MIB", 1024 * 1024);
    const growth_mib = parseMiBEnv("LMDBX_MAP_GROWTH_MIB", 16);
    const shrink_mib = parseMiBEnv("LMDBX_MAP_SHRINK_MIB", 16);

    const lower_bytes = lower_mib * mib;
    const now_bytes = @max(now_mib, lower_mib) * mib;
    const upper_bytes = @max(upper_mib, now_mib) * mib;
    const growth_bytes = @max(growth_mib, 1) * mib;
    const shrink_bytes = @max(shrink_mib, 1) * mib;

    return .{
        .lower = lower_bytes,
        .now = now_bytes,
        .upper = upper_bytes,
        .growth = growth_bytes,
        .shrink = shrink_bytes,
    };
}

pub const CursorEntry = struct {
    key: []const u8,
    value: []const u8,
};

pub const Cursor = struct {
    cursor: *ffi.MDBX_cursor,
    txn: *ffi.MDBX_txn,
    owns_txn: bool,

    /// Seek to first key with given prefix
    /// Returns the first entry or null if not found
    pub fn seekPrefix(self: Cursor, allocator: std.mem.Allocator, prefix: []const u8) !?CursorEntry {
        var k = ffi.MDBX_val{
            .iov_base = @constCast(prefix.ptr),
            .iov_len = prefix.len,
        };
        var v: ffi.MDBX_val = undefined;

        const rc = ffi.mdbx_cursor_get(self.cursor, &k, &v, ffi.MDBX_SET_RANGE);
        if (rc == ffi.MDBX_NOTFOUND) return null;
        if (rc != ffi.MDBX_SUCCESS) return MdbxError.GetFailed;

        const key_data = @as([*]u8, @ptrCast(k.iov_base))[0..k.iov_len];
        const value_data = @as([*]u8, @ptrCast(v.iov_base))[0..v.iov_len];

        // Check if key starts with prefix
        if (key_data.len < prefix.len or !std.mem.eql(u8, key_data[0..prefix.len], prefix)) {
            return null;
        }

        return CursorEntry{
            .key = try allocator.dupe(u8, key_data),
            .value = try allocator.dupe(u8, value_data),
        };
    }

    /// Move to next entry
    /// Returns the next entry or null if no more entries
    pub fn next(self: Cursor, allocator: std.mem.Allocator) !?CursorEntry {
        var k: ffi.MDBX_val = undefined;
        var v: ffi.MDBX_val = undefined;

        const rc = ffi.mdbx_cursor_get(self.cursor, &k, &v, ffi.MDBX_NEXT);
        if (rc == ffi.MDBX_NOTFOUND) return null;
        if (rc != ffi.MDBX_SUCCESS) return MdbxError.GetFailed;

        const key_data = @as([*]u8, @ptrCast(k.iov_base))[0..k.iov_len];
        const value_data = @as([*]u8, @ptrCast(v.iov_base))[0..v.iov_len];

        return CursorEntry{
            .key = try allocator.dupe(u8, key_data),
            .value = try allocator.dupe(u8, value_data),
        };
    }
};

pub const Database = struct {
    env: *ffi.MDBX_env,
    dbi: ffi.MDBX_dbi,
    current_txn: ?*ffi.MDBX_txn,

    pub fn open(path: [:0]const u8) !Database {
        var env: ?*ffi.MDBX_env = null;

        var rc = ffi.mdbx_env_create(&env);
        if (rc != ffi.MDBX_SUCCESS) return MdbxError.CreateFailed;

        // Set max readers and DBs
        _ = ffi.mdbx_env_set_maxreaders(env, 126);
        _ = ffi.mdbx_env_set_maxdbs(env, 128);

        // Configure map geometry so large values don't fail with MDBX_MAP_FULL.
        const g = geometryFromEnv();
        rc = ffi.mdbx_env_set_geometry(
            env,
            g.lower,
            g.now,
            g.upper,
            g.growth,
            g.shrink,
            -1,
        );
        if (rc != ffi.MDBX_SUCCESS) {
            _ = ffi.mdbx_env_close(env);
            return MdbxError.OpenFailed;
        }

        rc = ffi.mdbx_env_open(env, path.ptr, ffi.MDBX_CREATE, 0o664);
        if (rc != ffi.MDBX_SUCCESS) {
            _ = ffi.mdbx_env_close(env);
            return MdbxError.OpenFailed;
        }

        var txn: ?*ffi.MDBX_txn = null;
        rc = ffi.mdbx_txn_begin(env, null, 0, &txn);
        if (rc != ffi.MDBX_SUCCESS) {
            _ = ffi.mdbx_env_close(env);
            return MdbxError.TxnBeginFailed;
        }

        var dbi: ffi.MDBX_dbi = undefined;
        rc = ffi.mdbx_dbi_open(txn, null, ffi.MDBX_CREATE, &dbi);
        if (rc != ffi.MDBX_SUCCESS) {
            _ = ffi.mdbx_txn_abort(txn);
            _ = ffi.mdbx_env_close(env);
            return MdbxError.DbiOpenFailed;
        }

        rc = ffi.mdbx_txn_commit(txn);
        if (rc != ffi.MDBX_SUCCESS) {
            _ = ffi.mdbx_env_close(env);
            return MdbxError.TxnCommitFailed;
        }

        return Database{
            .env = env.?,
            .dbi = dbi,
            .current_txn = null,
        };
    }

    pub fn close(self: *Database) void {
        _ = ffi.mdbx_env_close(self.env);
    }

    fn growMap(self: *Database) bool {
        // Получаем текущий размер
        var info: ffi.MDBX_envinfo = undefined;
        const info_rc = ffi.mdbx_env_info_ex(self.env, null, &info, @sizeOf(ffi.MDBX_envinfo));
        if (info_rc != ffi.MDBX_SUCCESS) {
            std.log.err("mdbx_env_info_ex failed: rc={d}", .{info_rc});
            return false;
        }

        const current: usize = @intCast(info.geo.current);
        const upper: usize = @intCast(info.geo.upper);
        // Удваиваем, но не больше upper
        const new_size: isize = @intCast(@min(current * 2, upper));

        std.log.warn("MDBX growing map: {d} MiB -> {d} MiB (upper={d} MiB)", .{
            current / (1024 * 1024),
            @as(usize, @intCast(new_size)) / (1024 * 1024),
            upper / (1024 * 1024),
        });

        const rc = ffi.mdbx_env_set_geometry(self.env, -1, new_size, -1, -1, -1, -1);
        if (rc != ffi.MDBX_SUCCESS) {
            std.log.err("mdbx_env_set_geometry (grow) failed: rc={d} ({s})", .{ rc, ffi.mdbx_strerror(rc) });
            return false;
        }
        return true;
    }

    pub fn put(self: *Database, key: []const u8, value: []const u8) !void {
        const max_retries: u8 = 3;
        var attempt: u8 = 0;

        while (attempt < max_retries) : (attempt += 1) {
            const use_current = self.current_txn != null;
            var txn: ?*ffi.MDBX_txn = self.current_txn;

            if (!use_current) {
                const rc = ffi.mdbx_txn_begin(self.env, null, 0, &txn);
                if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnBeginFailed;
            }

            var k = ffi.MDBX_val{
                .iov_base = @constCast(key.ptr),
                .iov_len = key.len,
            };
            var v = ffi.MDBX_val{
                .iov_base = @constCast(value.ptr),
                .iov_len = value.len,
            };

            var rc = ffi.mdbx_put(txn, self.dbi, &k, &v, ffi.MDBX_UPSERT);
            if (rc == ffi.MDBX_MAP_FULL) {
                if (!use_current) _ = ffi.mdbx_txn_abort(txn);
                if (use_current) return MdbxError.MapFull; // caller manages txn, can't retry
                std.log.warn("MDBX_MAP_FULL on put, growing map (attempt {d}/{d})", .{ attempt + 1, max_retries });
                if (!self.growMap()) return MdbxError.MapFull;
                continue;
            }
            if (rc != ffi.MDBX_SUCCESS) {
                if (!use_current) _ = ffi.mdbx_txn_abort(txn);
                std.log.err("mdbx_put failed: rc={d} ({s})", .{ rc, ffi.mdbx_strerror(rc) });
                return MdbxError.PutFailed;
            }

            if (!use_current) {
                rc = ffi.mdbx_txn_commit(txn);
                if (rc == ffi.MDBX_MAP_FULL) {
                    std.log.warn("MDBX_MAP_FULL on commit, growing map (attempt {d}/{d})", .{ attempt + 1, max_retries });
                    if (!self.growMap()) return MdbxError.MapFull;
                    continue;
                }
                if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnCommitFailed;
            }

            return; // success
        }

        return MdbxError.MapFull;
    }

    pub fn get(self: *Database, allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
        const use_current = self.current_txn != null;
        var txn: ?*ffi.MDBX_txn = self.current_txn;

        if (!use_current) {
            const rc = ffi.mdbx_txn_begin(self.env, null, ffi.MDBX_TXN_RDONLY, &txn);
            if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnBeginFailed;
        }
        defer {
            if (!use_current) _ = ffi.mdbx_txn_abort(txn);
        }

        var k = ffi.MDBX_val{
            .iov_base = @constCast(key.ptr),
            .iov_len = key.len,
        };
        var v: ffi.MDBX_val = undefined;

        const rc = ffi.mdbx_get(txn, self.dbi, &k, &v);
        if (rc == ffi.MDBX_NOTFOUND) return null;
        if (rc != ffi.MDBX_SUCCESS) return MdbxError.GetFailed;

        const data = @as([*]u8, @ptrCast(v.iov_base))[0..v.iov_len];
        const result = try allocator.dupe(u8, data);
        return result;
    }

    pub fn hasKey(self: *Database, key: []const u8) !bool {
        const use_current = self.current_txn != null;
        var txn: ?*ffi.MDBX_txn = self.current_txn;

        if (!use_current) {
            const rc = ffi.mdbx_txn_begin(self.env, null, ffi.MDBX_TXN_RDONLY, &txn);
            if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnBeginFailed;
        }
        defer {
            if (!use_current) _ = ffi.mdbx_txn_abort(txn);
        }

        var k = ffi.MDBX_val{
            .iov_base = @constCast(key.ptr),
            .iov_len = key.len,
        };
        var v: ffi.MDBX_val = undefined;

        const rc = ffi.mdbx_get(txn, self.dbi, &k, &v);
        switch (rc) {
            ffi.MDBX_SUCCESS => return true,
            ffi.MDBX_NOTFOUND => return false,
            else => return MdbxError.GetFailed,
        }
    }

    pub fn delete(self: *Database, key: []const u8) !void {
        const use_current = self.current_txn != null;
        var txn: ?*ffi.MDBX_txn = self.current_txn;

        if (!use_current) {
            const rc = ffi.mdbx_txn_begin(self.env, null, 0, &txn);
            if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnBeginFailed;
        }

        var k = ffi.MDBX_val{
            .iov_base = @constCast(key.ptr),
            .iov_len = key.len,
        };

        var rc = ffi.mdbx_del(txn, self.dbi, &k, null);
        if (rc == ffi.MDBX_NOTFOUND) {
            if (!use_current) _ = ffi.mdbx_txn_abort(txn);
            return MdbxError.NotFound;
        }
        if (rc != ffi.MDBX_SUCCESS) {
            if (!use_current) _ = ffi.mdbx_txn_abort(txn);
            return MdbxError.DeleteFailed;
        }

        if (!use_current) {
            rc = ffi.mdbx_txn_commit(txn);
            if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnCommitFailed;
        }
    }

    pub fn flush(self: *Database) !void {
        const rc = ffi.mdbx_env_sync(self.env);
        if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnCommitFailed;
    }

    /// Compact database: copy with MDBX_CP_COMPACT to tmp, then replace original.
    /// path must be the same directory that was passed to open().
    pub fn compact(self: *Database, allocator: std.mem.Allocator, path: []const u8) !void {
        const tmp_str = try std.fmt.allocPrint(allocator, "{s}-compact", .{path});
        defer allocator.free(tmp_str);
        const tmp_path = try allocator.dupeZ(u8, tmp_str);
        defer allocator.free(tmp_path);

        // Remove leftover tmp dir if exists — mdbx_env_copy creates the dir itself
        std.fs.cwd().deleteTree(tmp_path) catch {};

        const rc = ffi.mdbx_env_copy(self.env, tmp_path.ptr, ffi.MDBX_CP_COMPACT);
        if (rc != ffi.MDBX_SUCCESS) {
            std.log.err("mdbx_env_copy compact failed: rc={d} ({s})", .{ rc, ffi.mdbx_strerror(rc) });
            std.fs.cwd().deleteTree(tmp_path) catch {};
            return MdbxError.OpenFailed;
        }

        // Close current env
        _ = ffi.mdbx_env_close(self.env);

        // mdbx_env_copy creates a single file at tmp_path.
        // Atomic swap: rename original to .bak first, then put compacted in place.
        // Only delete .bak after successful reopen — original is never lost until confirmed.
        const orig_dat = try std.fmt.allocPrint(allocator, "{s}/mdbx.dat", .{path});
        defer allocator.free(orig_dat);
        const bak_dat = try std.fmt.allocPrint(allocator, "{s}/mdbx.dat.bak", .{path});
        defer allocator.free(bak_dat);
        const orig_lck = try std.fmt.allocPrint(allocator, "{s}/mdbx.lck", .{path});
        defer allocator.free(orig_lck);

        // Move original aside
        std.fs.cwd().rename(orig_dat, bak_dat) catch {};
        std.fs.cwd().deleteFile(orig_lck) catch {};

        // Put compacted file in place
        std.fs.cwd().rename(tmp_str, orig_dat) catch |e| {
            std.log.err("compact rename dat failed: {}", .{e});
            // Restore original
            std.fs.cwd().rename(bak_dat, orig_dat) catch {};
            return MdbxError.OpenFailed;
        };

        // Reopen — if this fails, bak is still there for manual recovery
        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);
        const reopened = Database.open(path_z) catch |e| {
            std.log.err("compact reopen failed: {}", .{e});
            return e;
        };
        self.env = reopened.env;
        self.dbi = reopened.dbi;
        self.current_txn = null;

        // Reopen succeeded — safe to delete backup
        std.fs.cwd().deleteFile(bak_dat) catch {};
    }

    /// Returns utilization ratio (0.0 – 1.0): used pages / file size.
    /// Returns null if info cannot be obtained.
    pub fn utilization(self: *Database) ?f64 {
        var info: ffi.MDBX_envinfo = undefined;
        const rc = ffi.mdbx_env_info_ex(self.env, null, &info, @sizeOf(ffi.MDBX_envinfo));
        if (rc != ffi.MDBX_SUCCESS) return null;
        const page_size: u64 = if (info.mi_dxb_pagesize > 0) info.mi_dxb_pagesize else 4096;
        const used_bytes: u64 = info.mi_last_pgno * page_size;
        const file_size: u64 = info.geo.current;
        if (file_size == 0) return null;
        return @as(f64, @floatFromInt(used_bytes)) / @as(f64, @floatFromInt(file_size));
    }

    pub fn beginTransaction(self: *Database) !void {
        if (self.current_txn != null) return; // Already in transaction

        var txn: ?*ffi.MDBX_txn = null;
        const rc = ffi.mdbx_txn_begin(self.env, null, 0, &txn);
        if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnBeginFailed;
        self.current_txn = txn;
    }

    pub fn commitTransaction(self: *Database) !void {
        if (self.current_txn) |txn| {
            const rc = ffi.mdbx_txn_commit(txn);
            self.current_txn = null;
            if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnCommitFailed;
        }
    }

    pub fn abortTransaction(self: *Database) void {
        if (self.current_txn) |txn| {
            _ = ffi.mdbx_txn_abort(txn);
            self.current_txn = null;
        }
    }

    pub fn openCursor(self: *Database) !Cursor {
        const use_current = self.current_txn != null;
        var txn: ?*ffi.MDBX_txn = self.current_txn;

        if (!use_current) {
            const rc = ffi.mdbx_txn_begin(self.env, null, ffi.MDBX_TXN_RDONLY, &txn);
            if (rc != ffi.MDBX_SUCCESS) return MdbxError.TxnBeginFailed;
        }

        var cursor: ?*ffi.MDBX_cursor = null;
        const rc = ffi.mdbx_cursor_open(txn, self.dbi, &cursor);
        if (rc != ffi.MDBX_SUCCESS) {
            if (!use_current) _ = ffi.mdbx_txn_abort(txn);
            return MdbxError.CursorOpenFailed;
        }

        return Cursor{
            .cursor = cursor.?,
            .txn = txn.?,
            .owns_txn = !use_current,
        };
    }

    pub fn closeCursor(cursor: Cursor) void {
        ffi.mdbx_cursor_close(cursor.cursor);
        if (cursor.owns_txn) {
            _ = ffi.mdbx_txn_abort(cursor.txn);
        }
    }
};
