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

    // Clear the cache when starting new discovery
    device_cache.count = 0;

    const session_id = mdns.startDiscovery(allocator, null) catch |err| {
        switch (err) {
            error.SocketOpenFailed => return -1,
            error.QuerySendFailed => return -2,
            else => return -3,
        }
    };

    current_session_id = session_id;
    return @intCast(session_id);
}

// Get discovered devices with timeout - full implementation
export fn Java_com_example_flock_MainActivity_getDiscoveredDevices(
    env: ?*anyopaque,
    obj: ?*anyopaque,
    timeout_ms: i32,
) callconv(.c) i32 {
    _ = env;
    _ = obj;

    if (current_session_id == 0) {
        return -1; // No active session
    }

    // Wait for responses and collect discovered devices
    const device_count = mdns.listDiscoveredDevices(current_session_id, @intCast(timeout_ms)) catch |err| {
        // Clean up on error
        mdns.stopDiscovery(current_session_id) catch {};
        switch (err) {
            error.InvalidSessionId => return -5,
        }
    };

    // Cache the device information before returning
    device_cache.count = 0;
    
    const count = @min(@as(usize, @intCast(device_count)), MAX_DEVICES);
    
    for (0..count) |i| {
        // Get and cache name
        const name = mdns.getDeviceName(current_session_id, i) catch null;
        if (name) |device_name| {
            const len = @min(device_name.len, MAX_NAME_LEN - 1);
            @memcpy(device_cache.names[i][0..len], device_name[0..len]);
            device_cache.names[i][len] = 0;
        } else {
            @memcpy(device_cache.names[i][0..7], "unknown");
            device_cache.names[i][7] = 0;
        }
        
        // Get and cache IP
        const ip = mdns.getDeviceIp(current_session_id, i) catch null;
        if (ip) |device_ip| {
            const len = @min(device_ip.len, MAX_IP_LEN - 1);
            @memcpy(device_cache.ips[i][0..len], device_ip[0..len]);
            device_cache.ips[i][len] = 0;
        } else {
            @memcpy(device_cache.ips[i][0..7], "unknown");
            device_cache.ips[i][7] = 0;
        }
        
        // Get and cache port
        const port = mdns.getDevicePort(current_session_id, i) catch 0;
        const port_str = std.fmt.bufPrint(&device_cache.ports[i], "{d}", .{port}) catch "0";
        device_cache.ports[i][port_str.len] = 0;
        
        device_cache.count += 1;
    }

    return @intCast(device_cache.count);
}

// Static strings to avoid memory issues
const static_unknown = "unknown";
const static_zero = "0";

// Cached device information to prevent use-after-free
const MAX_DEVICES = 100;
const MAX_NAME_LEN = 256;
const MAX_IP_LEN = 46; // IPv6 max length

var device_cache: struct {
    names: [MAX_DEVICES][MAX_NAME_LEN:0]u8 = undefined,
    ips: [MAX_DEVICES][MAX_IP_LEN:0]u8 = undefined,
    ports: [MAX_DEVICES][16:0]u8 = undefined, // Max port string length
    count: usize = 0,
} = .{};

// Test function to debug alignment issue
export fn flock_test_mdns_recv(env: ?*anyopaque, obj: ?*anyopaque) callconv(.c) i32 {
    _ = env;
    _ = obj;
    
    // Test with a simple aligned buffer
    var buffer: [2048]u8 align(16) = undefined;
    
    // Open a socket
    const sock = mdns.openMdnsSocketIpv4(0);
    if (sock < 0) {
        return -1;
    }
    
    // Try to receive without any callbacks - just test the alignment
    const mdns_lib = @cImport({
        @cInclude("mdns.h");
    });
    
    // Try calling mdns_discovery_recv with minimal params
    _ = mdns_lib.mdns_discovery_recv(sock, &buffer, buffer.len, null, null);
    
    mdns.closeMdnsSocket(sock);
    return 0;
}

// Get device information by index and type
export fn Java_com_example_flock_MainActivity_getDeviceInfo(
    env: ?*anyopaque,
    obj: ?*anyopaque,
    index: i32,
    info_type: i32,
) callconv(.c) ?[*:0]const u8 {
    _ = env;
    _ = obj;

    if (index < 0 or index >= device_cache.count) {
        return null;
    }

    const idx = @as(usize, @intCast(index));

    // Info type constants (from MainActivity):
    // INFO_NAME = 0, INFO_IP = 1, INFO_PORT = 2
    switch (info_type) {
        0 => { // NAME
            return &device_cache.names[idx];
        },
        1 => { // IP
            return &device_cache.ips[idx];
        },
        2 => { // PORT
            return &device_cache.ports[idx];
        },
        else => return null,
    }
}

// Stop discovery and clean up - full implementation
export fn Java_com_example_flock_MainActivity_stopDiscovery(
    env: ?*anyopaque,
    obj: ?*anyopaque,
) callconv(.c) void {
    _ = env;
    _ = obj;

    if (current_session_id == 0) {
        return;
    }

    // Stop the discovery session properly
    mdns.stopDiscovery(current_session_id) catch {
        // If the mdns cleanup fails, still try to close the socket manually
        mdns.closeMdnsSocket(@intCast(current_session_id));
    };

    current_session_id = 0;
    
    // Clear cache when stopping discovery - this prevents use-after-free
    device_cache.count = 0;
}
