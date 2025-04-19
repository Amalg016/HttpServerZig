const std = @import("std");
const mime = @import("../utils/mime.zig");
const response = @import("../http/response.zig");

// Validate the file path to prevent directory traversal attacks
fn validatePath(allocator: std.mem.Allocator, baseDir: []const u8, path: []const u8) ![]const u8 {
    // const relPath = try std.mem.concat(std.heap.page_allocator, u8, &.{ baseDir, path });
    // defer std.heap.page_allocator.free(relPath);

    // std.debug.print("Path: {s} \n", .{relPath});
    if (std.mem.eql(u8, path, "")) {
        return error.PathEmpty;
    }
    const resolvedPath = try std.fs.path.resolve(allocator, &.{ baseDir, path });

    std.debug.print("ResolvedPath: {s}\n path: {s} \n\n", .{ resolvedPath, path });
    // Ensure the resolved path is within the base directory
    if (!std.mem.startsWith(u8, resolvedPath, baseDir)) {
        return error.PathTraversal;
    }

    // Reject paths containing ".." or absolute paths
    if (std.mem.containsAtLeast(u8, path, 1, "..") or std.fs.path.isAbsolute(path)) {
        return error.PathTraversal;
    }
    return resolvedPath;
}

pub fn serveFile(stream: std.net.Stream, path: []const u8) !void {
    const baseDir = "public";

    // Using an arena allocator for the request
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Validate the path
    const fullPath = validatePath(allocator, baseDir, path[1..]) catch |err| {
        switch (err) {
            error.PathTraversal => try response.sendErrorResponse(stream, "403 Forbidden", "403 Forbidden: Path traversal detected"),
            error.PathEmpty => try response.sendErrorResponse(stream, "403 Forbidden", "403 Forbidden: Path is forbidden"),
            else => return err,
        }
        return;
    };

    var file = std.fs.cwd().openFile(fullPath, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => try response.sendErrorResponse(stream, "404 Not Found", "404 Not Found"),
            error.AccessDenied => try response.sendErrorResponse(stream, "403 Forbidden", "403 Forbidden"),
            else => {
                std.debug.print("Tried accesing here {s}", .{fullPath});
                return err;
            },
        }
        return;
    };
    defer file.close();

    const fileSize = try file.getEndPos();
    const mimeType = mime.getMimeType(path);

    const headers = try std.fmt.allocPrint(std.heap.page_allocator, "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {}\r\n\r\n", .{ mimeType, fileSize });
    defer std.heap.page_allocator.free(headers);
    try stream.writeAll(headers);

    var buffer: [4096]u8 = undefined;
    var totalRead: usize = 0;
    while (totalRead < fileSize) {
        const readSize = try file.read(buffer[0..]);
        try stream.writeAll(buffer[0..readSize]);
        totalRead += readSize;
    }
}
