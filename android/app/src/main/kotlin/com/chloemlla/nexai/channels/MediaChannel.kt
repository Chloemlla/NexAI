package com.chloemlla.nexai.channels

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import com.chloemlla.nexai.background.NativeTaskStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

class MediaChannel(
    private val context: Context,
    private val taskStore: NativeTaskStore,
    private val events: NativeTaskEvents,
) : MethodChannel.MethodCallHandler {
    private val cancelledTasks = ConcurrentHashMap.newKeySet<String>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVideoMetadata" -> {
                val source = call.argument<String>("uri")
                    ?: call.argument<String>("path")
                    ?: return result.success(NativeResult.invalidArgument("uri or path is required"))
                result.success(runCatching {
                    NativeResult.ok(readMetadata(source))
                }.getOrElse {
                    NativeResult.nativeFailure("Failed to read media metadata")
                })
            }
            "startAudioExtraction" -> startAudioExtraction(call, result)
            "startVideoCompression" -> result.success(
                NativeResult.nativeFailure(
                    "Native video compression facade is registered, but no Android transcoder is bundled. Keep existing Flutter compressor until a native transcoder is added.",
                ),
            )
            "cancelTask" -> {
                val taskId = call.argument<String>("taskId")
                    ?: return result.success(NativeResult.invalidArgument("taskId is required"))
                cancelledTasks.add(taskId)
                taskStore.updateStatus(taskId, "cancelled", "cancel requested")
                emit(taskId, "cancelled", 0.0, "cancel requested")
                result.success(NativeResult.ok(mapOf("taskId" to taskId, "status" to "cancelled")))
            }
            "getTaskStatus" -> {
                val taskId = call.argument<String>("taskId")
                    ?: return result.success(NativeResult.invalidArgument("taskId is required"))
                result.success(
                    taskStore.get(taskId)?.let { NativeResult.ok(it) }
                        ?: NativeResult.error("task_not_found", "Task not found"),
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun readMetadata(source: String): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            setRetrieverSource(retriever, source)
            return mapOf(
                "durationMs" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull(),
                "width" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull(),
                "height" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull(),
                "bitrate" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull(),
                "rotation" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull(),
                "mimeType" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE),
                "hasAudio" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes"),
                "hasVideo" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"),
                "source" to source,
                "checkedAt" to System.currentTimeMillis(),
            )
        } finally {
            retriever.release()
        }
    }

    private fun startAudioExtraction(call: MethodCall, result: MethodChannel.Result) {
        val source = call.argument<String>("uri")
            ?: call.argument<String>("path")
            ?: return result.success(NativeResult.invalidArgument("uri or path is required"))
        val format = call.argument<String>("format") ?: "m4a"
        if (format.lowercase() !in setOf("m4a", "aac")) {
            return result.success(
                NativeResult.error(
                    "unsupported_android_version",
                    "Android system API only supports muxing existing AAC audio to M4A; MP3 requires FFmpeg-class native capability.",
                ),
            )
        }

        val taskId = call.argument<String>("taskId") ?: "media-audio-${UUID.randomUUID()}"
        val output = File(context.cacheDir, "$taskId.m4a")
        val task = mapOf(
            "taskId" to taskId,
            "type" to "audioExtraction",
            "status" to "queued",
            "source" to source,
            "outputUri" to Uri.fromFile(output).toString(),
            "createdAt" to System.currentTimeMillis(),
            "updatedAt" to System.currentTimeMillis(),
        )
        taskStore.put(task)
        emit(taskId, "started", 0.0, "queued")
        result.success(NativeResult.ok(task))

        thread(name = "nexai-audio-extract-$taskId") {
            extractAudio(taskId, source, output)
        }
    }

    private fun extractAudio(taskId: String, source: String, output: File) {
        taskStore.updateStatus(taskId, "running", "extracting")
        emit(taskId, "progress", 0.02, "extracting")
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        try {
            setExtractorSource(extractor, source)
            val trackIndex = findAudioTrack(extractor)
            if (trackIndex < 0) {
                failTask(taskId, output, "native_failure", "No audio track found")
                return
            }

            val inputFormat = extractor.getTrackFormat(trackIndex)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME) ?: ""
            if (!mime.equals("audio/mp4a-latm", ignoreCase = true)) {
                failTask(taskId, output, "native_failure", "Only AAC audio tracks can be muxed by Android system API")
                return
            }

            extractor.selectTrack(trackIndex)
            muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val outputTrack = muxer.addTrack(inputFormat)
            muxer.start()

            val durationUs = if (inputFormat.containsKey(MediaFormat.KEY_DURATION)) {
                inputFormat.getLong(MediaFormat.KEY_DURATION).coerceAtLeast(1L)
            } else {
                1L
            }
            val bufferSize = if (inputFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                inputFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(256 * 1024)
            } else {
                256 * 1024
            }
            val buffer = ByteBuffer.allocate(bufferSize)
            val bufferInfo = android.media.MediaCodec.BufferInfo()

            while (!cancelledTasks.contains(taskId)) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break
                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(outputTrack, buffer, bufferInfo)

                val progress = (bufferInfo.presentationTimeUs.toDouble() / durationUs)
                    .coerceIn(0.0, 0.98)
                taskStore.put(
                    mapOf(
                        "taskId" to taskId,
                        "type" to "audioExtraction",
                        "status" to "running",
                        "progress" to progress,
                        "outputUri" to Uri.fromFile(output).toString(),
                        "updatedAt" to System.currentTimeMillis(),
                    ),
                )
                emit(taskId, "progress", progress, "extracting")
                extractor.advance()
            }

            if (cancelledTasks.remove(taskId)) {
                output.delete()
                taskStore.updateStatus(taskId, "cancelled", "cancelled")
                emit(taskId, "cancelled", 0.0, "cancelled")
                return
            }

            val completed = mapOf(
                "taskId" to taskId,
                "type" to "audioExtraction",
                "status" to "succeeded",
                "progress" to 1.0,
                "outputUri" to Uri.fromFile(output).toString(),
                "outputBytes" to output.length(),
                "updatedAt" to System.currentTimeMillis(),
            )
            taskStore.put(completed)
            emit(taskId, "completed", 1.0, "completed", completed)
        } catch (e: Exception) {
            failTask(taskId, output, "native_failure", "Audio extraction failed")
        } finally {
            runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            extractor.release()
        }
    }

    private fun findAudioTrack(extractor: MediaExtractor): Int {
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) return index
        }
        return -1
    }

    private fun setRetrieverSource(retriever: MediaMetadataRetriever, source: String) {
        if (source.startsWith("content://")) {
            retriever.setDataSource(context, Uri.parse(source))
        } else {
            retriever.setDataSource(source.removePrefix("file://"))
        }
    }

    private fun setExtractorSource(extractor: MediaExtractor, source: String) {
        if (source.startsWith("content://")) {
            extractor.setDataSource(context, Uri.parse(source), null)
        } else {
            extractor.setDataSource(source.removePrefix("file://"))
        }
    }

    private fun failTask(taskId: String, output: File, code: String, message: String) {
        output.delete()
        val failed = mapOf(
            "taskId" to taskId,
            "status" to "failed",
            "error" to mapOf(
                "code" to code,
                "message" to message,
                "recoverable" to true,
            ),
            "updatedAt" to System.currentTimeMillis(),
        )
        taskStore.put(failed)
        emit(taskId, "failed", 0.0, message, failed)
    }

    private fun emit(
        taskId: String,
        type: String,
        progress: Double,
        message: String,
        payload: Map<String, Any?> = emptyMap(),
    ) {
        events.emit(
            mapOf(
                "taskId" to taskId,
                "type" to type,
                "progress" to progress,
                "message" to message,
                "payload" to payload,
            ),
        )
    }
}
