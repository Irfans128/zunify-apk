package com.fannz.zunify

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Android Background Notification Engine for Zunify.
 * Works even when the Flutter UI / app process has been swiped closed or after device reboot,
 * delivering system status-bar notifications with sound and optional banner image.
 */
object ZunifyNotifEngine {
    const val ACTION_POLL = "com.fannz.zunify.ACTION_POLL_NOTIF"
    const val CHANNEL_ID = "zunify_broadcast_sound_v3"
    private const val CHANNEL_NAME = "Notifikasi Zunify"
    private const val PREFS_NAME = "zunify_notif_prefs"
    private const val KEY_INITIALIZED = "initialized"
    private const val KEY_FIRST_INSTALL_MS = "first_install_ms"
    private const val KEY_LAST_SEEN_ID = "last_seen_id"
    private const val KEY_LAST_ETAG = "last_etag"
    private const val JOB_ID = 9410
    private const val REQ_ALARM = 9411
    private const val ALARM_INTERVAL_MS = 90_000L // 1.5 minutes
    private const val REPO = "Irfans128/zunify-apk"

    private val isChecking = AtomicBoolean(false)

    fun isAdminPackage(context: Context): Boolean {
        return context.packageName.endsWith(".admin")
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttrs = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifikasi informasi resmi Zunify"
                    setSound(soundUri, audioAttrs)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 240, 120, 240)
                    enableLights(true)
                }
                nm.createNotificationChannel(channel)
            } catch (_: Exception) {}
        }
    }

    fun ensureScheduled(context: Context) {
        if (isAdminPackage(context)) return
        val appCtx = context.applicationContext
        initPrefsIfNeeded(appCtx)
        ensureChannel(appCtx)
        schedulePeriodicJob(appCtx)
        scheduleNextAlarm(appCtx, ALARM_INTERVAL_MS)
    }

    private fun initPrefsIfNeeded(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_INITIALIZED, false)) {
                val flutterPrefs = context.getSharedPreferences(
                    "FlutterSharedPreferences",
                    Context.MODE_PRIVATE
                )
                val migratedId = flutterPrefs.getString("flutter.last_seen_announcement_id", "") ?: ""
                val hasOnboarded = flutterPrefs.getBoolean("flutter.has_completed_onboarding", false)
                val now = System.currentTimeMillis()
                // If upgrading user already completed onboarding before, set install baseline in the past
                // so any broadcast sent while they were offline/updating still arrives.
                val baselineMs = if (hasOnboarded || migratedId.isNotEmpty()) 0L else now
                prefs.edit()
                    .putBoolean(KEY_INITIALIZED, true)
                    .putLong(KEY_FIRST_INSTALL_MS, baselineMs)
                    .apply {
                        if (migratedId.isNotEmpty()) {
                            putString(KEY_LAST_SEEN_ID, migratedId)
                        }
                    }
                    .commit()
            }
        } catch (_: Exception) {}
    }

    private fun schedulePeriodicJob(context: Context) {
        try {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
                ?: return
            val alreadyPending = js.allPendingJobs.any { it.id == JOB_ID }
            if (!alreadyPending) {
                val comp = ComponentName(context, ZunifyNotifJobService::class.java)
                val job = JobInfo.Builder(JOB_ID, comp)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPersisted(true)
                    .setPeriodic(15 * 60 * 1000L)
                    .build()
                js.schedule(job)
            }
        } catch (_: Exception) {}
    }

    fun scheduleNextAlarm(context: Context, delayMs: Long = ALARM_INTERVAL_MS) {
        if (isAdminPackage(context)) return
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, ZunifyNotifReceiver::class.java).apply {
                action = ACTION_POLL
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pi = PendingIntent.getBroadcast(context, REQ_ALARM, intent, flags)
            val triggerAt = System.currentTimeMillis() + delayMs

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                } catch (_: SecurityException) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                }
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (_: Exception) {}
    }

    fun checkNowAsync(context: Context, onComplete: (() -> Unit)? = null) {
        if (isAdminPackage(context)) {
            onComplete?.invoke()
            return
        }
        val appCtx = context.applicationContext
        Thread {
            try {
                checkNowSync(appCtx)
            } catch (_: Exception) {
            } finally {
                onComplete?.invoke()
            }
        }.start()
    }

    fun checkNowSync(context: Context) {
        if (isAdminPackage(context)) return
        if (!isChecking.compareAndSet(false, true)) return
        try {
            initPrefsIfNeeded(context)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lastSeenId = prefs.getString(KEY_LAST_SEEN_ID, "") ?: ""
            val lastEtag = prefs.getString(KEY_LAST_ETAG, "") ?: ""
            val firstInstallMs = prefs.getLong(KEY_FIRST_INSTALL_MS, 0L)

            val rawJson = fetchAnnouncementJson(prefs, lastEtag, lastSeenId) ?: return
            if (rawJson.isBlank()) return

            val json = JSONObject(rawJson)
            val id = json.optString("id", "").trim()
            val active = json.optBoolean("active", true)
            val title = json.optString("title", "").trim().ifEmpty { "Zunify" }
            val message = json.optString("message", "").trim()
            val imageUrl = json.optString("imageUrl", "").trim()
            var createdAtMs = json.optLong("createdAtMs", 0L)
            if (createdAtMs <= 0L && id.startsWith("fannz_")) {
                createdAtMs = id.removePrefix("fannz_").toLongOrNull() ?: 0L
            }

            if (!active || id.isEmpty() || message.isEmpty()) return
            if (id == lastSeenId) return

            // Prevent ancient broadcasts (older than 15 minutes before fresh install) from firing on new installs
            if (lastSeenId.isEmpty() &&
                firstInstallMs > 0L &&
                createdAtMs > 0L &&
                createdAtMs < (firstInstallMs - 15 * 60 * 1000L)
            ) {
                prefs.edit().putString(KEY_LAST_SEEN_ID, id).commit()
                syncFlutterPrefId(context, id)
                return
            }

            if (!canPostNotification(context)) {
                // Keep unseen until notification permission is granted so user doesn't miss recent notif
                return
            }

            // Record seen ID immediately so this broadcast fires strictly once ("sekali kirim yaudah")
            prefs.edit().putString(KEY_LAST_SEEN_ID, id).commit()
            syncFlutterPrefId(context, id)

            postSystemNotification(
                context = context,
                notifId = (id.hashCode() and 0x7FFFFFFF).coerceAtLeast(1001),
                title = title,
                body = message,
                imageUrl = imageUrl
            )
        } catch (_: Exception) {
        } finally {
            isChecking.set(false)
        }
    }

    private fun syncFlutterPrefId(context: Context, id: String) {
        try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.last_seen_announcement_id", id)
                .apply()
        } catch (_: Exception) {}
    }

    private fun canPostNotification(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        return try {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        } catch (_: Exception) {
            true
        }
    }

    private fun fetchAnnouncementJson(
        prefs: android.content.SharedPreferences,
        lastEtag: String,
        lastSeenId: String
    ): String? {
        // 1. Primary: GitHub Contents API with ETag conditional check (instant 0-lag + 0 rate-limit cost on 304)
        var conn: HttpURLConnection? = null
        try {
            val apiUrl = URL("https://api.github.com/repos/$REPO/contents/announcements.json")
            conn = (apiUrl.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 7000
                readTimeout = 7000
                useCaches = false
                setRequestProperty("Accept", "application/vnd.github.raw+json")
                setRequestProperty("User-Agent", "Zunify-Android-Notif")
                setRequestProperty("Cache-Control", "no-cache")
                if (lastEtag.isNotEmpty() && lastSeenId.isNotEmpty()) {
                    setRequestProperty("If-None-Match", lastEtag)
                }
            }
            val code = conn.responseCode
            if (code == HttpURLConnection.HTTP_NOT_MODIFIED) {
                return null
            }
            if (code == HttpURLConnection.HTTP_OK) {
                val newEtag = conn.getHeaderField("ETag") ?: ""
                if (newEtag.isNotEmpty()) {
                    prefs.edit().putString(KEY_LAST_ETAG, newEtag).apply()
                }
                return conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            }
        } catch (_: Exception) {
        } finally {
            try {
                conn?.disconnect()
            } catch (_: Exception) {}
        }

        // 2. Fallback: raw.githubusercontent.com with cache-buster (no 60/hr API rate limit)
        var rawConn: HttpURLConnection? = null
        try {
            val rawUrl = URL(
                "https://raw.githubusercontent.com/$REPO/main/announcements.json?cb=${System.currentTimeMillis()}"
            )
            rawConn = (rawUrl.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 7000
                readTimeout = 7000
                useCaches = false
                setRequestProperty("Cache-Control", "no-cache, no-store, max-age=0")
                setRequestProperty("Pragma", "no-cache")
                setRequestProperty("User-Agent", "Zunify-Android-Notif")
            }
            if (rawConn.responseCode == HttpURLConnection.HTTP_OK) {
                return rawConn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            }
        } catch (_: Exception) {
        } finally {
            try {
                rawConn?.disconnect()
            } catch (_: Exception) {}
        }
        return null
    }

    private fun downloadScaledBitmap(imageUrl: String): Bitmap? {
        if (imageUrl.isBlank()) return null
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(imageUrl)
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 8000
                readTimeout = 8000
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", "Zunify-Android-Notif")
            }
            if (conn.responseCode != HttpURLConnection.HTTP_OK) return null
            val bytes = conn.inputStream.use { it.readBytes() }
            if (bytes.isEmpty()) return null
            val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
            val maxDim = 1024
            if (decoded.width > maxDim || decoded.height > maxDim) {
                val ratio = maxDim.toFloat() / maxOf(decoded.width, decoded.height).toFloat()
                val nw = (decoded.width * ratio).toInt().coerceAtLeast(1)
                val nh = (decoded.height * ratio).toInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(decoded, nw, nh, true)
            } else {
                decoded
            }
        } catch (_: Exception) {
            null
        } finally {
            try {
                conn?.disconnect()
            } catch (_: Exception) {}
        }
    }

    fun postSystemNotification(
        context: Context,
        notifId: Int,
        title: String,
        body: String,
        imageUrl: String = "",
        localImagePath: String = ""
    ) {
        ensureChannel(context)
        val bmp: Bitmap? = when {
            localImagePath.isNotBlank() -> {
                try {
                    BitmapFactory.decodeFile(localImagePath)
                } catch (_: Exception) {
                    null
                }
            }
            imageUrl.isNotBlank() -> downloadScaledBitmap(imageUrl)
            else -> null
        }

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            } ?: Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val contentIntent = PendingIntent.getActivity(context, notifId, launchIntent, piFlags)
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_zunify)
            .setContentTitle(title)
            .setContentText(body)
            .setSound(soundUri)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)

        if (bmp != null) {
            builder.setLargeIcon(bmp)
            builder.setStyle(
                NotificationCompat.BigPictureStyle()
                    .bigPicture(bmp)
                    .bigLargeIcon(null as Bitmap?)
                    .setBigContentTitle(title)
                    .setSummaryText(body)
            )
        } else {
            builder.setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(body)
                    .setBigContentTitle(title)
            )
        }

        try {
            NotificationManagerCompat.from(context).notify(notifId, builder.build())
        } catch (_: SecurityException) {
        } catch (_: Exception) {}
    }
}

class ZunifyNotifJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        if (ZunifyNotifEngine.isAdminPackage(this)) {
            jobFinished(params, false)
            return false
        }
        ZunifyNotifEngine.scheduleNextAlarm(this)
        ZunifyNotifEngine.checkNowAsync(this) {
            try {
                jobFinished(params, false)
            } catch (_: Exception) {}
        }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }
}

class ZunifyNotifReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (ZunifyNotifEngine.isAdminPackage(context)) return
        ZunifyNotifEngine.ensureScheduled(context)
        val pendingResult = goAsync()
        ZunifyNotifEngine.checkNowAsync(context) {
            try {
                pendingResult.finish()
            } catch (_: Exception) {}
        }
    }
}
