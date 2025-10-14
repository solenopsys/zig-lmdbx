const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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
        .file = b.path("version.c"),
        .flags = &flags,
    });

    mdbx.addIncludePath(b.path("libs/libmdbx"));
    mdbx.addIncludePath(b.path("libs/libmdbx/src"));
    mdbx.linkLibC();

    lib.linkLibrary(mdbx);
    lib.addIncludePath(b.path("libs/libmdbx"));
    lib.linkLibC();

    b.installArtifact(lib);

    // Tests for cursor functions
    const cursor_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_cursor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    cursor_tests.linkLibrary(mdbx);
    cursor_tests.addIncludePath(b.path("libs/libmdbx"));
    cursor_tests.linkLibC();

    const run_cursor_tests = b.addRunArtifact(cursor_tests);

    // Tests for C API functions
    const c_api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_c_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    c_api_tests.root_module.addImport("lmdbx", lib.root_module);
    c_api_tests.linkLibrary(lib);
    c_api_tests.linkLibrary(mdbx);
    c_api_tests.addIncludePath(b.path("libs/libmdbx"));
    c_api_tests.linkLibC();

    const run_c_api_tests = b.addRunArtifact(c_api_tests);

    const test_step = b.step("test", "Run all integration tests");
    test_step.dependOn(&run_cursor_tests.step);
    test_step.dependOn(&run_c_api_tests.step);
}
