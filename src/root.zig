const std = @import("std");
const mdns = @import("mdns.zig");

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

    const sock = mdns.openMdnsSocketIpv4(5353);
    if (sock >= 0) {
        mdns.closeMdnsSocket(sock);
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
    const sock = mdns.openMdnsSocketIpv4(0);
    if (sock < 0) {
        return sock; // Failed to open socket
    }

    // Send discovery query - THIS SHOULD GENERATE NETWORK TRAFFIC!
    const query_result = mdns.sendMdnsDiscovery(sock);

    // Keep socket open briefly to receive responses (optional)
    // In real code, you'd want to receive responses here

    // Clean up
    mdns.closeMdnsSocket(sock);

    // Return query_result (should be > 0 if query was sent)
    return query_result;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
