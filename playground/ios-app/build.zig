const std = @import("std");
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *std.Build) void {
    // Production builds always use ReleaseSafe (see repo AGENTS.md).
    const optimize: OptimizeMode = .ReleaseSafe;

    const is_macos = b.graph.host.result.os.tag == .macos;

    // iOS deployment target: 26.0 (matches xcodegen deploymentTarget and the
    // device under test, iPhone 11 Pro). Both the Zig slices and the Xcode
    // targets must agree on this.
    const ios_version: std.SemanticVersion = .{ .major = 26, .minor = 0, .patch = 0 };

    // liblex is a pure-Zig static library exposing a C ABI; it has no libc or
    // Apple-SDK dependency, so both iOS slices cross-compile cleanly on Linux.
    // The device slice targets arm64 iPhone hardware (PLATFORM_IOS); the
    // simulator slice targets the arm64 iOS Simulator (PLATFORM_IOSSIMULATOR)
    // for Apple Silicon Macs (M1 Pro).
    const device_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
        .os_version_min = .{ .semver = ios_version },
    });
    const sim_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
        .abi = .simulator,
        .os_version_min = .{ .semver = ios_version },
    });

    // Strip debug info from the iOS slices. This keeps ReleaseSafe's runtime
    // safety checks but lets the compiler dead-code-eliminate Zig's panic
    // stack-trace symbolizer (std.debug.writeCurrentStackTrace). That symbolizer
    // references the dyld SPI `_dyld_get_image_header_containing_address`, which
    // the iOS SDK refuses to link against, so an unstripped slice fails to link
    // into the keyboard extension. On panic the engine still aborts; it just
    // prints "debug info stripped" instead of a symbolicated trace.
    const device_lib = b.addLibrary(.{
        .name = "lex",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lex.zig"),
            .target = device_target,
            .optimize = optimize,
            .strip = true,
        }),
    });
    const sim_lib = b.addLibrary(.{
        .name = "lex",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lex.zig"),
            .target = sim_target,
            .optimize = optimize,
            .strip = true,
        }),
    });

    // Stage each slice under its own directory (same archive name, distinct
    // path) so `xcodebuild -create-xcframework` can consume them, plus the
    // public C header that the XCFramework advertises.
    const install_device = b.addInstallFile(device_lib.getEmittedBin(), "lib/ios-device/liblex.a");
    const install_sim = b.addInstallFile(sim_lib.getEmittedBin(), "lib/ios-sim/liblex.a");
    const install_header = b.addInstallFile(b.path("src/lex.h"), "include/lex.h");
    b.getInstallStep().dependOn(&install_device.step);
    b.getInstallStep().dependOn(&install_sim.step);
    b.getInstallStep().dependOn(&install_header.step);

    // Engine unit tests run on the host so they can be exercised on a Linux dev
    // machine (the iOS app can only be built on macOS).
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lex.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run liblex unit tests on the host");
    test_step.dependOn(&run_lib_tests.step);

    const xcframework_step = b.step("xcframework", "Build liblex.xcframework (macOS only)");
    const app_step = b.step("app", "Generate the Xcode project and build for the simulator (macOS only)");

    if (!is_macos) {
        const notice = b.addSystemCommand(&.{
            "echo",
            "liblex.xcframework and the iOS app can only be built on macOS. " ++
                "On this host run `zig build` (produces the iOS static slices) and `zig build test`.",
        });
        xcframework_step.dependOn(&notice.step);
        app_step.dependOn(&notice.step);
        return;
    }

    // --- macOS-only pipeline ---

    // Re-pack each archive with the system `ar` (Apple's linker rejects
    // non-8-byte-aligned archive members produced by Zig), then assemble the
    // XCFramework with the device and simulator slices. Re-packing happens here,
    // on macOS, so the members use Apple's `ar` rather than GNU `ar`.
    const xcframework = b.addSystemCommand(&.{
        "/bin/sh", "-c",
        \\set -e
        \\for slice in ios-device ios-sim; do
        \\  a="zig-out/lib/$slice/liblex.a"
        \\  tmp=$(mktemp -d)
        \\  cp "$a" "$tmp/lib.a"
        \\  (cd "$tmp" && ar x lib.a && rm lib.a && chmod 644 *.o && /usr/bin/ar rcs lib.a *.o)
        \\  cp "$tmp/lib.a" "$a"
        \\  rm -rf "$tmp"
        \\done
        \\rm -rf zig-out/liblex.xcframework
        \\xcodebuild -create-xcframework \
        \\  -library zig-out/lib/ios-device/liblex.a -headers zig-out/include \
        \\  -library zig-out/lib/ios-sim/liblex.a -headers zig-out/include \
        \\  -output zig-out/liblex.xcframework
        ,
    });
    xcframework.has_side_effects = true;
    xcframework.step.dependOn(b.getInstallStep());
    xcframework_step.dependOn(&xcframework.step);

    // Generate the Xcode project from project.yaml and build the app + keyboard
    // extension for the iPhone 11 Pro simulator (no code signing required).
    const app = b.addSystemCommand(&.{
        "/bin/sh", "-c",
        \\set -e
        \\(cd ios && xcodegen generate --spec project.yaml)
        \\xcodebuild \
        \\  -project ios/Lex.xcodeproj \
        \\  -scheme Lex \
        \\  -configuration Debug \
        \\  -sdk iphonesimulator \
        \\  -destination 'platform=iOS Simulator,name=iPhone 11 Pro' \
        \\  -derivedDataPath ios/build \
        \\  CODE_SIGNING_ALLOWED=NO \
        \\  build
        ,
    });
    app.has_side_effects = true;
    app.step.dependOn(&xcframework.step);
    app_step.dependOn(&app.step);
}
