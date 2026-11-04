package com.fannz.zunify

import android.content.Intent
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Zunify MainActivity - Crafted with ❤️ by Fannz
 * Bridges Flutter audioSessionId directly to Android's hardware DSP Equalizer,
 * BassBoost, Virtualizer, and native APK update installer.
 */
class MainActivity : AudioServiceFragmentActivity() {
    private val CHANNEL = "com.fannz.zunify/equalizer"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId: Int = -1

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
