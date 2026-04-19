const std = @import("std");

fn defaultOptimize(b: *std.Build) std.builtin.OptimizeMode {
    if (b.option(std.builtin.OptimizeMode, "optimize", "Prioritize performance, safety, or binary size")) |mode| {
        return mode;
    }
    if (b.option(bool, "release", "Optimize for end users; defaults to ReleaseSmall") orelse false) {
        return .ReleaseSmall;
    }
    return switch (b.release_mode) {
        .off, .any, .small => .ReleaseSmall,
        .fast => .ReleaseFast,
        .safe => .ReleaseSafe,
    };
}

pub fn build(b: *std.Build) void {
    const optimize = defaultOptimize(b);

    // Match LSMinimumSystemVersion in Info.plist
    const target = b.resolveTargetQuery(.{
        .os_version_min = .{ .semver = .{ .major = 26, .minor = 0, .patch = 0 } },
    });

    // Step 1: Build the Zig static library
    const lib = b.addLibrary(.{
        .name = "lex",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/liblex.zig"),
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

    // Derive Swift target triple from host arch + macOS deployment target
    const arch = target.result.cpu.arch;
    const swift_arch: []const u8 = switch (arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("unsupported host architecture for macOS build"),
    };
    const swift_target = b.fmt("{s}-apple-macosx26.0", .{swift_arch});

    // Step 3: Compile Swift and link with the Zig library
    const swiftc = b.addSystemCommand(&.{
        "swiftc",
        "macos/Lex.swift",
        "-import-objc-header",
        "src/liblex.h",
        "-target",
    });
    swiftc.addArg(swift_target);
    swiftc.addPrefixedDirectoryArg("-L", lib.getEmittedBinDirectory());
    swiftc.addArgs(&.{"-llex"});
    swiftc.addArgs(&.{ "-o", "macos/Lex.app/Contents/MacOS/Lex" });
    swiftc.step.dependOn(&repack.step);
    swiftc.has_side_effects = true;

    // Step 4: Strip local symbols before codesigning
    const strip = b.addSystemCommand(&.{
        "strip", "-x", "macos/Lex.app/Contents/MacOS/Lex",
    });
    strip.step.dependOn(&swiftc.step);
    strip.has_side_effects = true;

    // Step 5: Ad-hoc codesign
    const codesign = b.addSystemCommand(&.{
        "codesign", "-f", "-s", "-", "macos/Lex.app",
    });
    codesign.step.dependOn(&strip.step);
    codesign.has_side_effects = true;

    // Wire into default install step
    b.getInstallStep().dependOn(&codesign.step);

    // `zig build run` — open the app
    const run = b.addSystemCommand(&.{ "open", "macos/Lex.app" });
    run.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Build and open Lex.app");
    run_step.dependOn(&run.step);
}
