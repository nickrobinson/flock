const std = @import("std");

// Use the wrapper functions that are properly exported
extern fn mdns_wrapper_socket_open_ipv4(port: u16) c_int;
extern fn mdns_wrapper_socket_close(sock: c_int) void;
extern fn mdns_wrapper_test() c_int;
extern fn mdns_wrapper_send_discovery(sock: c_int) c_int;

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try stdout.flush();
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn Java_com_example_flock_MainActivity_add(
    env: ?*anyopaque,
    obj: ?*anyopaque,
    a: i32,
    b: i32,
) callconv(.c) i32 {
    _ = env;
    _ = obj;
    return add(a, b);
}

export fn Java_com_example_flock_MainActivity_testMdnsLink(
    env: ?*anyopaque,
    obj: ?*anyopaque,
) callconv(.c) i32 {
    _ = env;
    _ = obj;

    // First just test that basic linking works
    const test_result = mdns_wrapper_test();
    if (test_result != 42) {
        return -1;
    }

    // Try to open a socket (might fail due to permissions, but tests linking)
    const sock = mdns_wrapper_socket_open_ipv4(5353);
    if (sock >= 0) {
        mdns_wrapper_socket_close(sock);
        return sock; // Return the socket fd to show success
    }

    // Return -1 to indicate socket failed (but linking worked since we got here)
    return -1;
}

export fn Java_com_example_flock_MainActivity_testMdnsDiscovery(
    env: ?*anyopaque,
    obj: ?*anyopaque,
) callconv(.c) i32 {
    _ = env;
    _ = obj;

    // Open socket on ephemeral port (0 = let system choose)
    const sock = mdns_wrapper_socket_open_ipv4(0);
    if (sock < 0) {
        return sock; // Failed to open socket
    }

    // Send discovery query - THIS SHOULD GENERATE NETWORK TRAFFIC!
    const query_result = mdns_wrapper_send_discovery(sock);

    // Keep socket open briefly to receive responses (optional)
    // In real code, you'd want to receive responses here

    // Clean up
    mdns_wrapper_socket_close(sock);

    // Return query_result (should be > 0 if query was sent)
    return query_result;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
