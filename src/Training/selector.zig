const std = @import("std");

pub const Selector = struct {
    const Entry = struct {
        index: usize,
        socre: f32,
        wheel_score: f32,
    };

    entries: std.ArrayList(Entry),

    pub fn create(allocator: std.mem.Allocator) Selector {
        return Selector{ .entries = std.ArrayList(Entry).init(allocator) };
    }

    pub fn clear(self: *Selector) void {
        self.entries.clearAndFree();
    }

    pub fn add(self: *Selector, index: usize, score: f32) void {
        self.entries.append(Entry{ .index = index, .socre = score, .wheel_score = 0.0 }) catch unreachable;
    }

    pub fn normaliseEntries(self: *Selector) void {
        var total_score: f32 = 0.0;
        for (self.entries.items) |entry| {
            total_score += entry.socre;
        }

        var normalised_score: f32 = 0.0;
        if (total_score == 0.0) {
            const virtual_score = 1.0 / @as(f32, @floatFromInt(self.entries.items.len));
            for (0..self.entries.items.len) |entry| {
                normalised_score += virtual_score;
                self.entries.items[entry].wheel_score = normalised_score;
            }
        } else {
            for (0..self.entries.items.len) |entry| {
                normalised_score += self.entries.items[entry].socre / total_score;
                self.entries.items[entry].wheel_score = normalised_score;
            }
        }
    }

    pub fn pick(self: *Selector) !usize {
        if (self.entries.items.len == 0) {
            return error.NoEntries;
        }

        var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const score_threshold = random.random().float(f32);
        for (self.entries.items) |entry| {
            if (entry.wheel_score > score_threshold) {
                return entry.index;
            }
        }
        return self.entries.items[self.entries.items.len - 1].index;
    }
};

test "selector" {
    const allocator = std.testing.allocator;
    var selector = Selector.create(allocator);
    defer selector.clear();
    selector.add(0, 10);
    selector.add(1, 0.5);
    selector.add(2, 0.1);
    selector.normaliseEntries();
    const index = try selector.pick();

    try std.testing.expect(index == 0 or index == 1);
}
