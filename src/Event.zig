const std = @import("std");

pub const Event = struct {
    pub const Type = enum {
        Closed,
    };

    type: Type,
};
