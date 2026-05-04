const std = @import("std");
const build_utils = @import("build_utils.zig"); // simlink ../comptime/build_utils.zig

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

    const lib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .dynamic,
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

    mdbx.root_module.addCSourceFile(.{
        .file = b.path("vendor/libmdbx/src/alloy.c"),
        .flags = flags,
    });

    mdbx.root_module.addCSourceFile(.{
        .file = b.path("version.c"),
        .flags = flags,
    });

    mdbx.root_module.addCSourceFile(.{
        .file = b.path("cpu_stub.c"),
        .flags = &[_][]const u8{"-fPIC"},
    });

    mdbx.root_module.addIncludePath(b.path("vendor/libmdbx"));
    mdbx.root_module.addIncludePath(b.path("vendor/libmdbx/src"));
    mdbx.root_module.link_libc = true;

    lib.root_module.linkLibrary(mdbx);
    lib.root_module.link_libc = true;

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
        const native_musl = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .musl,
        });
        const test_target = if (target.query.isNative()) native_musl else target;

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

        mdbx.root_module.addCSourceFile(.{
            .file = b.path("vendor/libmdbx/src/alloy.c"),
            .flags = flags,
        });

        mdbx.root_module.addCSourceFile(.{
            .file = b.path("version.c"),
            .flags = flags,
        });

        mdbx.root_module.addCSourceFile(.{
            .file = b.path("cpu_stub.c"),
            .flags = &[_][]const u8{"-fPIC"},
        });

        mdbx.root_module.addIncludePath(b.path("vendor/libmdbx"));
        mdbx.root_module.addIncludePath(b.path("vendor/libmdbx/src"));
        mdbx.root_module.link_libc = true;

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

        lib.root_module.linkLibrary(mdbx);
        lib.root_module.link_libc = true;

        b.installArtifact(lib);

        const mdbx_tests = b.addLibrary(.{
            .name = "mdbx_tests",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = test_target,
                .optimize = optimize,
            }),
        });

        const cpu_arch_tests = test_target.result.cpu.arch;
        const abi_tests = test_target.result.abi;
        const flags_tests: []const []const u8 = if (cpu_arch_tests == .x86_64 and (abi_tests == .gnu or abi_tests == .gnueabi or abi_tests == .gnueabihf))
            &x86_gnu_flags_test
        else if (cpu_arch_tests == .x86_64)
            &x86_flags_test
        else if (abi_tests == .gnu or abi_tests == .gnueabi or abi_tests == .gnueabihf)
            &glibc_cross_flags_test
        else
            &base_flags_test;

        mdbx_tests.root_module.addCSourceFile(.{
            .file = b.path("vendor/libmdbx/src/alloy.c"),
            .flags = flags_tests,
        });

        mdbx_tests.root_module.addCSourceFile(.{
            .file = b.path("version.c"),
            .flags = flags_tests,
        });

        mdbx_tests.root_module.addCSourceFile(.{
            .file = b.path("cpu_stub.c"),
            .flags = &[_][]const u8{"-fPIC"},
        });

        mdbx_tests.root_module.addIncludePath(b.path("vendor/libmdbx"));
        mdbx_tests.root_module.addIncludePath(b.path("vendor/libmdbx/src"));
        mdbx_tests.root_module.link_libc = true;

        const lib_tests = b.addLibrary(.{
            .name = "lmdbx_tests",
            .linkage = .static,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = test_target,
                .optimize = optimize,
            }),
        });

        lib_tests.root_module.linkLibrary(mdbx_tests);
        lib_tests.root_module.link_libc = true;

        // Tests for cursor functions
        const cursor_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/test_cursor.zig"),
                .target = test_target,
                .optimize = optimize,
            }),
        });

        cursor_tests.root_module.linkLibrary(mdbx_tests);
        cursor_tests.root_module.link_libc = true;
        cursor_tests.use_new_linker = false;

        const run_cursor_tests = b.addRunArtifact(cursor_tests);

        // Tests for C API functions
        const c_api_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/test_c_api.zig"),
                .target = test_target,
                .optimize = optimize,
            }),
        });

        c_api_tests.root_module.addImport("lmdbx", lib_tests.root_module);
        c_api_tests.root_module.linkLibrary(lib_tests);
        c_api_tests.root_module.linkLibrary(mdbx_tests);
        c_api_tests.root_module.link_libc = true;
        c_api_tests.use_new_linker = false;

        const run_c_api_tests = b.addRunArtifact(c_api_tests);

        const test_step = b.step("test", "Run all integration tests");
        test_step.dependOn(&run_cursor_tests.step);
        test_step.dependOn(&run_c_api_tests.step);

        const compact_test_exe = b.addExecutable(.{
            .name = "compact_test",
            .root_module = b.createModule(.{
                .root_source_file = b.path("compact_test.zig"),
                .target = test_target,
                .optimize = optimize,
            }),
        });
        compact_test_exe.root_module.addImport("lmdbx", lib_tests.root_module);
        compact_test_exe.root_module.linkLibrary(lib_tests);
        compact_test_exe.root_module.linkLibrary(mdbx_tests);
        compact_test_exe.root_module.link_libc = true;

        const run_compact_test = b.addRunArtifact(compact_test_exe);
        const compact_step = b.step("compact-test", "Run compact test");
        compact_step.dependOn(&run_compact_test.step);
    }
}
