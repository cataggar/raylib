const std = @import("std");
const camera = @import("rcamera");
const math = @import("raymath");

test "translated camera and vector operations have complete header context" {
    var view: camera.Camera = .{
        .position = .{ .x = 0, .y = 0, .z = 1 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = @import("raylib").CAMERA_PERSPECTIVE,
    };
    const forward = camera.GetCameraForward(&view);
    try std.testing.expectEqual(@as(f32, -1), forward.z);
    const result = math.Vector2Add(.{ .x = 2, .y = 3 }, .{ .x = 4, .y = 5 });
    try std.testing.expectEqual(@as(f32, 6), result.x);
    try std.testing.expectEqual(@as(f32, 8), result.y);
}
