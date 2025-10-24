const std = @import("std");
const c = @cImport({
    @cInclude("mdbx.h");
});

pub fn main() !void {
    std.debug.print("MDBX_SUCCESS = {}\n", .{c.MDBX_SUCCESS});
    std.debug.print("MDBX_NOTFOUND = {}\n", .{c.MDBX_NOTFOUND});
    std.debug.print("MDBX_CREATE = 0x{x}\n", .{c.MDBX_CREATE});
    std.debug.print("MDBX_COALESCE = 0x{x}\n", .{c.MDBX_COALESCE});
    std.debug.print("MDBX_LIFORECLAIM = 0x{x}\n", .{c.MDBX_LIFORECLAIM});
    std.debug.print("MDBX_NOMETASYNC = 0x{x}\n", .{c.MDBX_NOMETASYNC});
    std.debug.print("MDBX_SAFE_NOSYNC = 0x{x}\n", .{c.MDBX_SAFE_NOSYNC});
    std.debug.print("MDBX_TXN_RDONLY = 0x{x}\n", .{c.MDBX_TXN_RDONLY});
    std.debug.print("MDBX_UPSERT = 0x{x}\n", .{c.MDBX_UPSERT});
    std.debug.print("MDBX_FIRST = {}\n", .{c.MDBX_FIRST});
    std.debug.print("MDBX_NEXT = {}\n", .{c.MDBX_NEXT});
    std.debug.print("MDBX_SET_RANGE = {}\n", .{c.MDBX_SET_RANGE});
}
