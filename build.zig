const std = @import("std");

fn getTargetString(target: std.Build.ResolvedTarget) []const u8 {
    const cpu_arch = target.result.cpu.arch;
    const abi = target.result.abi;

    const arch_str = switch (cpu_arch) {
        .x86_64 => "x86_64",
        .aarch64 => "aarch64",
        else => "unknown",
    };

    const libc_str = switch (abi) {
        .musl, .musleabi, .musleabihf => "musl",
        .gnu, .gnueabi, .gnueabihf => "gnu",
        else => "gnu",
    };

    return std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}-{s}",
        .{ arch_str, libc_str },
    ) catch "unknown";
}

fn buildForTarget(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const target_str = getTargetString(target);
    const lib_name = std.fmt.allocPrint(
        std.heap.page_allocator,
        "lmdbx-{s}",
        .{target_str},
    ) catch "lmdbx";

    // Shared library
    const lib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const mdbx_name = std.fmt.allocPrint(
        std.heap.page_allocator,
        "mdbx-{s}",
        .{target_str},
    ) catch "mdbx";

    const mdbx = b.addLibrary(.{
        .name = mdbx_name,
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    const cpu_arch = target.result.cpu.arch;
    const abi = target.result.abi;
    const base_flags = [_][]const u8{
        "-DMDBX_BUILD_SHARED_LIBRARY=0",
        "-DMDBX_WITHOUT_MSVC_CRT=0",
        "-DMDBX_BUILD_TOOLS=0",
        "-DMDBX_BUILD_FLAGS=\"zig\"",
        "-DMDBX_BUILD_COMPILER=\"zig-cc\"",
        "-DMDBX_BUILD_TARGET=\"cross\"",
        "-std=c11",
        "-Wno-error",
        "-Wno-expansion-to-defined",
        "-Wno-date-time",
        "-fno-sanitize=undefined",
        "-fPIC",
        "-O3",
    };
    const x86_gnu_flags = base_flags ++ [_][]const u8{ "-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1", "-D_SYS_CACHECTL_H=1" };
    const x86_flags = base_flags ++ [_][]const u8{"-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1"};
    const glibc_cross_flags = base_flags ++ [_][]const u8{"-D_SYS_CACHECTL_H=1"};
    const flags: []const []const u8 = if (cpu_arch == .x86_64 and (abi == .gnu or abi == .gnueabi or abi == .gnueabihf))
        &x86_gnu_flags
    else if (cpu_arch == .x86_64)
        &x86_flags
    else if (abi == .gnu or abi == .gnueabi or abi == .gnueabihf)
        &glibc_cross_flags
    else
        &base_flags;

    mdbx.addCSourceFile(.{
        .file = b.path("libs/libmdbx/src/alloy.c"),
        .flags = flags,
    });

    mdbx.addCSourceFile(.{
        .file = b.path("version.c"),
        .flags = flags,
    });

    mdbx.addIncludePath(b.path("libs/libmdbx"));
    mdbx.addIncludePath(b.path("libs/libmdbx/src"));
    mdbx.linkLibC();

    lib.linkLibrary(mdbx);
    lib.addIncludePath(b.path("libs/libmdbx"));
    lib.linkLibC();

    b.installArtifact(lib);
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Option to build for all targets or a specific target
    const build_all = b.option(bool, "all", "Build for all supported targets") orelse false;

    if (build_all) {
        // Build for all supported targets
        const targets = [_]std.Target.Query{
            .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
            .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
            .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
            .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
        };

        for (targets) |query| {
            const target = b.resolveTargetQuery(query);
            buildForTarget(b, target, optimize);
        }
    } else {
        // Build for a single target (specified by user or native)
        const target = b.standardTargetOptions(.{});
        buildForTarget(b, target, optimize);

        // Tests only for single-target builds (using the specified target)
        const mdbx_name = std.fmt.allocPrint(
            std.heap.page_allocator,
            "mdbx-{s}",
            .{getTargetString(target)},
        ) catch "mdbx";

        // Recreate mdbx for tests (needed because buildForTarget is separate)
        const mdbx = b.addLibrary(.{
            .name = mdbx_name,
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        const cpu_arch_test = target.result.cpu.arch;
        const abi_test = target.result.abi;
        const base_flags_test = [_][]const u8{
            "-DMDBX_BUILD_SHARED_LIBRARY=0",
            "-DMDBX_WITHOUT_MSVC_CRT=0",
            "-DMDBX_BUILD_TOOLS=0",
            "-DMDBX_BUILD_FLAGS=\"zig\"",
            "-DMDBX_BUILD_COMPILER=\"zig-cc\"",
            "-DMDBX_BUILD_TARGET=\"cross\"",
            "-std=c11",
            "-Wno-error",
            "-Wno-expansion-to-defined",
            "-Wno-date-time",
            "-fno-sanitize=undefined",
            "-fPIC",
            "-O3",
        };
        const x86_gnu_flags_test = base_flags_test ++ [_][]const u8{ "-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1", "-D_SYS_CACHECTL_H=1" };
        const x86_flags_test = base_flags_test ++ [_][]const u8{"-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1"};
        const glibc_cross_flags_test = base_flags_test ++ [_][]const u8{"-D_SYS_CACHECTL_H=1"};
        const flags: []const []const u8 = if (cpu_arch_test == .x86_64 and (abi_test == .gnu or abi_test == .gnueabi or abi_test == .gnueabihf))
            &x86_gnu_flags_test
        else if (cpu_arch_test == .x86_64)
            &x86_flags_test
        else if (abi_test == .gnu or abi_test == .gnueabi or abi_test == .gnueabihf)
            &glibc_cross_flags_test
        else
            &base_flags_test;

        mdbx.addCSourceFile(.{
            .file = b.path("libs/libmdbx/src/alloy.c"),
            .flags = flags,
        });

        mdbx.addCSourceFile(.{
            .file = b.path("version.c"),
            .flags = flags,
        });

        mdbx.addIncludePath(b.path("libs/libmdbx"));
        mdbx.addIncludePath(b.path("libs/libmdbx/src"));
        mdbx.linkLibC();

        // Recreate lib for tests
        const lib_name = std.fmt.allocPrint(
            std.heap.page_allocator,
            "lmdbx-{s}",
            .{getTargetString(target)},
        ) catch "lmdbx";

        const lib = b.addLibrary(.{
            .name = lib_name,
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        lib.linkLibrary(mdbx);
        lib.addIncludePath(b.path("libs/libmdbx"));
        lib.linkLibC();

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
}
