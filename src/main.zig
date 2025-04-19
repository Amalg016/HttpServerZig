const std = @import("std");
const http = @import("http/request.zig");
const fs = @import("fs/file.zig");

const net = std.net;

pub fn main() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 8080);

    var server = try address.listen(.{ .reuse_port = true, .reuse_address = true });
    defer server.deinit();

    std.debug.print("Server listening on http://{}:{}\n", .{ address.in, address.getPort() });

    while (true) {
        const conn = try server.accept();
        var thread = try std.Thread.spawn(.{}, handleConnection, .{conn});
        thread.detach();
    }
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

fn handleConnection(conn: net.Server.Connection) !void {
    defer conn.stream.close();

    var recv_buf: [4096]u8 = undefined;
    var recv_total: usize = 0;
    while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
        if (recv_len == 0) break;
        recv_total += recv_len;
        if (std.mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) {
            break;
        }
    } else |read_err| {
        std.debug.print("Error reading from client: {}\n", .{read_err});
        return read_err;
    }

    const recv_data = recv_buf[0..recv_total];
    if (recv_data.len == 0) {
        std.debug.print("Got connection but no header!\n", .{});
        return error.InvalidHeader;
    }
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const request = try http.Request.parse(allocator, recv_data);
    try fs.serveFile(conn.stream, request.path);

    // // Send a simple response
    // const response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\n\r\nHello, World!";
    // _ = try conn.stream.writeAll(response);

}
