package com.flashdrop.app

import android.content.Context
import android.os.ParcelFileDescriptor
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

class TransferManager(
    private val context: Context,
    private val connectionsClient: ConnectionsClient,
    private val emitEvent: (Map<String, Any?>) -> Unit
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // Maps transferId -> Nearby payloadId (for cancellation & progress mapping)
    private val transferToPayload = ConcurrentHashMap<String, Long>()
    private val payloadToTransfer = ConcurrentHashMap<Long, String>()

    // Incoming file staging: payloadId -> Payload
    private val incomingFilePayloads = ConcurrentHashMap<Long, Payload>()
    // Pending incoming metadata keyed by endpointId (FIFO queue for multi-file batches)
    private val pendingIncomingMetadata = ConcurrentHashMap<String, ConcurrentLinkedQueue<JSONObject>>()

    val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            when (payload.type) {
                Payload.Type.BYTES -> {
                    val bytes = payload.asBytes() ?: return
                    val jsonStr = String(bytes, Charsets.UTF_8)
                    handleIncomingControlMessage(endpointId, jsonStr)
                }
                Payload.Type.FILE -> {
                    incomingFilePayloads[payload.id] = payload
                    val meta = pendingIncomingMetadata[endpointId]?.peek()
                    val transferId = meta?.optString("transferId") ?: "payload_${payload.id}"
                    payloadToTransfer[payload.id] = transferId
                    transferToPayload[transferId] = payload.id
                    TransferForegroundService.start(
                        context,
                        "Receiving file",
                        meta?.optString("fileName") ?: "Incoming file",
                        0
                    )
                }
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            val transferId = payloadToTransfer[update.payloadId] ?: return
            val totalBytes = update.totalBytes
            val transferred = update.bytesTransferred
            val progressPct = if (totalBytes > 0) ((transferred * 100) / totalBytes).toInt() else 0

            when (update.status) {
                PayloadTransferUpdate.Status.IN_PROGRESS -> {
                    TransferForegroundService.update(
                        context,
                        "FlashDrop Transfer",
                        "$progressPct% complete",
                        progressPct
                    )
                    emitEvent(
                        mapOf(
                            "type" to "transferProgress",
                            "transferId" to transferId,
                            "deviceId" to endpointId,
                            "bytesTransferred" to transferred,
                            "totalBytes" to totalBytes,
                            "status" to "inProgress"
                        )
                    )
                }
                PayloadTransferUpdate.Status.SUCCESS -> {
                    val incomingPayload = incomingFilePayloads.remove(update.payloadId)
                    if (incomingPayload != null) {
                        val meta = pendingIncomingMetadata[endpointId]?.poll()
                        finalizeIncomingFile(endpointId, transferId, incomingPayload, meta)
                    } else {
                        TransferForegroundService.stop(context)
                        emitEvent(
                            mapOf(
                                "type" to "transferProgress",
                                "transferId" to transferId,
                                "deviceId" to endpointId,
                                "bytesTransferred" to totalBytes,
                                "totalBytes" to totalBytes,
                                "status" to "completed"
                            )
                        )
                    }
                    cleanupMapping(transferId, update.payloadId)
                }
                PayloadTransferUpdate.Status.FAILURE -> {
                    incomingFilePayloads.remove(update.payloadId)
                    TransferForegroundService.stop(context)
                    emitEvent(
                        mapOf(
                            "type" to "transferProgress",
                            "transferId" to transferId,
                            "deviceId" to endpointId,
                            "bytesTransferred" to transferred,
                            "totalBytes" to totalBytes,
                            "status" to "failed",
                            "error" to "Native payload transfer failed"
                        )
                    )
                    cleanupMapping(transferId, update.payloadId)
                }
                PayloadTransferUpdate.Status.CANCELED -> {
                    incomingFilePayloads.remove(update.payloadId)
                    TransferForegroundService.stop(context)
                    emitEvent(
                        mapOf(
                            "type" to "transferProgress",
                            "transferId" to transferId,
                            "deviceId" to endpointId,
                            "bytesTransferred" to transferred,
                            "totalBytes" to totalBytes,
                            "status" to "cancelled"
                        )
                    )
                    cleanupMapping(transferId, update.payloadId)
                }
            }
        }
    }

    private fun handleIncomingControlMessage(endpointId: String, jsonStr: String) {
        try {
            val json = JSONObject(jsonStr)
            val messageType = json.optString("messageType", "metadata")
            when (messageType) {
                "metadata" -> {
                    val transferId = json.optString("transferId")
                    val fileName = sanitizeFileName(json.optString("fileName"))
                    val fileSize = json.optLong("fileSize", -1L)
                    val checksum = json.optString("checksum")
                    if (transferId.isBlank() || fileName.isBlank() || fileSize < 0 || checksum.length != 64) {
                        emitEvent(
                            mapOf(
                                "type" to "transferError",
                                "deviceId" to endpointId,
                                "error" to "Rejected invalid incoming file metadata"
                            )
                        )
                        return
                    }
                    json.put("fileName", fileName)
                    pendingIncomingMetadata.computeIfAbsent(endpointId) { ConcurrentLinkedQueue() }.add(json)
                    emitEvent(
                        mapOf(
                            "type" to "incomingMetadata",
                            "deviceId" to endpointId,
                            "transferId" to transferId,
                            "fileName" to fileName,
                            "fileSize" to fileSize,
                            "mimeType" to json.optString("mimeType", "application/octet-stream"),
                            "checksum" to checksum,
                            "fileIndex" to json.optInt("fileIndex", 1),
                            "totalFiles" to json.optInt("totalFiles", 1)
                        )
                    )
                }
                "ack" -> {
                    emitEvent(
                        mapOf(
                            "type" to "transferAck",
                            "deviceId" to endpointId,
                            "transferId" to json.optString("transferId"),
                            "verified" to json.optBoolean("verified", false),
                            "error" to json.optString("error", "")
                        )
                    )
                }
            }
        } catch (e: Exception) {
            emitEvent(
                mapOf(
                    "type" to "transferError",
                    "deviceId" to endpointId,
                    "error" to "Malformed control message: ${e.message}"
                )
            )
        }
    }

    fun sendMetadata(
        endpointId: String,
        metadataJson: String,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        val payload = Payload.fromBytes(metadataJson.toByteArray(Charsets.UTF_8))
        connectionsClient.sendPayload(endpointId, payload)
            .addOnSuccessListener { onSuccess() }
            .addOnFailureListener(onFailure)
    }

    fun sendFile(
        endpointId: String,
        transferId: String,
        filePath: String,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        val file = File(filePath)
        if (!file.exists() || !file.canRead()) {
            onFailure(IllegalArgumentException("File does not exist or is unreadable: $filePath"))
            return
        }
        try {
            // Stream directly via ParcelFileDescriptor: zero full-file RAM buffering
            val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            val payload = Payload.fromFile(pfd)
            transferToPayload[transferId] = payload.id
            payloadToTransfer[payload.id] = transferId

            TransferForegroundService.start(context, "Sending file", file.name, 0)
            connectionsClient.sendPayload(endpointId, payload)
                .addOnSuccessListener { onSuccess() }
                .addOnFailureListener { e ->
                    cleanupMapping(transferId, payload.id)
                    TransferForegroundService.stop(context)
                    onFailure(e)
                }
        } catch (e: Exception) {
            onFailure(e)
        }
    }

    fun cancelTransfer(transferId: String, onComplete: () -> Unit) {
        val payloadId = transferToPayload.remove(transferId)
        if (payloadId != null) {
            payloadToTransfer.remove(payloadId)
            connectionsClient.cancelPayload(payloadId)
        }
        TransferForegroundService.stop(context)
        onComplete()
    }

    private fun finalizeIncomingFile(
        endpointId: String,
        transferId: String,
        payload: Payload,
        metadata: JSONObject?
    ) {
        scope.launch {
            var tempFile: File? = null
            try {
                val payloadFile = payload.asFile()
                    ?: throw IllegalStateException("Incoming payload missing file handle")
                val expectedName = sanitizeFileName(metadata?.optString("fileName") ?: "received_$transferId")
                val expectedSize = metadata?.optLong("fileSize", -1L) ?: -1L
                val expectedChecksum = metadata?.optString("checksum", "") ?: ""

                val stagingDir = File(context.cacheDir, "FlashDropTmp").apply { mkdirs() }
                tempFile = File(stagingDir, "${transferId}.part")

                // Copy with bounded 64KB buffer while computing SHA-256 in a single pass
                val digest = MessageDigest.getInstance("SHA-256")
                var totalCopied = 0L
                val buffer = ByteArray(64 * 1024)

                val pfd = payloadFile.asParcelFileDescriptor()
                    ?: throw IllegalStateException("Incoming payload missing ParcelFileDescriptor")
                ParcelFileDescriptor.AutoCloseInputStream(pfd).use { input ->
                    FileOutputStream(tempFile).use { output ->
                        while (true) {
                            val read = input.read(buffer)
                            if (read <= 0) break
                            digest.update(buffer, 0, read)
                            output.write(buffer, 0, read)
                            totalCopied += read
                        }
                        output.fd.sync()
                    }
                }

                val actualChecksum = digest.digest().joinToString("") { "%02x".format(it) }
                if (expectedSize >= 0 && totalCopied != expectedSize) {
                    throw SecurityException("Size mismatch: expected $expectedSize, received $totalCopied")
                }
                if (expectedChecksum.isNotEmpty() && !actualChecksum.equals(expectedChecksum, ignoreCase = true)) {
                    throw SecurityException("SHA-256 integrity mismatch")
                }

                val destDir = File(
                    context.getExternalFilesDir(null) ?: context.filesDir,
                    "FlashDrop"
                ).apply { mkdirs() }
                val finalFile = resolveUniqueFile(destDir, expectedName)

                if (!tempFile.renameTo(finalFile)) {
                    tempFile.copyTo(finalFile, overwrite = false)
                    tempFile.delete()
                }

                sendAck(endpointId, transferId, verified = true, error = "")
                TransferForegroundService.stop(context)

                emitEvent(
                    mapOf(
                        "type" to "incomingFileVerified",
                        "transferId" to transferId,
                        "deviceId" to endpointId,
                        "fileName" to finalFile.name,
                        "savedPath" to finalFile.absolutePath,
                        "fileSize" to totalCopied,
                        "checksum" to actualChecksum
                    )
                )
            } catch (e: Exception) {
                tempFile?.delete()
                sendAck(endpointId, transferId, verified = false, error = e.message ?: "Verification failed")
                TransferForegroundService.stop(context)
                emitEvent(
                    mapOf(
                        "type" to "transferProgress",
                        "transferId" to transferId,
                        "deviceId" to endpointId,
                        "bytesTransferred" to 0L,
                        "totalBytes" to 0L,
                        "status" to "failed",
                        "error" to (e.message ?: "Integrity verification failed")
                    )
                )
            }
        }
    }

    private fun sendAck(endpointId: String, transferId: String, verified: Boolean, error: String) {
        val ack = JSONObject().apply {
            put("messageType", "ack")
            put("transferId", transferId)
            put("verified", verified)
            put("error", error)
        }
        connectionsClient.sendPayload(
            endpointId,
            Payload.fromBytes(ack.toString().toByteArray(Charsets.UTF_8))
        )
    }

    private fun sanitizeFileName(raw: String): String {
        val base = raw.replace("\\", "/").substringAfterLast('/')
        val cleaned = base.replace(Regex("[\\x00-\\x1F\\x7F:*?\"<>|]"), "_").trim().trim('.')
        return if (cleaned.isEmpty()) "file_${System.currentTimeMillis()}" else cleaned
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

    private fun cleanupMapping(transferId: String, payloadId: Long) {
        transferToPayload.remove(transferId)
        payloadToTransfer.remove(payloadId)
    }

    fun dispose() {
        scope.cancel()
        TransferForegroundService.stop(context)
    }
}
