package com.flashdrop.app

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest

/**
 * Optional Android-to-Android Wi-Fi Direct fallback transport.
 * Uses WifiP2pManager for discovery/group negotiation and a bounded-buffer
 * 64KB TCP socket stream with metadata validation and SHA-256 verification.
 */
class WifiDirectManager(
    private val context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit
) {
    companion object {
        private const val TRANSFER_PORT = 48921
        private const val BUFFER_SIZE = 64 * 1024
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val manager: WifiP2pManager? =
        context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private var channel: WifiP2pManager.Channel? = null
    private var receiverRegistered = false
    private var groupOwnerAddress: InetAddress? = null
    private var serverSocket: ServerSocket? = null

    fun initialize(): Boolean {
        val mgr = manager ?: return false
        if (channel == null) {
            channel = mgr.initialize(context, Looper.getMainLooper(), null)
        }
        if (!receiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(p2pReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(p2pReceiver, filter)
            }
            receiverRegistered = true
        }
        return channel != null
    }

    @SuppressLint("MissingPermission")
    fun startDiscovery(onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        val mgr = manager ?: return onFailure(IllegalStateException("Wi-Fi Direct unavailable"))
        val ch = channel ?: return onFailure(IllegalStateException("Wi-Fi Direct not initialized"))
        mgr.discoverPeers(ch, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                emitEvent(mapOf("type" to "discoveryState", "active" to true))
                onSuccess()
            }

            override fun onFailure(reason: Int) {
                onFailure(IllegalStateException("Wi-Fi Direct discovery failed (code=$reason)"))
            }
        })
    }

    fun stopDiscovery() {
        val mgr = manager ?: return
        val ch = channel ?: return
        mgr.stopPeerDiscovery(ch, null)
        emitEvent(mapOf("type" to "discoveryState", "active" to false))
    }

    @SuppressLint("MissingPermission")
    fun connect(deviceAddress: String, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        val mgr = manager ?: return onFailure(IllegalStateException("Wi-Fi Direct unavailable"))
        val ch = channel ?: return onFailure(IllegalStateException("Wi-Fi Direct not initialized"))
        val config = WifiP2pConfig().apply {
            this.deviceAddress = deviceAddress
        }
        mgr.connect(ch, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = onSuccess()
            override fun onFailure(reason: Int) =
                onFailure(IllegalStateException("Wi-Fi Direct connect failed (code=$reason)"))
        })
    }

    fun sendFileOverSocket(transferId: String, metadataJson: String, filePath: String) {
        val targetHost = groupOwnerAddress ?: run {
            emitEvent(
                mapOf(
                    "type" to "transferProgress",
                    "transferId" to transferId,
                    "bytesTransferred" to 0L,
                    "totalBytes" to 0L,
                    "status" to "failed",
                    "error" to "Wi-Fi Direct peer address not established"
                )
            )
            return
        }
        scope.launch {
            val file = File(filePath)
            val totalSize = file.length()
            try {
                Socket(targetHost, TRANSFER_PORT).use { socket ->
                    socket.soTimeout = 30_000
                    val out = DataOutputStream(BufferedOutputStream(socket.getOutputStream(), BUFFER_SIZE))
                    val metaBytes = metadataJson.toByteArray(Charsets.UTF_8)
                    out.writeInt(metaBytes.size)
                    out.write(metaBytes)

                    val buffer = ByteArray(BUFFER_SIZE)
                    var sent = 0L
                    FileInputStream(file).use { input ->
                        while (true) {
                            val read = input.read(buffer)
                            if (read <= 0) break
                            out.write(buffer, 0, read)
                            sent += read
                            emitEvent(
                                mapOf(
                                    "type" to "transferProgress",
                                    "transferId" to transferId,
                                    "bytesTransferred" to sent,
                                    "totalBytes" to totalSize,
                                    "status" to "inProgress"
                                )
                            )
                        }
                    }
                    out.flush()
                    emitEvent(
                        mapOf(
                            "type" to "transferProgress",
                            "transferId" to transferId,
                            "bytesTransferred" to totalSize,
                            "totalBytes" to totalSize,
                            "status" to "completed"
                        )
                    )
                }
            } catch (e: Exception) {
                emitEvent(
                    mapOf(
                        "type" to "transferProgress",
                        "transferId" to transferId,
                        "bytesTransferred" to 0L,
                        "totalBytes" to totalSize,
                        "status" to "failed",
                        "error" to (e.message ?: "Wi-Fi Direct socket error")
                    )
                )
            }
        }
    }

    private fun startReceiveServer() {
        if (serverSocket != null) return
        scope.launch {
            try {
                val server = ServerSocket(TRANSFER_PORT)
                serverSocket = server
                while (!server.isClosed) {
                    val client = server.accept()
                    handleIncomingSocket(client)
                }
            } catch (_: Exception) {
                // Socket closed on dispose
            }
        }
    }

    private fun handleIncomingSocket(socket: Socket) {
        var tempFile: File? = null
        try {
            socket.use { s ->
                s.soTimeout = 30_000
                val input = DataInputStream(BufferedInputStream(s.getInputStream(), BUFFER_SIZE))
                val metaLen = input.readInt()
                if (metaLen <= 0 || metaLen > 65536) {
                    throw SecurityException("Invalid metadata header length")
                }
                val metaBytes = ByteArray(metaLen)
                input.readFully(metaBytes)
                val meta = JSONObject(String(metaBytes, Charsets.UTF_8))
                val transferId = meta.getString("transferId")
                val rawName = meta.getString("fileName")
                val fileSize = meta.getLong("fileSize")
                val expectedChecksum = meta.getString("checksum")
                val safeName = rawName.replace("\\", "/").substringAfterLast('/')
                    .replace(Regex("[\\x00-\\x1F\\x7F:*?\"<>|]"), "_").trim().trim('.')

                val stagingDir = File(context.cacheDir, "FlashDropTmp").apply { mkdirs() }
                tempFile = File(stagingDir, "$transferId.part")
                val digest = MessageDigest.getInstance("SHA-256")
                val buffer = ByteArray(BUFFER_SIZE)
                var remaining = fileSize
                var received = 0L

                FileOutputStream(tempFile).use { out ->
                    while (remaining > 0) {
                        val toRead = minOf(buffer.size.toLong(), remaining).toInt()
                        val read = input.read(buffer, 0, toRead)
                        if (read <= 0) throw IllegalStateException("Unexpected EOF during transfer")
                        digest.update(buffer, 0, read)
                        out.write(buffer, 0, read)
                        remaining -= read
                        received += read
                        emitEvent(
                            mapOf(
                                "type" to "transferProgress",
                                "transferId" to transferId,
                                "bytesTransferred" to received,
                                "totalBytes" to fileSize,
                                "status" to "inProgress"
                            )
                        )
                    }
                }

                val actualChecksum = digest.digest().joinToString("") { "%02x".format(it) }
                if (!actualChecksum.equals(expectedChecksum, ignoreCase = true)) {
                    throw SecurityException("SHA-256 checksum mismatch")
                }

                val destDir = File(context.getExternalFilesDir(null) ?: context.filesDir, "FlashDrop")
                    .apply { mkdirs() }
                val finalFile = resolveUniqueFile(destDir, safeName.ifEmpty { "received_$transferId" })
                if (tempFile?.renameTo(finalFile) != true) {
                    tempFile?.copyTo(finalFile, overwrite = false)
                    tempFile?.delete()
                }
                emitEvent(
                    mapOf(
                        "type" to "incomingFileVerified",
                        "transferId" to transferId,
                        "fileName" to finalFile.name,
                        "savedPath" to finalFile.absolutePath,
                        "fileSize" to received,
                        "checksum" to actualChecksum
                    )
                )
            }
        } catch (e: Exception) {
            tempFile?.delete()
            emitEvent(
                mapOf(
                    "type" to "transferError",
                    "error" to (e.message ?: "Wi-Fi Direct receive failed")
                )
            )
        }
    }

    private val p2pReceiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context, intent: Intent) {
            val mgr = manager ?: return
            val ch = channel ?: return
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                    mgr.requestPeers(ch) { peerList ->
                        for (device: WifiP2pDevice in peerList.deviceList) {
                            emitEvent(
                                mapOf(
                                    "type" to "deviceFound",
                                    "deviceId" to device.deviceAddress,
                                    "deviceName" to device.deviceName,
                                    "platform" to "android",
                                    "transport" to "wifiDirect"
                                )
                            )
                        }
                    }
                }
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    mgr.requestConnectionInfo(ch) { info ->
                        if (info.groupFormed) {
                            groupOwnerAddress = info.groupOwnerAddress
                            if (info.isGroupOwner) {
                                startReceiveServer()
                            }
                            emitEvent(
                                mapOf(
                                    "type" to "connectionState",
                                    "deviceId" to (info.groupOwnerAddress?.hostAddress ?: "wifi_direct"),
                                    "status" to "connected"
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private fun resolveUniqueFile(dir: File, fileName: String): File {
        var candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate
        val dotIndex = fileName.lastIndexOf('.')
        val stem = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val ext = if (dotIndex > 0) fileName.substring(dotIndex) else ""
        var counter = 1
        while (candidate.exists()) {
            candidate = File(dir, "${stem}_($counter)$ext")
            counter++
        }
        return candidate
    }

    fun dispose() {
        try {
            serverSocket?.close()
        } catch (_: Exception) {}
        serverSocket = null
        if (receiverRegistered) {
            try {
                context.unregisterReceiver(p2pReceiver)
            } catch (_: Exception) {}
            receiverRegistered = false
        }
        scope.cancel()
    }
}
