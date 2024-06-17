const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const GraphError = error{
    InvalidNode,
    InvalidConnection,
};

pub const Graph = struct {
    const Node = struct {
        incoming_edges_count: u32,
        depth: u32,
        outgoing_edges: std.ArrayList(u32),

        pub fn getOutgoingCount(self: *Node) u32 {
            return @intCast(self.outgoing_edges.items.len);
        }
    };
    nodes: std.ArrayList(Node),

    pub fn init(allocator: Allocator) Graph {
        return Graph{
            .nodes = std.ArrayList(Node).init(allocator),
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.nodes.items) |node| {
            node.outgoing_edges.deinit();
        }
        self.nodes.deinit();
    }

    pub fn clear(self: *Graph) void {
        for (self.nodes.items) |node| {
            node.outgoing_edges.clearAndFree();
        }
        self.nodes.clearAndFree();
    }

    pub fn addNode(self: *Graph) void {
        const node = Node{
            .incoming_edges_count = 0,
            .depth = 0,
            .outgoing_edges = std.ArrayList(u32).init(self.nodes.allocator),
        };
        self.nodes.append(node) catch unreachable;
    }

    fn isValid(self: *Graph, node_id: u32) GraphError!void {
        if (node_id >= self.nodes.items.len) {
            return GraphError.InvalidNode;
        }
    }

    // Check if node_1 is a descendant of node_2
    fn isDescendant(self: *Graph, node_1: u32, node_2: u32) GraphError!void {
        const outgoings = self.nodes.items[node_2].outgoing_edges;
        for (outgoings.items) |outgoing| {
            if (outgoing == node_1) {
                return GraphError.InvalidConnection;
            }
        }
    }

    // Check if node_1 is an ancestor of node_2
    fn isAncestor(self: *Graph, node_1: u32, node_2: u32) GraphError!void {
        const outgoings = self.nodes.items[node_1].outgoing_edges;
        try self.isDescendant(node_2, node_1);
        for (outgoings.items) |outgoing| {
            try self.isAncestor(outgoing, node_2);
        }
    }

    pub fn addEdge(self: *Graph, from: u32, to: u32) GraphError!void {
        try self.isValid(from);
        try self.isValid(to);
        if (from == to) {
            return GraphError.InvalidConnection;
        }
        try self.isAncestor(to, from);
        try self.isDescendant(to, from);

        self.nodes.items[from].outgoing_edges.append(to) catch unreachable;
        self.nodes.items[to].incoming_edges_count += 1;
    }

    pub fn computeDepths(self: *Graph) void {
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

    pub fn removeEdge(self: *Graph, from: u32, to: u32) GraphError!void {
        const connections = self.nodes.items[from].outgoing_edges;
        var found = false;
        for (connections.items, 0..) |connection, i| {
            if (connection == to) {
                found = true;
                _ = self.nodes.items[from].outgoing_edges.swapRemove(i);
                self.nodes.items[to].incoming_edges_count -= 1;
                break;
            }
        }
        if (!found) {
            return GraphError.InvalidConnection;
        }
    }

    // fn cmpNodeDepths(context: *Graph, a: u32, b: u32) bool {
    //     return std.sort.asc(u32)({}, context.nodes.items[a].depth, context.nodes.items[b].depth);
    // }

    // fn getOrder(self: *Graph) []u32 {
    //     self.computeDepths();
    //     var order = self.allocator.alloc(u32, self.nodes.items.len) catch |err| {
    //         std.debug.print("Error: {}\n", .{err});
    //         std.process.exit(1);
    //     };

    //     for (0..self.nodes.items.len) |i| {
    //         order[i] = @intCast(i);
    //     }

    //     std.sort.insertion(u32, order, self, cmpNodeDepths);

    //     return order;
    // }
};

test "graph" {
    const allocator = testing.allocator;
    var graph = Graph.init(allocator);
    defer graph.deinit();
    for (0..4) |_| {
        graph.addNode();
    }
    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 3);
    try graph.addEdge(0, 3);
    graph.computeDepths();
    try testing.expect(graph.nodes.items[0].depth == 0);
    try testing.expect(graph.nodes.items[1].depth == 1);
    try testing.expect(graph.nodes.items[2].depth == 2);
    try testing.expect(graph.nodes.items[3].depth == 3);
}

test "cyclic_graph" {
    const allocator = testing.allocator;
    var graph = Graph.init(allocator);
    defer graph.deinit();
    for (0..4) |_| {
        graph.addNode();
    }
    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 3);
    try graph.addEdge(0, 3);
    try testing.expectError(GraphError.InvalidConnection, graph.addEdge(3, 0));
    try testing.expectError(GraphError.InvalidConnection, graph.addEdge(0, 1));
}
