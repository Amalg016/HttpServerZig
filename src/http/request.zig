const std = @import("std");

pub const Request = struct {
    method: []const u8,
    path: []const u8,
    headers: std.StringHashMap([]const u8),

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Request {
        var request = Request{
            .method = undefined,
            .path = undefined,
            .headers = std.StringHashMap([]const u8).init(allocator),
        };

        var lines = std.mem.splitSequence(u8, data, "\r\n");

        if (lines.next()) |requestLine| {
            var parts = std.mem.splitSequence(u8, requestLine, " ");
            request.method = parts.next() orelse return error.InvalidRequest;
            request.path = parts.next() orelse return error.InvalidRequest;
        } else {
            return error.InvalidRequest;
        }

        while (lines.next()) |line| {
            if (line.len == 0) break;
            var headerParts = std.mem.splitSequence(u8, line, ": ");
            const key = headerParts.next() orelse return error.InvalidHeader;
            const value = headerParts.rest();
            try request.headers.put(key, value);
        }

        return request;
    }
};
