const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_step = b.step("test", "Run tests");
    const docs_step = b.step("docs", "Generate documentation");

    const module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (optimize != .Debug) {
        module.strip = true;
        module.error_tracing = false;
        module.omit_frame_pointer = true;
    }

    const libstring = b.dependency("string", .{ .target = target, .optimize = optimize });
    module.addImport("string", libstring.module("string"));

    const exe = b.addExecutable(.{
        .name = "your-project-name",
        .root_module = module,
    });

    const tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/your-project-name.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests_mod.addImport("string", libstring.module("string"));
    tests_mod.addImport("your-project-name", module);

    const tests = b.addTest(.{
        .name = "string_test",
        .root_module = tests_mod,
    });

    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    b.installArtifact(exe);
}
