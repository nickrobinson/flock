const std = @import("std");
const builtin = @import("builtin");

const mdns = @cImport({
    @cInclude("mdns.h");
});

// Import necessary constants and types
const AF_INET = mdns.AF_INET;
const INADDR_ANY = mdns.INADDR_ANY;

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
    const service = "_services._dns-sd._udp.local.";

    const query_id = mdns.mdns_query_send(sock, query_type, service.ptr, service.len, &buffer, buffer.len, 0);

    return query_id;
}
