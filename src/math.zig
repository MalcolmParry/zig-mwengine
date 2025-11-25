const std = @import("std");

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);

pub const dir_forward: Vec3 = .{ 1, 0, 0 };
pub const dir_right: Vec3 = .{ 0, 1, 0 };
pub const dir_up: Vec3 = .{ 0, 0, 1 };

pub fn dot(left: anytype, right: anytype) @typeInfo(@TypeOf(left)).vector.child {
    return @reduce(.Add, left * right);
}

fn ToArrayReturnType(t: type) type {
    switch (@typeInfo(t)) {
        .vector => |vec| return [vec.len]vec.child,
        else => @compileError("invalid type"),
    }
}

pub fn toArray(x: anytype) ToArrayReturnType(@TypeOf(x)) {
    const type_info = @typeInfo(@TypeOf(x));
    var result: ToArrayReturnType(@TypeOf(x)) = undefined;

    switch (type_info) {
        .vector => |vec| {
            inline for (0..vec.len) |i| {
                result[i] = x[i];
            }

            return result;
        },
        else => @compileError("invalid type"),
    }
}

test "dot" {
    try std.testing.expect(dot(dir_forward, dir_right) == 0);
    try std.testing.expect(dot(dir_forward, dir_up) == 0);
    try std.testing.expect(dot(dir_forward, -dir_forward) == -1);
    try std.testing.expect(dot(dir_forward, dir_forward) == 1);
}
