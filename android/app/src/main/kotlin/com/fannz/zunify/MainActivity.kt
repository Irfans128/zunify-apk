package com.fannz.zunify

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

/**
 * Zunify MainActivity - Crafted with ❤️ by Fannz
 * Bridges Flutter audioSessionId directly to Android's hardware DSP Equalizer,
 * BassBoost, Virtualizer, Network Type Detector, Story MP4 Video+Audio Muxer,
 * and native APK update installer.
 */
class MainActivity : AudioServiceFragmentActivity() {
    private val CHANNEL = "com.fannz.zunify/equalizer"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId: Int = -1
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initAudioEffects" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        initEffects(sessionId, enabled)
                        result.success(getEqualizerInfo())
                    } catch (e: Exception) {
                        result.error("EQ_INIT_ERR", e.message, null)
                    }
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    equalizer?.enabled = enabled
                    bassBoost?.enabled = enabled
                    virtualizer?.enabled = enabled
                    result.success(true)
                }
                "setBandLevel" -> {
                    val band: Short = (call.argument<Int>("band") ?: 0).toShort()
                    val level: Short = (call.argument<Int>("level") ?: 0).toShort()
                    try {
                        equalizer?.setBandLevel(band, level)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EQ_BAND_ERR", e.message, null)
                    }
                }
                "setBassBoost" -> {
                    val strength: Short = (call.argument<Int>("strength") ?: 0).coerceIn(0, 1000).toShort()
                    try {
                        if (bassBoost?.strengthSupported == true) {
                            bassBoost?.setStrength(strength)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BASS_ERR", e.message, null)
                    }
                }
                "setVirtualizer" -> {
                    val strength: Short = (call.argument<Int>("strength") ?: 0).coerceIn(0, 1000).toShort()
                    try {
                        if (virtualizer?.strengthSupported == true) {
                            virtualizer?.setStrength(strength)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VIRT_ERR", e.message, null)
                    }
                }
                "getNetworkType" -> {
                    result.success(detectNetworkType())
                }
                "createStoryVideo" -> {
                    val imagePath = call.argument<String>("imagePath") ?: ""
                    val audioPath = call.argument<String>("audioPath") ?: ""
                    val outputPath = call.argument<String>("outputPath") ?: ""
                    val startMs = (call.argument<Number>("startMs")?.toLong() ?: 0L).coerceAtLeast(0L)
                    val durationMs = (call.argument<Number>("durationMs")?.toLong() ?: 20000L).coerceIn(5000L, 30000L)

                    Thread {
                        try {
                            val ok = muxImageAndAudioToMp4(
                                imagePath = imagePath,
                                audioPath = audioPath,
                                outputPath = outputPath,
                                startMs = startMs,
                                durationMs = durationMs
                            )
                            mainHandler.post {
                                if (ok) {
                                    result.success(outputPath)
                                } else {
                                    result.error("MUX_FAIL", "Could not generate story MP4", null)
                                }
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("MUX_ERR", e.message ?: "Unknown mux error", null)
                            }
                        }
                    }.start()
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        try {
                            val file = File(filePath)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun detectNetworkType(): String {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return "wifi"
            val net = cm.activeNetwork ?: return "none"
            val caps = cm.getNetworkCapabilities(net) ?: return "wifi"
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                else -> "wifi"
            }
        } catch (_: Exception) {
            "wifi"
        }
    }

    /**
     * Generates a 720x1280 9:16 vertical H.264 + AAC `.mp4` story video
     * combining the rendered Lyric Card PNG with the exact song audio slice.
     */
    private fun muxImageAndAudioToMp4(
        imagePath: String,
        audioPath: String,
        outputPath: String,
        startMs: Long,
        durationMs: Long
    ): Boolean {
        val rawBmp = BitmapFactory.decodeFile(imagePath) ?: return false
        val width = 720
        val height = 1280

        // Center card inside a 720x1280 9:16 story canvas
        val canvasBmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(canvasBmp)
        canvas.drawColor(Color.parseColor("#080B12"))

        val padH = 36f
        val maxW = width - padH * 2f
        val maxH = height - 140f
        val scale = minOf(maxW / rawBmp.width.toFloat(), maxH / rawBmp.height.toFloat())
        val drawW = rawBmp.width * scale
        val drawH = rawBmp.height * scale
        val left = (width - drawW) / 2f
        val top = (height - drawH) / 2f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(rawBmp, null, RectF(left, top, left + drawW, top + drawH), paint)
        rawBmp.recycle()

        // Precompute Y, U, V planes (BT.601) once for the static 720x1280 frame
        val argb = IntArray(width * height)
        canvasBmp.getPixels(argb, 0, width, 0, 0, width, height)
        canvasBmp.recycle()

        val yPlane = ByteArray(width * height)
        val uPlane = ByteArray((width / 2) * (height / 2))
        val vPlane = ByteArray((width / 2) * (height / 2))

        var yIdx = 0
        var uvIdx = 0
        for (j in 0 until height) {
            for (i in 0 until width) {
                val c = argb[yIdx]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF

                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yPlane[yIdx++] = y.coerceIn(0, 255).toByte()

                if (j % 2 == 0 && i % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    uPlane[uvIdx] = u.coerceIn(0, 255).toByte()
                    vPlane[uvIdx] = v.coerceIn(0, 255).toByte()
                    uvIdx++
                }
            }
        }

        val outFile = File(outputPath)
        if (outFile.exists()) outFile.delete()

        val extractor = MediaExtractor()
        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null
        try {
            extractor.setDataSource(audioPath)
            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = fmt
                    extractor.selectTrack(i)
                    break
                }
            }
        } catch (_: Exception) {}

        val fps = 5
        val totalFrames = ((durationMs / 1000.0) * fps).toInt().coerceAtLeast(25)
        val frameDurationUs = 1_000_000L / fps

        val videoFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, 1_500_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var muxerVideoTrack = -1
        var muxerAudioTrack = -1
        var muxerStarted = false

        val bufferInfo = MediaCodec.BufferInfo()
        var frameIdx = 0
        var inputDone = false
        var outputDone = false

        while (!outputDone) {
            if (!inputDone) {
                val inIdx = encoder.dequeueInputBuffer(10_000)
                if (inIdx >= 0) {
                    if (frameIdx >= totalFrames) {
                        encoder.queueInputBuffer(
                            inIdx,
                            0,
                            0,
                            frameIdx * frameDurationUs,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        inputDone = true
                    } else {
                        val img = encoder.getInputImage(inIdx)
                        if (img != null) {
                            fillYuvImage(img, width, height, yPlane, uPlane, vPlane)
                            encoder.queueInputBuffer(
                                inIdx,
                                0,
                                (width * height * 3) / 2,
                                frameIdx * frameDurationUs,
                                0
                            )
                        } else {
                            val buf = encoder.getInputBuffer(inIdx)
                            buf?.clear()
                            buf?.put(yPlane)
                            buf?.put(uPlane)
                            buf?.put(vPlane)
                            encoder.queueInputBuffer(
                                inIdx,
                                0,
                                yPlane.size + uPlane.size + vPlane.size,
                                frameIdx * frameDurationUs,
                                0
                            )
                        }
                        frameIdx++
                    }
                }
            }

            val outIdx = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    muxerVideoTrack = muxer.addTrack(encoder.outputFormat)
                    if (audioFormat != null && audioTrackIndex >= 0) {
                        try {
                            muxerAudioTrack = muxer.addTrack(audioFormat)
                        } catch (_: Exception) {
                            muxerAudioTrack = -1
                        }
                    }
                    muxer.start()
                    muxerStarted = true
                }
                outIdx >= 0 -> {
                    val encodedData = encoder.getOutputBuffer(outIdx)
                    if (encodedData != null && bufferInfo.size > 0 && muxerStarted &&
                        (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                    ) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(muxerVideoTrack, encodedData, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outIdx, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
        }

        // Copy AAC audio stream slice from startMs for durationMs
        if (muxerStarted && muxerAudioTrack >= 0 && audioTrackIndex >= 0) {
            try {
                val startUs = startMs * 1000L
                val maxDurationUs = durationMs * 1000L
                extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                val firstSampleUs = extractor.sampleTime.coerceAtLeast(0L)
                val audioBuf = ByteBuffer.allocate(256 * 1024)
                val audioInfo = MediaCodec.BufferInfo()

                while (true) {
                    audioBuf.clear()
                    val sampleSize = extractor.readSampleData(audioBuf, 0)
                    if (sampleSize < 0) break
                    val sampleTimeUs = extractor.sampleTime
                    val relUs = (sampleTimeUs - firstSampleUs).coerceAtLeast(0L)
                    if (relUs > maxDurationUs) break

                    audioInfo.offset = 0
                    audioInfo.size = sampleSize
                    audioInfo.presentationTimeUs = relUs
                    audioInfo.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxerAudioTrack, audioBuf, audioInfo)
                    if (!extractor.advance()) break
                }
            } catch (_: Exception) {}
        }

        try {
            extractor.release()
        } catch (_: Exception) {}
        try {
            encoder.stop()
            encoder.release()
        } catch (_: Exception) {}
        try {
            if (muxerStarted) muxer.stop()
            muxer.release()
        } catch (_: Exception) {}

        return outFile.exists() && outFile.length() > 1024
    }

    private fun fillYuvImage(
        img: android.media.Image,
        width: Int,
        height: Int,
        yPlane: ByteArray,
        uPlane: ByteArray,
        vPlane: ByteArray
    ) {
        val planes = img.planes
        // Y Plane
        val yBuf = planes[0].buffer
        val yRowStride = planes[0].rowStride
        if (yRowStride == width) {
            yBuf.put(yPlane, 0, width * height)
        } else {
            for (row in 0 until height) {
                yBuf.position(row * yRowStride)
                yBuf.put(yPlane, row * width, width)
            }
        }

        // U & V Planes
        val uvWidth = width / 2
        val uvHeight = height / 2
        val uBuf = planes[1].buffer
        val vBuf = planes[2].buffer
        val uRowStride = planes[1].rowStride
        val uPixelStride = planes[1].pixelStride
        val vRowStride = planes[2].rowStride
        val vPixelStride = planes[2].pixelStride

        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val srcIdx = row * uvWidth + col
                uBuf.put(row * uRowStride + col * uPixelStride, uPlane[srcIdx])
                vBuf.put(row * vRowStride + col * vPixelStride, vPlane[srcIdx])
            }
        }
    }

    private fun initEffects(sessionId: Int, enabled: Boolean) {
        if (sessionId != currentSessionId && sessionId > 0) {
            releaseEffects()
            currentSessionId = sessionId
            equalizer = Equalizer(0, sessionId).apply { this.enabled = enabled }
            bassBoost = BassBoost(0, sessionId).apply { this.enabled = enabled }
            virtualizer = Virtualizer(0, sessionId).apply { this.enabled = enabled }
        } else {
            equalizer?.enabled = enabled
            bassBoost?.enabled = enabled
            virtualizer?.enabled = enabled
        }
    }

    private fun getEqualizerInfo(): Map<String, Any> {
        val eq = equalizer ?: return emptyMap()
        val numBands = eq.numberOfBands.toInt()
        val range = eq.bandLevelRange
        val bands = mutableListOf<Map<String, Int>>()
        for (i in 0 until numBands) {
            val b = i.toShort()
            bands.add(
                mapOf(
                    "index" to i,
                    "centerFreqHz" to (eq.getCenterFreq(b) / 1000),
                    "level" to eq.getBandLevel(b).toInt()
                )
            )
        }
        return mapOf(
            "minLevel" to range[0].toInt(),
            "maxLevel" to range[1].toInt(),
            "bands" to bands
        )
    }

    private fun releaseEffects() {
        try {
            equalizer?.release()
            bassBoost?.release()
            virtualizer?.release()
        } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
    }

    override fun onDestroy() {
        releaseEffects()
        super.onDestroy()
    }
}
