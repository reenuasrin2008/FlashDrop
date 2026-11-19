package com.flashdrop.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.ConnectionsClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NearbyBridge(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.flashdrop.app/transport"
        const val EVENT_CHANNEL = "com.flashdrop.app/events"
        const val SERVICE_ID = "com.flashdrop.app.P2P_SERVICE"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null

    private val connectionsClient: ConnectionsClient = Nearby.getConnectionsClient(context)
    private val transferManager = TransferManager(context, connectionsClient, ::emitEvent)
    private val connectionManager = ConnectionManager(
        connectionsClient,
        transferManager.payloadCallback,
        ::emitEvent
    )
    private val discoveryManager = DiscoveryManager(
        context,
        connectionsClient,
        SERVICE_ID,
        ::emitEvent
    )
    private val wifiDirectManager = WifiDirectManager(context, ::emitEvent)

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val useWifiDirect = call.argument<Boolean>("enableWifiDirectFallback") ?: false
                if (useWifiDirect) {
                    wifiDirectManager.initialize()
                }
                result.success(discoveryManager.checkAdapters())
            }
            "checkAdapters" -> {
                result.success(discoveryManager.checkAdapters())
            }
            "startAdvertising" -> {
                val deviceName = call.argument<String>("deviceName") ?: "FlashDrop Android"
                discoveryManager.startAdvertising(
                    deviceName = deviceName,
                    connectionLifecycleCallback = connectionManager.connectionLifecycleCallback,
                    onSuccess = { result.success(true) },
                    onFailure = { e -> result.error("ADVERTISE_ERROR", e.message, null) }
                )
            }
            "stopAdvertising" -> {
                discoveryManager.stopAdvertising()
                result.success(true)
            }
            "startDiscovery" -> {
                val transport = call.argument<String>("transport") ?: "nearby"
                if (transport == "wifiDirect") {
                    wifiDirectManager.initialize()
                    wifiDirectManager.startDiscovery(
                        onSuccess = { result.success(true) },
                        onFailure = { e -> result.error("DISCOVERY_ERROR", e.message, null) }
                    )
                } else {
                    discoveryManager.startDiscovery(
                        onSuccess = { result.success(true) },
                        onFailure = { e -> result.error("DISCOVERY_ERROR", e.message, null) }
                    )
                }
            }
            "stopDiscovery" -> {
                discoveryManager.stopDiscovery()
                wifiDirectManager.stopDiscovery()
                result.success(true)
            }
            "requestConnection" -> {
                val deviceId = call.argument<String>("deviceId")
                val localDeviceName = call.argument<String>("localDeviceName") ?: "FlashDrop Android"
                val transport = call.argument<String>("transport") ?: "nearby"
                if (deviceId.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "deviceId is required", null)
                    return
                }
                if (transport == "wifiDirect") {
                    wifiDirectManager.connect(
                        deviceAddress = deviceId,
                        onSuccess = { result.success(true) },
                        onFailure = { e -> result.error("CONNECT_ERROR", e.message, null) }
                    )
                } else {
                    connectionManager.requestConnection(
                        localDeviceName = localDeviceName,
                        endpointId = deviceId,
                        onSuccess = { result.success(true) },
                        onFailure = { e -> result.error("CONNECT_ERROR", e.message, null) }
                    )
                }
            }
            "acceptConnection" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "deviceId is required", null)
                    return
                }
                connectionManager.acceptConnection(
                    endpointId = deviceId,
                    onSuccess = { result.success(true) },
                    onFailure = { e -> result.error("ACCEPT_ERROR", e.message, null) }
                )
            }
            "rejectConnection" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "deviceId is required", null)
                    return
                }
                connectionManager.rejectConnection(
                    endpointId = deviceId,
                    onSuccess = { result.success(true) },
                    onFailure = { e -> result.error("REJECT_ERROR", e.message, null) }
                )
            }
            "sendMetadata" -> {
                val deviceId = call.argument<String>("deviceId")
                val metadataJson = call.argument<String>("metadataJson")
                if (deviceId.isNullOrBlank() || metadataJson.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "deviceId and metadataJson are required", null)
                    return
                }
                transferManager.sendMetadata(
                    endpointId = deviceId,
                    metadataJson = metadataJson,
                    onSuccess = { result.success(true) },
                    onFailure = { e -> result.error("METADATA_ERROR", e.message, null) }
                )
            }
            "sendFile" -> {
                val deviceId = call.argument<String>("deviceId")
                val transferId = call.argument<String>("transferId")
                val filePath = call.argument<String>("filePath")
                val transport = call.argument<String>("transport") ?: "nearby"
                val metadataJson = call.argument<String>("metadataJson") ?: "{}"
                if (deviceId.isNullOrBlank() || transferId.isNullOrBlank() || filePath.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "deviceId, transferId, and filePath are required", null)
                    return
                }
                if (transport == "wifiDirect") {
                    wifiDirectManager.sendFileOverSocket(transferId, metadataJson, filePath)
                    result.success(true)
                } else {
                    transferManager.sendFile(
                        endpointId = deviceId,
                        transferId = transferId,
                        filePath = filePath,
                        onSuccess = { result.success(true) },
                        onFailure = { e -> result.error("SEND_FILE_ERROR", e.message, null) }
                    )
                }
            }
            "cancelTransfer" -> {
                val transferId = call.argument<String>("transferId")
                if (transferId.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "transferId is required", null)
                    return
                }
                transferManager.cancelTransfer(transferId) {
                    result.success(true)
                }
            }
            "disconnect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId.isNullOrBlank()) {
                    connectionManager.disconnectAll()
                } else {
                    connectionManager.disconnect(deviceId)
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        discoveryManager.clear()
        connectionManager.disconnectAll()
        transferManager.dispose()
        wifiDirectManager.dispose()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
