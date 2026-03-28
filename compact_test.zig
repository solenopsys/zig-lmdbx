const std = @import("std");
const lmdbx = @import("src/lmdbx.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const path = "/tmp/compact-test/data";
    const path_z: [:0]const u8 = path;

    const before = try std.fs.cwd().statFile(path ++ "/mdbx.dat");
    std.debug.print("Before: {d} MB\n", .{before.size / 1024 / 1024});

    std.debug.print("Opening: {s}\n", .{path});
    var db = try lmdbx.Database.open(path_z);
    defer db.close();

    std.debug.print("Running compact...\n", .{});
    try db.compact(allocator, path);

    const after = try std.fs.cwd().statFile(path ++ "/mdbx.dat");
    std.debug.print("After:  {d} MB\n", .{after.size / 1024 / 1024});
}
