const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const stadium = @import("Training/stadium.zig");
const config = @import("Physics/config.zig");
const demo = @import("Demo/demo.zig");

const DT = 0.01;

pub fn main() !void {
    // Raylib initialization
    r.InitWindow(config.world_size, config.world_height, "Inverted Pendulum Simulation");
    r.SetTargetFPS(60);

    // AI initialization
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var s = stadium.Stadium.create(allocator);
    defer s.destroy(allocator);
    var d = false;
    var demo_scene = demo.Demo{};

    while (!r.WindowShouldClose()) {
        if (r.IsKeyPressed(r.KEY_T)) {
            d = !d;
            if (d) {
                demo_scene.init(allocator, s.agents.items[0]);
            }
        }

        if (r.IsKeyPressed(r.KEY_E)) {
            if (d) {
                demo_scene.enable_ai = !demo_scene.enable_ai;
            }
        }

        if (!d) {
            try s.update(allocator, DT);
        } else {
            try demo_scene.update(DT);
            demo_scene.render();
        }
    }

    r.CloseWindow();
}

// T - Toggle demo mode
// E - Toggle AI
// R - Reset in demo mode
