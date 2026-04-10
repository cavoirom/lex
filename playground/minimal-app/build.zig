const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Match LSMinimumSystemVersion in Info.plist
    const target = b.resolveTargetQuery(.{
        .os_version_min = .{ .semver = .{ .major = 26, .minor = 0, .patch = 0 } },
    });

    // Step 1: Build the Zig static library
    const lib = b.addLibrary(.{
        .name = "minimal",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/minimal.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Step 2: Re-pack the archive (Zig master workaround for non-8-byte-aligned members)
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

    // Step 3: Compile Swift and link with the Zig library
    const swiftc = b.addSystemCommand(&.{
        "swiftc",
        "app/main.swift",
        "-import-objc-header",
        "include/bridging-header.h",
    });
    swiftc.addPrefixedDirectoryArg("-L", lib.getEmittedBinDirectory());
    swiftc.addArgs(&.{"-lminimal"});
    swiftc.addArgs(&.{ "-o", "macos/Minimal.app/Contents/MacOS/Minimal" });
    swiftc.step.dependOn(&repack.step);
    swiftc.has_side_effects = true;

    // Step 4: Ad-hoc codesign
    const codesign = b.addSystemCommand(&.{
        "codesign", "-f", "-s", "-", "macos/Minimal.app",
    });
    codesign.step.dependOn(&swiftc.step);
    codesign.has_side_effects = true;

    // Wire into default install step
    b.getInstallStep().dependOn(&codesign.step);

    // `zig build run` — open the app
    const run = b.addSystemCommand(&.{ "open", "macos/Minimal.app" });
    run.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Build and open Minimal.app");
    run_step.dependOn(&run.step);
}
