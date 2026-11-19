package com.flashdrop.app

import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.ConnectionsStatusCodes
import com.google.android.gms.nearby.connection.PayloadCallback
import java.util.concurrent.ConcurrentHashMap

class ConnectionManager(
    private val connectionsClient: ConnectionsClient,
    private val payloadCallback: PayloadCallback,
    private val emitEvent: (Map<String, Any?>) -> Unit
) {
    private val connectedEndpoints = ConcurrentHashMap<String, String>()
    private val pendingEndpoints = ConcurrentHashMap<String, ConnectionInfo>()

    val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, connectionInfo: ConnectionInfo) {
            // Never auto-accept: surface auth digits & peer name for explicit user approval
            pendingEndpoints[endpointId] = connectionInfo
            emitEvent(
                mapOf(
                    "type" to "connectionState",
                    "deviceId" to endpointId,
                    "deviceName" to connectionInfo.endpointName,
                    "status" to "authenticating",
                    "authToken" to connectionInfo.authenticationDigits,
                    "isIncoming" to connectionInfo.isIncomingConnection
                )
            )
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            val pending = pendingEndpoints.remove(endpointId)
            val peerName = pending?.endpointName ?: connectedEndpoints[endpointId] ?: "Unknown"
            when (result.status.statusCode) {
                ConnectionsStatusCodes.STATUS_OK -> {
                    connectedEndpoints[endpointId] = peerName
                    emitEvent(
                        mapOf(
                            "type" to "connectionState",
                            "deviceId" to endpointId,
                            "deviceName" to peerName,
                            "status" to "connected"
                        )
                    )
                }
                ConnectionsStatusCodes.STATUS_CONNECTION_REJECTED -> {
                    emitEvent(
                        mapOf(
                            "type" to "connectionState",
                            "deviceId" to endpointId,
                            "deviceName" to peerName,
                            "status" to "rejected",
                            "error" to "Connection rejected by peer"
                        )
                    )
                }
                else -> {
                    emitEvent(
                        mapOf(
                            "type" to "connectionState",
                            "deviceId" to endpointId,
                            "deviceName" to peerName,
                            "status" to "failed",
                            "error" to (result.status.statusMessage ?: "Connection failed (${result.status.statusCode})")
                        )
                    )
                }
            }
        }

        override fun onDisconnected(endpointId: String) {
            val peerName = connectedEndpoints.remove(endpointId) ?: "Peer"
            pendingEndpoints.remove(endpointId)
            emitEvent(
                mapOf(
                    "type" to "connectionState",
                    "deviceId" to endpointId,
                    "deviceName" to peerName,
                    "status" to "disconnected"
                )
            )
        }
    }

    fun requestConnection(
        localDeviceName: String,
        endpointId: String,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        connectionsClient.requestConnection(
            localDeviceName,
            endpointId,
            connectionLifecycleCallback
        ).addOnSuccessListener {
            emitEvent(
                mapOf(
                    "type" to "connectionState",
                    "deviceId" to endpointId,
                    "status" to "connecting"
                )
            )
            onSuccess()
        }.addOnFailureListener(onFailure)
    }

    fun acceptConnection(
        endpointId: String,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        connectionsClient.acceptConnection(endpointId, payloadCallback)
            .addOnSuccessListener { onSuccess() }
            .addOnFailureListener(onFailure)
    }

    fun rejectConnection(
        endpointId: String,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        pendingEndpoints.remove(endpointId)
        connectionsClient.rejectConnection(endpointId)
            .addOnSuccessListener {
                emitEvent(
                    mapOf(
                        "type" to "connectionState",
                        "deviceId" to endpointId,
                        "status" to "rejected"
                    )
                )
                onSuccess()
            }
            .addOnFailureListener(onFailure)
    }

    fun disconnect(endpointId: String) {
        connectedEndpoints.remove(endpointId)
        pendingEndpoints.remove(endpointId)
        connectionsClient.disconnectFromEndpoint(endpointId)
        emitEvent(
            mapOf(
                "type" to "connectionState",
                "deviceId" to endpointId,
                "status" to "disconnected"
            )
        )
    }

    fun disconnectAll() {
        connectionsClient.stopAllEndpoints()
        connectedEndpoints.clear()
        pendingEndpoints.clear()
    }
}
