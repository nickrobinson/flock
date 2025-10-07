// mdns_wrapper.c
#define MDNS_IMPLEMENTATION
#include <string.h>
#include "../vendor/mdns/mdns.h"
#include "../vendor/mdns/mdns.c"

int mdns_wrapper_socket_open_ipv4(unsigned short port) {
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    int sock = mdns_socket_open_ipv4(&addr);
    if (sock >= 0) {
        // mdns_socket_setup_ipv4 only takes 2 params: sock and bind address
        mdns_socket_setup_ipv4(sock, &addr);
    }
    return sock;
}

int mdns_wrapper_socket_open_ipv6(unsigned short port) {
    struct sockaddr_in6 addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin6_family = AF_INET6;
    addr.sin6_port = htons(port);
    addr.sin6_addr = in6addr_any;
    return mdns_socket_open_ipv6(&addr);  // Pass address of struct
}

void mdns_wrapper_socket_close(int sock) {
    mdns_socket_close(sock);
}

// Simple test function
int mdns_wrapper_test(void) {
    // Just return 42 to verify linking works
    return 42;
}

int mdns_wrapper_send_discovery(int sock) {
    if (sock < 0) return -1000;
    
    // Create proper buffers
    uint8_t query_buffer[1024];
    
    // Build the query using mdns_query_send
    const char* service = "_http-alt._tcp.local";
    
    // mdns_query_send returns the size of the query built
    size_t query_size = mdns_query_send(sock, MDNS_RECORDTYPE_PTR,
                                        service, strlen(service),
                                        query_buffer, sizeof(query_buffer), 0);
    
    // If query_size is > 0, the query was built successfully
    if (query_size > 0) {
        // Now actually send it to the multicast address
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(5353);
        // Use the hex value for 224.0.0.251 to avoid inet_addr
        addr.sin_addr.s_addr = htonl(0xE00000FB); // 224.0.0.251 in hex
        
        ssize_t sent = sendto(sock, query_buffer, query_size, 0,
                             (struct sockaddr*)&addr, sizeof(addr));
        
        if (sent > 0) {
            return (int)sent;  // Return bytes sent
        } else {
            return -2000 - errno;  // -2000-x range for send errors
        }
    }
    
    return -3000 - (int)query_size;  // -3000-x range for query build errors
}

int mdns_wrapper_receive(int sock, int timeout_ms) {
    uint8_t buffer[2048];
    size_t responses = 0;
    
    // This would receive and count responses
    // You'd need to implement proper timeout handling
    // For now, just return 0 to indicate function exists
    return 0;
}
