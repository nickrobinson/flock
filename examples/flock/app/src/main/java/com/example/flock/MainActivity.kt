package com.example.flock

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.flock.ui.theme.FlockTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext


// Data class to represent discovered devices
data class DeviceInfo(
    val name: String,
    val ipAddress: String,
    val port: String
)

class MainActivity : ComponentActivity() {
    companion object {
        init {
            System.loadLibrary("flock")
        }

        // Info type constants
        const val INFO_NAME = 0
        const val INFO_IP = 1
        const val INFO_PORT = 2

        // New mDNS discovery methods
        @JvmStatic
        external fun startDiscovery(serviceType: String?): Int

        @JvmStatic
        external fun getDiscoveredDevices(timeoutMs: Int): Int

        @JvmStatic
        external fun getDeviceInfo(index: Int, infoType: Int): String?

        @JvmStatic
        external fun stopDiscovery()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            FlockTheme {
                MdnsDiscoveryScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MdnsDiscoveryScreen() {
    var devices by remember { mutableStateOf(listOf<DeviceInfo>()) }
    var isDiscovering by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf("Ready to discover devices") }
    val coroutineScope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("mDNS Device Discovery") }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Status Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Text(
                    text = statusMessage,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyLarge
                )
            }

            // Discovery Button
            Button(
                onClick = {
                    if (!isDiscovering) {
                        performMdnsDiscovery(
                            coroutineScope = coroutineScope,
                            onStatusUpdate = { status -> statusMessage = status },
                            onDiscoveryStateChange = { discovering -> isDiscovering = discovering },
                            onDevicesFound = { foundDevices -> devices = foundDevices }
                        )
                    }
                },
                enabled = !isDiscovering,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Discover",
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(if (isDiscovering) "Discovering..." else "Discover Devices")
            }

            // Device List
            if (devices.isEmpty() && !isDiscovering) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 32.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    )
                ) {
                    Text(
                        text = "No devices discovered yet.\nTap 'Discover Devices' to start scanning.",
                        modifier = Modifier.padding(24.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(devices) { device ->
                        DeviceCard(device = device)
                    }
                }
            }

            // Progress Indicator
            if (isDiscovering) {
                CircularProgressIndicator(
                    modifier = Modifier.padding(top = 16.dp)
                )
            }
        }
    }
}

@Composable
fun DeviceCard(device: DeviceInfo) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = device.name,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${device.ipAddress}:${device.port}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

fun performMdnsDiscovery(
    coroutineScope: kotlinx.coroutines.CoroutineScope,
    onStatusUpdate: (String) -> Unit,
    onDiscoveryStateChange: (Boolean) -> Unit,
    onDevicesFound: (List<DeviceInfo>) -> Unit
) {
    coroutineScope.launch {
        onDiscoveryStateChange(true)
        onStatusUpdate("Starting discovery...")

        withContext(Dispatchers.IO) {
            try {
                // Start the discovery process
                val result = MainActivity.startDiscovery(null) // null uses default "_services._dns-sd._udp.local."

                if (result < 0) {
                    withContext(Dispatchers.Main) {
                        onStatusUpdate("Failed to start discovery: Error code $result")
                        onDiscoveryStateChange(false)
                    }
                    return@withContext
                }

                Log.d("mDNS", "Discovery started successfully")
                withContext(Dispatchers.Main) {
                    onStatusUpdate("Discovering devices for 5 seconds...")
                }

                // Wait and collect responses for 5 seconds
                val deviceCount = MainActivity.getDiscoveredDevices(5000)

                if (deviceCount < 0) {
                    withContext(Dispatchers.Main) {
                        onStatusUpdate("Error getting discovered devices: $deviceCount")
                    }
                } else {
                    Log.d("mDNS", "Found $deviceCount devices")

                    val foundDevices = mutableListOf<DeviceInfo>()

                    for (i in 0 until deviceCount) {
                        val name = MainActivity.getDeviceInfo(i, MainActivity.INFO_NAME)
                        val ip = MainActivity.getDeviceInfo(i, MainActivity.INFO_IP)
                        val port = MainActivity.getDeviceInfo(i, MainActivity.INFO_PORT)

                        if (name != null && ip != null && port != null) {
                            foundDevices.add(DeviceInfo(name, ip, port))
                        }
                    }

                    withContext(Dispatchers.Main) {
                        onDevicesFound(foundDevices)
                        onStatusUpdate("Found ${foundDevices.size} device(s)")
                    }
                }

            } catch (e: Exception) {
                Log.e("mDNS", "Discovery error", e)
                withContext(Dispatchers.Main) {
                    onStatusUpdate("Error during discovery: ${e.message}")
                }
            } finally {
                // Always stop discovery to clean up resources
                MainActivity.stopDiscovery()
                Log.d("mDNS", "Discovery stopped")
                withContext(Dispatchers.Main) {
                    onDiscoveryStateChange(false)
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun MdnsDiscoveryScreenPreview() {
    FlockTheme {
        MdnsDiscoveryScreen()
    }
}