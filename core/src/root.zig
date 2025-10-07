const std = @import("std");
const mdns = @import("mdns.zig");

// Use a simple page allocator instead of GPA for Android compatibility
const allocator = std.heap.page_allocator;

// Global discovery session ID (simplified single-session approach for Android)
var current_session_id: u32 = 0;

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

// Start mDNS discovery session - minimal safe version
export fn Java_com_example_flock_MainActivity_startDiscovery(
    env: ?*anyopaque,
    obj: ?*anyopaque,
    service_type_jstring: ?*anyopaque,
) callconv(.c) i32 {
    _ = env;
    _ = obj;
    _ = service_type_jstring;

    // Use the original simple discovery test instead of complex session management
    const sock = mdns.openMdnsSocketIpv4(0);
    if (sock < 0) {
        return -1; // Failed to open socket
    }

    // Send discovery query
    const query_result = mdns.sendMdnsDiscovery(sock);
    if (query_result < 0) {
        mdns.closeMdnsSocket(sock);
        return -2;
    }
    
    // Store socket for later use
    current_session_id = @intCast(sock);
    return query_result;
}

// Get discovered devices with timeout - minimal safe version
export fn Java_com_example_flock_MainActivity_getDiscoveredDevices(
    env: ?*anyopaque,
    obj: ?*anyopaque,
    timeout_ms: i32,
) callconv(.c) i32 {
    _ = env;
    _ = obj;
    _ = timeout_ms;

    if (current_session_id == 0) {
        return -1; // No active session
    }
    
    // For now, just return 0 to avoid any complex processing that might crash
    // This should at least let the app run without crashing
    return 0;
}

// Static strings to avoid memory issues
const static_unknown = "unknown";
const static_zero = "0";

// Get device information by index and type
export fn Java_com_example_flock_MainActivity_getDeviceInfo(
    env: ?*anyopaque,
    obj: ?*anyopaque,
    index: i32,
    info_type: i32,
) callconv(.c) ?[*:0]const u8 {
    _ = env;
    _ = obj;

    if (current_session_id == 0) {
        return null;
    }
    
    if (index < 0) {
        return null;
    }
    
    // Info type constants (from MainActivity):
    // INFO_NAME = 0, INFO_IP = 1, INFO_PORT = 2
    switch (info_type) {
        0 => { // NAME
            return static_unknown.ptr;
        },
        1 => { // IP
            return static_unknown.ptr;
        },
        2 => { // PORT - return as string for consistency
            return static_zero.ptr;
        },
        else => return null,
    }
}

// Stop discovery and clean up - minimal safe version
export fn Java_com_example_flock_MainActivity_stopDiscovery(
    env: ?*anyopaque,
    obj: ?*anyopaque,
) callconv(.c) void {
    _ = env;
    _ = obj;

    if (current_session_id == 0) {
        return;
    }
    
    // Close the socket stored in current_session_id
    mdns.closeMdnsSocket(@intCast(current_session_id));
    current_session_id = 0;
}
