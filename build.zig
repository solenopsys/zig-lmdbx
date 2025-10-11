const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Copy version.c to libmdbx source directory
    const copy_version = b.addSystemCommand(&[_][]const u8{
        "cp",
        "version.c",
        "libs/libmdbx/src/version.c",
    });

    // Shared library
    const lib = b.addLibrary(.{
        .name = "lmdbx",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const mdbx = b.addLibrary(.{
        .name = "mdbx",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    const flags = [_][]const u8{
        "-DMDBX_BUILD_SHARED_LIBRARY=0",
        "-DMDBX_WITHOUT_MSVC_CRT=0",
        "-DMDBX_BUILD_TOOLS=0",
        "-DMDBX_BUILD_FLAGS=\"zig\"",
        "-DMDBX_BUILD_COMPILER=\"zig-cc\"",
        "-DMDBX_BUILD_TARGET=\"native\"",
        "-std=c11",
        "-Wno-error",
        "-Wno-expansion-to-defined",
        "-Wno-date-time",
        "-fno-sanitize=undefined",
        "-O3",
        "-march=native",
    };

    mdbx.addCSourceFile(.{
        .file = b.path("libs/libmdbx/src/alloy.c"),
        .flags = &flags,
    });

    mdbx.addCSourceFile(.{
        .file = b.path("libs/libmdbx/src/version.c"),
        .flags = &flags,
    });

    mdbx.step.dependOn(&copy_version.step);

    mdbx.addIncludePath(b.path("libs/libmdbx"));
    mdbx.addIncludePath(b.path("libs/libmdbx/src"));
    mdbx.linkLibC();

    lib.linkLibrary(mdbx);
    lib.addIncludePath(b.path("libs/libmdbx"));
    lib.linkLibC();

    b.installArtifact(lib);
}
