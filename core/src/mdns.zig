const std = @import("std");
const builtin = @import("builtin");

const mdns = @cImport({
    @cInclude("mdns.h");
});

// Import necessary constants and types
const AF_INET = mdns.AF_INET;
const INADDR_ANY = mdns.INADDR_ANY;

// Simplified session management - use a single global session for Android
var current_session: ?*DiscoverySession = null;
var session_counter: u32 = 1;

// Discovered device information
pub const DiscoveredDevice = struct {
    name: [:0]u8,
    ip_address: [:0]u8,
    port: u16,

    pub fn deinit(self: *DiscoveredDevice, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.ip_address);
    }
};

// Discovery session state
pub const DiscoverySession = struct {
    id: u32,
    socket: i32,
    devices: std.ArrayList(DiscoveredDevice),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, socket: i32) !*DiscoverySession {
        const session = try allocator.create(DiscoverySession);
        session.* = DiscoverySession{
            .id = session_counter,
            .socket = socket,
            .devices = std.ArrayList(DiscoveredDevice){},
            .allocator = allocator,
        };
        session_counter += 1;
        return session;
    }

    pub fn deinit(self: *DiscoverySession) void {
        // Clean up all devices
        for (self.devices.items) |*device| {
            device.deinit(self.allocator);
        }
        self.devices.deinit(self.allocator);

        // Close socket if still open
        if (self.socket >= 0) {
            mdns.mdns_socket_close(self.socket);
        }

        self.allocator.destroy(self);
    }
};

fn htons(value: u16) u16 {
    if (builtin.cpu.arch.endian() == .little) {
        return (@as(u16, value & 0xFF) << 8) | (@as(u16, value >> 8) & 0xFF);
    } else {
        return value;
    }
}

pub fn openMdnsSocketIpv4(port: u16) i32 {
    var addr: mdns.struct_sockaddr_in = undefined;

    // Zero out the struct
    @memset(@as([*]u8, @ptrCast(&addr))[0..@sizeOf(@TypeOf(addr))], 0);

    // Set up the address structure
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;

    // Open the socket
    const sock = mdns.mdns_socket_open_ipv4(&addr);
    if (sock >= 0) {
        // Setup the socket
        _ = mdns.mdns_socket_setup_ipv4(sock, &addr);
    }

    return sock;
}

pub fn closeMdnsSocket(sock: i32) void {
    mdns.mdns_socket_close(sock);
}

// Helper to send discovery query
pub fn sendMdnsDiscovery(sock: i32) i32 {
    var buffer: [2048]u8 = undefined;
    const query_type: u16 = mdns.MDNS_RECORDTYPE_PTR;
    const service = "_http-alt._tcp.local.";

    const query_id = mdns.mdns_query_send(sock, query_type, service.ptr, service.len, &buffer, buffer.len, 0);

    return query_id;
}

// Start a new discovery session (simplified)
pub fn startDiscovery(allocator: std.mem.Allocator, service_type: ?[]const u8) !u32 {
    _ = service_type; // Mark as used to avoid warning

    // Clean up any existing session
    if (current_session) |session| {
        session.deinit();
        current_session = null;
    }

    // Open socket on ephemeral port (0 = let system choose)
    const sock = openMdnsSocketIpv4(0);
    if (sock < 0) {
        return error.SocketOpenFailed;
    }

    // Create new session
    const session = try DiscoverySession.init(allocator, sock);
    const session_id = session.id;

    // Store session globally
    current_session = session;

    // Send discovery query
    const query_result = sendMdnsDiscovery(sock);
    if (query_result < 0) {
        // Clean up on failure
        session.deinit();
        current_session = null;
        return error.QuerySendFailed;
    }

    return session_id;
}

// mDNS record callback function for parsing responses
fn discoveryCallback(sock: c_int, from: [*c]const mdns.struct_sockaddr, addrlen: usize, entry: mdns.mdns_entry_type_t, query_id: u16, rtype: u16, rclass: u16, ttl: u32, data: ?*const anyopaque, size: usize, name_offset: usize, name_length: usize, record_offset: usize, record_length: usize, user_data: ?*anyopaque) callconv(.c) c_int {
    _ = sock;
    _ = from;
    _ = addrlen;
    _ = query_id;
    _ = rclass;
    _ = ttl;
    _ = name_offset;
    _ = name_length;

    const session_ptr = @as(*DiscoverySession, @ptrCast(@alignCast(user_data.?)));

    if (entry == mdns.MDNS_ENTRYTYPE_ANSWER and rtype == mdns.MDNS_RECORDTYPE_PTR) {
        // Parse PTR record to get service name
        var name_buffer: [256]u8 = undefined;
        const parsed_name = mdns.mdns_record_parse_ptr(data, size, record_offset, record_length, &name_buffer, name_buffer.len);

        if (parsed_name.length > 0) {
            // Create device entry - add null termination for C string compatibility
            const device_name = session_ptr.allocator.allocSentinel(u8, parsed_name.length, 0) catch return 0;
            @memcpy(device_name[0..parsed_name.length], parsed_name.str[0..parsed_name.length]);

            const device_ip = session_ptr.allocator.allocSentinel(u8, 7, 0) catch {
                session_ptr.allocator.free(device_name);
                return 0;
            };
            @memcpy(device_ip[0..7], "unknown");

            const device = DiscoveredDevice{
                .name = device_name,
                .ip_address = device_ip,
                .port = 0,
            };

            session_ptr.devices.append(session_ptr.allocator, device) catch return 0;
        }
    }

    return 0; // Continue processing
}

// List discovered devices for a session by checking for responses
pub fn listDiscoveredDevices(session_id: u32, timeout_ms: u32) !i32 {
    _ = session_id; // Use global session instead

    const session = current_session orelse return error.InvalidSessionId;

    var buffer: [2048]u8 = undefined;

    // Calculate end time
    const start_time = std.time.milliTimestamp();
    const end_time = start_time + @as(i64, timeout_ms);

    // Poll for responses within timeout
    var total_responses: usize = 0;
    while (std.time.milliTimestamp() < end_time) {
        const responses = mdns.mdns_discovery_recv(session.socket, &buffer, buffer.len, discoveryCallback, session);
        total_responses += responses;

        // Small delay to avoid busy waiting - use a simple counter instead of Thread.sleep
        var delay_counter: u32 = 0;
        while (delay_counter < 1000000000) { // Simple delay loop
            delay_counter += 1;
        }
    }

    return @intCast(session.devices.items.len);
}

// Get device count for a session
pub fn getDeviceCount(session_id: u32) !i32 {
    _ = session_id; // Use global session instead

    const session = current_session orelse return error.InvalidSessionId;
    return @intCast(session.devices.items.len);
}

// Get device name by index
pub fn getDeviceName(session_id: u32, device_index: usize) !?[]const u8 {
    _ = session_id; // Use global session instead

    const session = current_session orelse return error.InvalidSessionId;

    if (device_index >= session.devices.items.len) {
        return null;
    }

    return session.devices.items[device_index].name;
}

// Get device IP by index
pub fn getDeviceIp(session_id: u32, device_index: usize) !?[]const u8 {
    _ = session_id; // Use global session instead

    const session = current_session orelse return error.InvalidSessionId;

    if (device_index >= session.devices.items.len) {
        return null;
    }

    return session.devices.items[device_index].ip_address;
}

// Get device port by index
pub fn getDevicePort(session_id: u32, device_index: usize) !u16 {
    _ = session_id; // Use global session instead

    const session = current_session orelse return error.InvalidSessionId;

    if (device_index >= session.devices.items.len) {
        return 0;
    }

    return session.devices.items[device_index].port;
}

// Stop discovery session and clean up
pub fn stopDiscovery(session_id: u32) !void {
    _ = session_id; // Use global session instead

    if (current_session) |session| {
        session.deinit();
        current_session = null;
    }
}
