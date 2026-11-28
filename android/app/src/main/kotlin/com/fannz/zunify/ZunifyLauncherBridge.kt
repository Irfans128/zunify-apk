package com.fannz.zunify

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.LruCache
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors

/**
 * In-Process Ultra-Lightweight Bridge between Zunify Audio/Lyrics Engine and
 * Zunify Built-In Native Launcher (`ZunifyLauncherActivity`).
 * Zero IPC overhead, zero background services, ~0 KB RAM when Launcher is off.
 */
data class LauncherMusicState(
    val title: String = "",
    val artist: String = "",
    val artUrl: String = "",
    val liveLyric: String = "",
    val isPlaying: Boolean = false,
    val isFavorite: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val ambientColor: Int = 0xFF1A2238.toInt(),
    val accentColor: Int = 0xFF5EEAD4.toInt(),
    val themeMode: String = "liquid_glass",
    val isLightCanvas: Boolean = false,
) {
    val hasTrack: Boolean get() = title.isNotBlank()
}

object ZunifyLauncherBridge {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val artCache = LruCache<String, Bitmap>(6)
    private val listeners = CopyOnWriteArraySet<(LauncherMusicState) -> Unit>()

    @Volatile
    var currentState: LauncherMusicState = LauncherMusicState()
        private set

    /** Registered by MainActivity to execute playback controls directly in Flutter PlayerProvider */
    @Volatile
    var onActionFromLauncher: ((String) -> Unit)? = null

    fun addListener(listener: (LauncherMusicState) -> Unit) {
        listeners.add(listener)
        listener(currentState)
    }

    fun removeListener(listener: (LauncherMusicState) -> Unit) {
        listeners.remove(listener)
    }

    fun updateState(newState: LauncherMusicState) {
        currentState = newState
        mainHandler.post {
            for (l in listeners) {
                try {
                    l(newState)
                } catch (_: Exception) {}
            }
        }
    }

    fun dispatchAction(context: Context, action: String) {
        if (action == "openApp" || action == "openLyrics") {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                if (action == "openLyrics") {
                    putExtra("zunify_open_lyrics", true)
                }
            }
            try {
                context.startActivity(launchIntent)
            } catch (_: Exception) {}
        }
        val cb = onActionFromLauncher
        if (cb != null) {
            mainHandler.post { cb(action) }
        } else if (action != "openApp" && action != "openLyrics") {
            // If MainActivity isn't alive yet, open Zunify so playback can resume cleanly
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            try {
                context.startActivity(launchIntent)
            } catch (_: Exception) {}
        }
    }

    fun loadAlbumArt(url: String, onLoaded: (Bitmap?) -> Unit) {
        if (url.isBlank()) {
            onLoaded(null)
            return
        }
        val cached = artCache.get(url)
        if (cached != null && !cached.isRecycled) {
            onLoaded(cached)
            return
        }
        ioExecutor.execute {
            var bmp: Bitmap? = null
            try {
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 4500
                    readTimeout = 4500
                    setRequestProperty("User-Agent", "Zunify/3.0")
                }
                if (conn.responseCode == 200) {
                    conn.inputStream.use { stream ->
                        val raw = BitmapFactory.decodeStream(stream)
                        if (raw != null) {
                            // Downscale to crisp 192px square so RAM stays ultra-light
                            val target = 192
                            bmp = if (raw.width > target || raw.height > target) {
                                Bitmap.createScaledBitmap(raw, target, target, true).also {
                                    if (it != raw) raw.recycle()
                                }
                            } else {
                                raw
                            }
                            bmp?.let { artCache.put(url, it) }
                        }
                    }
                }
                conn.disconnect()
            } catch (_: Exception) {}
            mainHandler.post { onLoaded(bmp) }
        }
    }

    private fun homeEntryComponent(context: Context): ComponentName {
        return ComponentName(context.packageName, "${context.packageName}.ZunifyHomeEntry")
    }

    fun isLauncherComponentEnabled(context: Context): Boolean {
        return try {
            val state = context.packageManager.getComponentEnabledSetting(homeEntryComponent(context))
            state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } catch (_: Exception) {
            false
        }
    }

    fun setLauncherComponentEnabled(context: Context, enabled: Boolean): Boolean {
        return try {
            context.packageManager.setComponentEnabledSetting(
                homeEntryComponent(context),
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    fun openHomeSettingsPicker(context: Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_HOME_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val fallback = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
