const std = @import("std");

pub fn sendErrorResponse(stream: std.net.Stream, status: []const u8, message: []const u8) !void {
    const response = try std.fmt.allocPrint(std.heap.page_allocator, "HTTP/1.1 {s}\r\nContent-Type: text/plain\r\nContent-Length: {}\r\n\r\n{s}", .{ status, message.len, message });
    defer std.heap.page_allocator.free(response);
    try stream.writeAll(response);
}
