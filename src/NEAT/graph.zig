const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const Graph = struct {
    const Node = struct {
        incoming_edges_count: u32,
        depth: u32,
        outgoing_edges: std.ArrayList(u32),

        pub fn get_outgoing_count(self: *Node) u32 {
            return self.outgoing_edges.items.len();
        }
    };
    nodes: std.ArrayList(Node),
    allocator: Allocator,

    const GraphError = error{
        InvalidNode,
        InvalidConnection,
    };

    pub fn init(allocator: Allocator) Graph {
        return Graph{
            .nodes = std.ArrayList(Node){ .allocator = allocator, .capacity = 0, .items = &[_]Node{} },
            .allocator = allocator,
        };
    }

    pub fn add_node(self: *Graph) void {
        const node = Node{
            .incoming_edges_count = 0,
            .depth = 0,
            .outgoing_edges = std.ArrayList(u32){ .allocator = self.allocator, .capacity = 0, .items = &[_]u32{} },
        };
        self.nodes.append(node) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            std.process.exit(1);
        };
    }

    fn is_valid(self: *Graph, node_id: u32) GraphError!void {
        if (node_id >= self.nodes.items.len) {
            return GraphError.InvalidNode;
        }
    }

    fn is_descendant(self: *Graph, from: u32, to: u32) GraphError!void {
        const outgoings = self.nodes.items[from].outgoing_edges;
        for (outgoings.items) |outgoing| {
            if (outgoing == to) {
                return GraphError.InvalidConnection;
            }
        }
    }

    fn is_ancestor(self: *Graph, from: u32, to: u32) GraphError!void {
        const outgoings = self.nodes.items[to].outgoing_edges;
        try self.is_descendant(to, from);
        for (outgoings.items) |outgoing| {
            try self.is_ancestor(outgoing, from);
        }
    }

    pub fn add_edge(self: *Graph, from: u32, to: u32) GraphError!void {
        try self.is_valid(from);
        try self.is_valid(to);
        if (from == to) {
            return GraphError.InvalidConnection;
        }
        try self.is_descendant(from, to);
        try self.is_ancestor(from, to);

        self.nodes.items[from].outgoing_edges.append(to) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            std.process.exit(1);
        };
        self.nodes.items[to].incoming_edges_count += 1;
    }

    fn compute_depths(self: *Graph) void {
        for (0..self.nodes.items.len) |i| {
            self.nodes.items[i].depth = 0;
        }

        for (self.nodes.items) |node| {
            const outgoings = node.outgoing_edges;
            for (outgoings.items) |outgoing| {
                self.nodes.items[outgoing].depth = @max(self.nodes.items[outgoing].depth, node.depth + 1);
            }
        }
    }

    pub fn remove_edge(self: *Graph, from: u32, to: u32) GraphError!void {
        try is_valid(from);
        try is_valid(to);
        if (from == to) {
            return GraphError.InvalidConnection;
        }
        try is_descendant(from, to);
        try is_ancestor(from, to);

        self.nodes.items[from].outgoing_edges.remove(to);
        self.nodes.items[to].incoming_edges_count -= 1;
    }

    fn cmp_node_depths(context: *Graph, a: u32, b: u32) bool {
        return std.sort.asc(u32)({}, context.nodes.items[a].depth, context.nodes.items[b].depth);
    }

    fn get_order(self: *Graph) []u32 {
        self.compute_depths();
        var order = self.allocator.alloc(u32, self.nodes.items.len) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            std.process.exit(1);
        };
        for (0..self.nodes.items.len) |i| {
            order[i] = @intCast(i);
        }

        std.sort.insertion(u32, order, self, cmp_node_depths);

        return order;
    }

    pub fn to_string(self: *Graph) ![]u8 {
        const order = self.get_order();
        var buffer: [5024]u8 = undefined;
        var len: usize = 0;
        var printed: []u8 = undefined;

        for (order) |index| {
            const node = self.nodes.items[index];
            const depth = node.depth;
            const outgoings = node.outgoing_edges;
            for (0..depth) |_| {
                printed = try std.fmt.bufPrint(buffer[len..], "  ", .{});
                len += printed.len;
            }
            printed = try std.fmt.bufPrint(buffer[len..], "Node {}: ", .{index});
            len += printed.len;
            for (outgoings.items) |outgoing| {
                printed = try std.fmt.bufPrint(buffer[len..], "{} ", .{outgoing});
                len += printed.len;
            }
            printed = try std.fmt.bufPrint(buffer[len..], "\n", .{});
            len += printed.len;
        }
        return buffer[0..len];
    }

    pub fn print(self: *Graph) void {
        const buffer = self.to_string() catch |err| {
            std.debug.print("Error: {}\n", .{err});
            std.process.exit(1);
        };
        std.debug.print("{s}", .{buffer});
    }
};

test "graph" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();
    var graph = Graph.init(allocator);
    for (0..4) |_| {
        graph.add_node();
    }
    try graph.add_edge(0, 1);
    try graph.add_edge(1, 2);
    try graph.add_edge(2, 3);
    try graph.add_edge(0, 3);
    // graph.print();
    const str = graph.to_string() catch |err| {
        std.debug.print("Error: {}\n", .{err});
        std.process.exit(1);
    };
    try testing.expectEqualStrings("Node 0: 1 3 \n" ++
        "  Node 1: 2 \n" ++
        "    Node 2: 3 \n" ++
        "      Node 3: \n", str);
    try testing.expect(graph.nodes.items[0].depth == 0);
    try testing.expect(graph.nodes.items[1].depth == 1);
    try testing.expect(graph.nodes.items[2].depth == 2);
    try testing.expect(graph.nodes.items[3].depth == 3);
}
