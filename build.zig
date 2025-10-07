const std = @import("std");
const builtin = @import("builtin");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .android },
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    // Allow override: `zig build -Dandroid-api=29`
    const android_api: u32 = b.option(u32, "android-api", "Android API level (e.g. 29)") orelse 29;

    for (targets) |t| {
        const resolved = b.resolveTargetQuery(t);

        const libflock = b.addLibrary(.{
            .name = "flock",
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/root.zig"),
                .target = resolved,
                .optimize = optimize,
            }),
        });

        // Build mdns for ALL platforms, not just Android
        const mdns_lib = b.addLibrary(.{
            .name = "mdns",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = resolved,
                .optimize = optimize,
            }),
        });

        mdns_lib.addCSourceFile(.{
            .file = b.path("src/mdns_wrapper.c"),
            .flags = &[_][]const u8{"-std=c99"},
        });

        mdns_lib.root_module.addIncludePath(b.path("vendor/mdns"));

        if (t.abi == .android) {
            // --- Find the NDK root ---
            const ndk_dir: []u8 = blk: {
                if (std.process.hasEnvVarConstant("ANDROID_NDK_HOME"))
                    break :blk try std.process.getEnvVarOwned(b.allocator, "ANDROID_NDK_HOME");
                if (std.process.hasEnvVarConstant("ANDROID_NDK_ROOT"))
                    break :blk try std.process.getEnvVarOwned(b.allocator, "ANDROID_NDK_ROOT");
                return error.AndroidNdkNotFound;
            };

            // --- Host prebuilt dir (darwin-arm64 / darwin-x86_64) ---
            const host_arch = "x86_64";
            const prebuilt = try std.fmt.allocPrint(b.allocator, "toolchains/llvm/prebuilt/darwin-{s}", .{host_arch});

            // --- Android arch triple subdir ---
            const arch_subdir = switch (resolved.result.cpu.arch) {
                .aarch64 => "aarch64-linux-android",
                .arm => "arm-linux-androideabi",
                .x86 => "i686-linux-android",
                .x86_64 => "x86_64-linux-android",
                else => @panic("unsupported Android arch"),
            };

            const api_s = try std.fmt.allocPrint(b.allocator, "{d}", .{android_api});

            // --- Sysroot include and lib dirs ---
            const sysroot = b.pathJoin(&.{ ndk_dir, prebuilt, "sysroot" });
            const include_dir = b.pathJoin(&.{ sysroot, "usr", "include" });
            const bionic_lib_dir = b.pathJoin(&.{ sysroot, "usr", "lib", arch_subdir, api_s });

            // Android-specific: add architecture-specific include directory
            const arch_include_dir = b.pathJoin(&.{ sysroot, "usr", "include", arch_subdir });

            // Add NDK headers to mdns for Android
            mdns_lib.root_module.addSystemIncludePath(.{ .cwd_relative = include_dir });
            mdns_lib.root_module.addSystemIncludePath(.{ .cwd_relative = arch_include_dir });
            mdns_lib.root_module.addLibraryPath(.{ .cwd_relative = bionic_lib_dir });

            // Add includes to libflock
            libflock.root_module.addSystemIncludePath(.{ .cwd_relative = include_dir });
            libflock.root_module.addLibraryPath(.{ .cwd_relative = bionic_lib_dir });

            const libc_path = b.pathJoin(&.{ bionic_lib_dir, "libc.so" });
            libflock.addObjectFile(.{ .cwd_relative = libc_path });

            // Link against bionic explicitly; Zig won't synthesize it.
            libflock.linkSystemLibrary("log");
        } else {
            // Non-Android: let Zig provide libc for both libflock and mdns
            libflock.linkLibC();
            mdns_lib.linkLibC();
        }

        // Link mdns to flock for ALL platforms
        libflock.linkLibrary(mdns_lib);
        libflock.root_module.addIncludePath(b.path("vendor/mdns"));

        // Install to a stable, arena-owned string
        const triple_owned = try t.zigTriple(b.allocator);
        const triple = b.dupe(triple_owned);
        const out = b.addInstallArtifact(libflock, .{
            .dest_dir = .{ .override = .{ .custom = triple } },
        });
        b.getInstallStep().dependOn(&out.step);
    }
}
