const std = @import("std");
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "generatesvg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/generatesvg.zig"),
            .target = b.graph.host,
        }),
    });

    {
        const install = b.addInstallArtifact(exe, .{});
        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);
        if (b.args) |args| {
            run.addArgs(args);
        }
        const run_step = b.step("generatesvg", "Generate the logo as an SVG");
        run_step.dependOn(&run.step);
    }

    const svgs = b.step("svgs", "Generate/Install the SVG files");
    b.getInstallStep().dependOn(svgs);

    {
        const gen = b.addRunArtifact(exe);
        gen.addArgs(&.{ "--fill", "#f7a41d" });
        gen.addArgs(&.{ "--width", "153" });
        gen.addArg("--out");
        svgs.dependOn(&b.addInstallFile(
            gen.addOutputFileArg("zig-mark.svg"),
            "zig-mark.svg",
        ).step);
    }
    {
        const gen = b.addRunArtifact(exe);
        gen.addArgs(&.{ "--fill", "#121212" });
        gen.addArgs(&.{ "--width", "153" });
        gen.addArg("--out");
        svgs.dependOn(&b.addInstallFile(
            gen.addOutputFileArg("zig-mark-neg-black.svg"),
            "zig-mark-neg-black.svg",
        ).step);
    }
    {
        const gen = b.addRunArtifact(exe);
        gen.addArgs(&.{ "--fill", "#fff" });
        gen.addArgs(&.{ "--width", "153" });
        gen.addArg("--out");
        svgs.dependOn(&b.addInstallFile(
            gen.addOutputFileArg("zig-mark-neg-white.svg"),
            "zig-mark-neg-white.svg",
        ).step);
    }
}
