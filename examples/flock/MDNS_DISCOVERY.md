# mDNS Discovery Implementation

This app now includes automatic mDNS discovery functionality that scans for devices on the local network.

## Features

- **Automatic Discovery**: Tap the "Discover Devices" button to scan for mDNS services
- **Device Information**: Displays device name, IP address, and port for each discovered device
- **Clean UI**: Modern Material 3 design with Jetpack Compose
- **Background Processing**: Discovery runs on background thread to keep UI responsive
- **Status Updates**: Real-time status messages during discovery process

## How to Use

1. Launch the app
2. Tap the "Discover Devices" button
3. Wait 5 seconds while the app scans the network
4. View the list of discovered devices

## Technical Implementation

### Native Methods
The app uses JNI to call native C++ mDNS implementation:
- `startDiscovery(serviceType)`: Starts mDNS discovery
- `getDiscoveredDevices(timeoutMs)`: Collects discovered devices
- `getDeviceInfo(index, infoType)`: Retrieves device details
- `stopDiscovery()`: Stops discovery and cleans up resources

### UI Components
- `MdnsDiscoveryScreen`: Main screen composable
- `DeviceCard`: Individual device display card
- `performMdnsDiscovery`: Coroutine-based discovery function

### Permissions Required
- `android.permission.INTERNET`
- `android.permission.ACCESS_WIFI_STATE`
- `android.permission.CHANGE_WIFI_MULTICAST_STATE`

## Customization

To discover specific service types instead of all services, modify the call to `startDiscovery()`:
```kotlin
// Discover HTTP services
val result = MainActivity.startDiscovery("_http._tcp.local.")

// Discover printer services
val result = MainActivity.startDiscovery("_ipp._tcp.local.")
```

## Notes

- Discovery timeout is set to 5 seconds by default
- The app automatically stops discovery after the timeout
- Devices are displayed as they are discovered
- Discovery runs on IO dispatcher to avoid blocking the UI thread