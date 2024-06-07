const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const g = @import("NEAT/graph.zig");

// const scalar = f32;

pub fn main() !void {
    r.InitWindow(960, 540, "Test Window");
    r.SetTargetFPS(30);
    defer r.CloseWindow();

    var x: c_int = 0;

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        r.ClearBackground(r.BLACK);
        r.DrawText("Congrats! You created your first window!", 190, 200, 20, r.LIGHTGRAY);
        r.DrawRectangle(@mod(x, 960), 10, 100, 100, r.RED);
        x += 10;
        r.EndDrawing();
    }
}
