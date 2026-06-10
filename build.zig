const std = @import("std");
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *std.Build) void {
    // Production builds always use ReleaseSafe (see AGENTS.md).
    const optimize: OptimizeMode = .ReleaseSafe;

    const host = b.graph.host;
    const host_arch = host.result.cpu.arch;
    const is_macos = host.result.os.tag == .macos;

    // Static liblex, targeting macOS with the host CPU architecture. The app is
    // only ever linked on macOS, so the library arch tracks the build machine
    // and matches swiftc's default architecture.
    const macos_target = b.resolveTargetQuery(.{
        .cpu_arch = host_arch,
        .os_tag = .macos,
        .os_version_min = .{ .semver = .{ .major = 26, .minor = 0, .patch = 0 } },
    });
    const lib = b.addLibrary(.{
        .name = "lex",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lex.zig"),
            .target = macos_target,
            .optimize = optimize,
        }),
    });

    // Unit tests run on the host so they can be exercised on a Linux dev
    // machine (the macOS app cannot be built there).
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lex.zig"),
            .target = host,
            // Debug build for tests to surface issues (extra safety checks,
            // better diagnostics) earlier than the ReleaseSafe production build.
            .optimize = .Debug,
        }),
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run liblex unit tests on the host");
    test_step.dependOn(&run_lib_tests.step);

    const app_step = b.step("app", "Build Lex.app (ad-hoc signed)");
    const app_unsigned_step = b.step("app-unsigned", "Build Lex.app (unsigned)");
    const run_step = b.step("run", "Build and open Lex.app");

    // Off macOS the app pipeline cannot run; surface a clear notice instead of
    // failing on a missing swiftc/codesign.
    if (!is_macos) {
        const notice = b.addSystemCommand(&.{
            "echo",
            "Lex.app can only be built on macOS. On this host run `zig build test`.",
        });
        app_step.dependOn(&notice.step);
        app_unsigned_step.dependOn(&notice.step);
        run_step.dependOn(&notice.step);
        b.getInstallStep().dependOn(&notice.step);
        return;
    }

    // --- macOS build pipeline ---

    // swiftc target triple, e.g. "arm64-apple-macosx26.0".
    const swift_arch = switch (host_arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("unsupported host architecture for macOS build"),
    };
    const swift_target = b.fmt("{s}-apple-macosx26.0", .{swift_arch});

    // Ensure the bundle's executable directory exists before swiftc writes to it.
    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", "macos/Lex.app/Contents/MacOS" });
    mkdir.has_side_effects = true;

    // Re-pack the archive (workaround for non-8-byte-aligned archive members
    // that Apple's linker rejects).
    const repack = b.addSystemCommand(&.{
        "/bin/sh", "-c",
        \\tmp=$(mktemp -d) && \
        \\cp "$1" "$tmp/lib.a" && \
        \\(cd "$tmp" && ar x lib.a && rm lib.a && chmod 644 *.o && /usr/bin/ar rcs lib.a *.o) && \
        \\cp "$tmp/lib.a" "$1" && \
        \\rm -rf "$tmp"
        ,
        "--",
    });
    repack.addArtifactArg(lib);
    repack.has_side_effects = true;

    // Remove any stale code signature before writing the new binary so an
    // unsigned build is cleanly unsigned (and a re-sign starts fresh).
    const strip_sig = b.addSystemCommand(&.{ "rm", "-rf", "macos/Lex.app/Contents/_CodeSignature" });
    strip_sig.has_side_effects = true;

    // Compile Swift and statically link liblex.
    const swiftc = b.addSystemCommand(&.{
        "swiftc",
        "-parse-as-library",
        "-target",
        swift_target,
        "macos/Lex.swift",
        "-import-objc-header",
        "src/lex.h",
    });
    swiftc.addPrefixedDirectoryArg("-L", lib.getEmittedBinDirectory());
    swiftc.addArgs(&.{"-llex"});
    swiftc.addArgs(&.{ "-o", "macos/Lex.app/Contents/MacOS/Lex" });
    swiftc.step.dependOn(&mkdir.step);
    swiftc.step.dependOn(&repack.step);
    swiftc.step.dependOn(&strip_sig.step);
    swiftc.has_side_effects = true;

    // app-unsigned: stop after swiftc, leaving the bundle unsigned.
    app_unsigned_step.dependOn(&swiftc.step);

    // app: ad-hoc codesign the bundle.
    const codesign = b.addSystemCommand(&.{ "codesign", "-f", "-s", "-", "macos/Lex.app" });
    codesign.step.dependOn(&swiftc.step);
    codesign.has_side_effects = true;
    app_step.dependOn(&codesign.step);

    // Default `zig build` builds the signed app.
    b.getInstallStep().dependOn(&codesign.step);

    // run: open the signed app.
    const open = b.addSystemCommand(&.{ "open", "macos/Lex.app" });
    open.step.dependOn(&codesign.step);
    run_step.dependOn(&open.step);
}
