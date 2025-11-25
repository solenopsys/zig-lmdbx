const std = @import("std");
const build_utils = @import("build_utils.zig");

fn buildForTarget(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    artifacts_dir: []const u8,
    hashes: *std.StringHashMap([]const u8),
    json_step: *build_utils.WriteJsonStep,
) void {
    const target_str = build_utils.getTargetString(target);
    const lib_name = build_utils.getLibName(std.heap.page_allocator, "lmdbx", target_str);

    // Static library
    const lib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const mdbx_name = build_utils.getLibName(std.heap.page_allocator, "mdbx", target_str);

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
        "-O2",
        "-ffunction-sections",
        "-fdata-sections",
        "-fvisibility=hidden",
    };
    const x86_gnu_flags = base_flags ++ [_][]const u8{ "-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1", "-D_SYS_CACHECTL_H=1", "-march=x86-64" };
    const x86_flags = base_flags ++ [_][]const u8{ "-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1", "-march=x86-64" };
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

    mdbx.addCSourceFile(.{
        .file = b.path("cpu_stub.c"),
        .flags = &[_][]const u8{"-fPIC"},
    });

    mdbx.addIncludePath(b.path("libs/libmdbx"));
    mdbx.addIncludePath(b.path("libs/libmdbx/src"));
    mdbx.linkLibC();

    lib.linkLibrary(mdbx);
    lib.linkLibC();

    const install = b.addInstallArtifact(lib, .{});

    const hash_step = build_utils.HashAndMoveStep.create(
        b,
        lib_name,
        target_str,
        artifacts_dir,
        hashes,
    );
    hash_step.step.dependOn(&install.step);

    json_step.step.dependOn(&hash_step.step);
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const artifacts_dir = "../../artifacts/libs";
    const json_path = "current.json";

    // Option to build for all targets or a specific target
    const build_all = b.option(bool, "all", "Build for all supported targets") orelse false;

    if (build_all) {
        const hashes = build_utils.createHashMap(b);
        const json_step = build_utils.WriteJsonStep.create(b, hashes, json_path);

        for (build_utils.supported_targets) |query| {
            const target = b.resolveTargetQuery(query);
            buildForTarget(b, target, optimize, artifacts_dir, hashes, json_step);
        }

        b.default_step.dependOn(&json_step.step);
    } else {
        // Build for a single target (specified by user or native)
        const target = b.standardTargetOptions(.{});
        const target_str = build_utils.getTargetString(target);

        const mdbx_name = build_utils.getLibName(std.heap.page_allocator, "mdbx", target_str);

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
            "-O2",
            "-ffunction-sections",
            "-fdata-sections",
            "-fvisibility=hidden",
        };
        const x86_gnu_flags_test = base_flags_test ++ [_][]const u8{ "-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1", "-D_SYS_CACHECTL_H=1", "-march=x86-64" };
        const x86_flags_test = base_flags_test ++ [_][]const u8{ "-DMDBX_GCC_FASTMATH_i686_SIMD_WORKAROUND=1", "-march=x86-64" };
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

        mdbx.addCSourceFile(.{
            .file = b.path("cpu_stub.c"),
            .flags = &[_][]const u8{"-fPIC"},
        });

        mdbx.addIncludePath(b.path("libs/libmdbx"));
        mdbx.addIncludePath(b.path("libs/libmdbx/src"));
        mdbx.linkLibC();

        // Recreate lib for tests
        const lib_name = build_utils.getLibName(std.heap.page_allocator, "lmdbx", target_str);

        const lib = b.addLibrary(.{
            .name = lib_name,
            .linkage = .static,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        lib.linkLibrary(mdbx);
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
        c_api_tests.linkLibC();

        const run_c_api_tests = b.addRunArtifact(c_api_tests);

        const test_step = b.step("test", "Run all integration tests");
        test_step.dependOn(&run_cursor_tests.step);
        test_step.dependOn(&run_c_api_tests.step);
    }
}
