package com.flashdrop.app

import android.bluetooth.BluetoothManager
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Strategy
import java.util.concurrent.ConcurrentHashMap

class DiscoveryManager(
    private val context: Context,
    private val connectionsClient: ConnectionsClient,
    private val serviceId: String,
    private val emitEvent: (Map<String, Any?>) -> Unit
) {
    // P2P_POINT_TO_POINT automatically upgrades from BLE discovery to high-bandwidth Wi-Fi Direct / Wi-Fi Aware
    private val strategy = Strategy.P2P_POINT_TO_POINT
    private val discoveredEndpoints = ConcurrentHashMap<String, String>()
    private var isAdvertising = false
    private var isDiscovering = false

    fun checkAdapters(): Map<String, Any> {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothEnabled = bluetoothManager?.adapter?.isEnabled == true
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val wifiEnabled = wifiManager?.isWifiEnabled == true
        return mapOf(
            "bluetoothEnabled" to bluetoothEnabled,
            "wifiEnabled" to wifiEnabled,
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            "sdkInt" to Build.VERSION.SDK_INT
        )
    }

    fun startAdvertising(
        deviceName: String,
        connectionLifecycleCallback: com.google.android.gms.nearby.connection.ConnectionLifecycleCallback,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        if (isAdvertising) {
            onSuccess()
            return
        }
        val options = AdvertisingOptions.Builder()
            .setStrategy(strategy)
            .build()

        connectionsClient.startAdvertising(
            deviceName,
            serviceId,
            connectionLifecycleCallback,
            options
        ).addOnSuccessListener {
            isAdvertising = true
            emitEvent(mapOf("type" to "advertisingState", "active" to true))
            onSuccess()
        }.addOnFailureListener { e ->
            isAdvertising = false
            onFailure(e)
        }
    }

    fun stopAdvertising() {
        if (isAdvertising) {
            connectionsClient.stopAdvertising()
            isAdvertising = false
            emitEvent(mapOf("type" to "advertisingState", "active" to false))
        }
    }

    fun startDiscovery(
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        if (isDiscovering) {
            onSuccess()
            return
        }
        discoveredEndpoints.clear()
        val options = DiscoveryOptions.Builder()
            .setStrategy(strategy)
            .build()

        connectionsClient.startDiscovery(
            serviceId,
            endpointDiscoveryCallback,
            options
        ).addOnSuccessListener {
            isDiscovering = true
            emitEvent(mapOf("type" to "discoveryState", "active" to true))
            onSuccess()
        }.addOnFailureListener { e ->
            isDiscovering = false
            onFailure(e)
        }
    }

    fun stopDiscovery() {
        if (isDiscovering) {
            connectionsClient.stopDiscovery()
            isDiscovering = false
            emitEvent(mapOf("type" to "discoveryState", "active" to false))
        }
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            val previous = discoveredEndpoints.put(endpointId, info.endpointName)
            if (previous == info.endpointName) {
                // Filter duplicate emissions for unchanged endpoint
                return
            }
            emitEvent(
                mapOf(
                    "type" to "deviceFound",
                    "deviceId" to endpointId,
                    "deviceName" to info.endpointName,
                    "platform" to "android",
                    "transport" to "nearby"
                )
            )
        }

        override fun onEndpointLost(endpointId: String) {
            discoveredEndpoints.remove(endpointId)
            emitEvent(
                mapOf(
                    "type" to "deviceLost",
                    "deviceId" to endpointId
                )
            )
        }
    }

    fun clear() {
        stopAdvertising()
        stopDiscovery()
        discoveredEndpoints.clear()
    }
}
