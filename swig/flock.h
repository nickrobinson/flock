#ifndef FLOCK_H
#define FLOCK_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to discovery session
typedef struct MdnsDiscoverySession MdnsDiscoverySession;

/**
 * Create a new mDNS discovery session.
 * @return Session handle, or NULL on failure
 */
MdnsDiscoverySession* mdns_create_session(void);

/**
 * Start discovery by sending mDNS query.
 * @param session Session handle
 * @param service_type Service type to discover (e.g., "_http._tcp.local"), or NULL for all
 * @return 0 on success, negative on error
 */
int32_t mdns_start_discovery(MdnsDiscoverySession* session, const char* service_type);

/**
 * Receive discovery responses for specified timeout.
 * @param session Session handle
 * @param timeout_ms Timeout in milliseconds
 * @return Total number of discovered devices, or negative on error
 */
int32_t mdns_receive_responses(MdnsDiscoverySession* session, int32_t timeout_ms);

/**
 * Get the number of discovered devices.
 * @param session Session handle
 * @return Number of devices
 */
int32_t mdns_get_device_count(MdnsDiscoverySession* session);

/**
 * Get device name by index.
 * @param session Session handle
 * @param index Device index (0-based)
 * @return Device name, or NULL if invalid index
 */
const char* mdns_get_device_name(MdnsDiscoverySession* session, int32_t index);

/**
 * Get device IP address by index.
 * @param session Session handle
 * @param index Device index (0-based)
 * @return IP address string, or NULL if invalid index
 */
const char* mdns_get_device_ip(MdnsDiscoverySession* session, int32_t index);

/**
 * Get device port by index.
 * @param session Session handle
 * @param index Device index (0-based)
 * @return Port number, or 0 if invalid index
 */
int32_t mdns_get_device_port(MdnsDiscoverySession* session, int32_t index);

/**
 * Destroy discovery session and free all resources.
 * @param session Session handle
 */
void mdns_destroy_session(MdnsDiscoverySession* session);

// Test functions
int32_t mdns_test_socket(void);
int32_t mdns_test_discovery(void);

#ifdef __cplusplus
}
#endif

#endif // FLOCK_H
