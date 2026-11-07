package com.fannz.zunify

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
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
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Real-Time Native Android Background Notification Engine for Zunify.
 * Runs in a lightweight dedicated `:notif` process (zero Flutter engine overhead),
 * survives swipe-from-Recents via `onTaskRemoved` + chained one-shot `JobScheduler` +
 * exact `AlarmManager` (`USE_EXACT_ALARM`), and polls Git Smart-HTTP HEAD SHA (754 bytes,
 * 0 CDN lag, 0 GitHub API 60/hr rate limit) every 7 seconds.
 */
object ZunifyNotifEngine {
    const val ACTION_POLL = "com.fannz.zunify.ACTION_POLL_NOTIF"
    const val CHANNEL_ID = "zunify_broadcast_sound_v3"
    private const val CHANNEL_NAME = "Notifikasi Zunify"

    private const val STATE_FILE_NAME = "zunify_notif_state.json"
    private const val LOCK_FILE_NAME = "zunify_notif.lock"

    const val JOB_ID_PERIODIC = 9410
    const val JOB_ID_FAST = 9412
    private const val REQ_ALARM = 9411
    private const val POLL_STEP_MS = 7_000L
    private const val ALARM_BACKUP_MS = 20_000L
    private const val REPO = "Irfans128/zunify-apk"

    private val inProcessFileLock = Any()
    private val isChecking = AtomicBoolean(false)
    private val isWatcherLoopRunning = AtomicBoolean(false)
    private val shaRegex = Regex("([0-9a-f]{40})\\s+refs/heads/main")

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

    /**
     * Called from MainActivity (UI process) and background receivers/services.
     */
    fun ensureScheduled(context: Context, startKeepAliveService: Boolean = false) {
        if (isAdminPackage(context)) return
        val appCtx = context.applicationContext
        initStateIfNeeded(appCtx)
        ensureChannel(appCtx)
        schedulePeriodicWatchdogJob(appCtx)
        scheduleFastOneShotJob(appCtx, 2_000L)
        scheduleNextAlarm(appCtx, ALARM_BACKUP_MS)
        if (startKeepAliveService) {
            try {
                appCtx.startService(Intent(appCtx, ZunifyKeepAliveService::class.java))
            } catch (_: Exception) {}
        }
    }

    /**
     * Cross-process safe disk state reader/updater protected by JVM monitor + OS FileChannel lock.
     */
    private fun <T> withLockedState(
        context: Context,
        block: (JSONObject, (JSONObject) -> Unit) -> T
    ): T {
        synchronized(inProcessFileLock) {
            val dir = context.filesDir
            if (!dir.exists()) dir.mkdirs()
            val lockFile = File(dir, LOCK_FILE_NAME)
            val stateFile = File(dir, STATE_FILE_NAME)
            RandomAccessFile(lockFile, "rw").use { raf ->
                raf.channel.use { ch ->
                    val fl = try {
                        ch.lock()
                    } catch (_: Exception) {
                        null
                    }
                    try {
                        val current = if (stateFile.exists()) {
                            try {
                                JSONObject(stateFile.readText(Charsets.UTF_8))
                            } catch (_: Exception) {
                                JSONObject()
                            }
                        } else {
                            JSONObject()
                        }
                        val saveFn: (JSONObject) -> Unit = { updated ->
                            try {
                                val tmp = File(dir, "$STATE_FILE_NAME.tmp")
                                tmp.writeText(updated.toString(), Charsets.UTF_8)
                                if (!tmp.renameTo(stateFile)) {
                                    stateFile.writeText(updated.toString(), Charsets.UTF_8)
                                    tmp.delete()
                                }
                            } catch (_: Exception) {}
                        }
                        return block(current, saveFn)
                    } finally {
                        try {
                            fl?.release()
                        } catch (_: Exception) {}
                    }
                }
            }
        }
    }

    private fun initStateIfNeeded(context: Context) {
        try {
            withLockedState(context) { state, save ->
                if (!state.optBoolean("initialized", false)) {
                    // Migrate from previous v2.0.0 prefs or FlutterSharedPreferences if present
                    val legacyPrefs = context.getSharedPreferences(
                        "zunify_notif_prefs",
                        Context.MODE_PRIVATE
                    )
                    val flutterPrefs = context.getSharedPreferences(
                        "FlutterSharedPreferences",
                        Context.MODE_PRIVATE
                    )
                    val migratedId = legacyPrefs.getString("last_seen_id", "")?.takeIf { it.isNotEmpty() }
                        ?: flutterPrefs.getString("flutter.last_seen_announcement_id", "")
                        ?: ""
                    val hasOnboarded = flutterPrefs.getBoolean(
                        "flutter.has_completed_onboarding",
                        false
                    )
                    val baselineMs = if (hasOnboarded || migratedId.isNotEmpty()) {
                        0L
                    } else {
                        System.currentTimeMillis()
                    }
                    state.put("initialized", true)
                    state.put("firstInstallMs", baselineMs)
                    if (migratedId.isNotEmpty()) {
                        state.put("lastSeenId", migratedId)
                    }
                    save(state)
                }
            }
        } catch (_: Exception) {}
    }

    fun schedulePeriodicWatchdogJob(context: Context) {
        try {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
                ?: return
            val alreadyPending = js.allPendingJobs.any { it.id == JOB_ID_PERIODIC }
            if (!alreadyPending) {
                val comp = ComponentName(context, ZunifyNotifJobService::class.java)
                val job = JobInfo.Builder(JOB_ID_PERIODIC, comp)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPersisted(true)
                    .setPeriodic(15 * 60 * 1000L)
                    .build()
                js.schedule(job)
            }
        } catch (_: Exception) {}
    }

    fun scheduleFastOneShotJob(context: Context, delayMs: Long = 3_000L, forceReplace: Boolean = false) {
        if (isAdminPackage(context)) return
        try {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
                ?: return
            if (!forceReplace && isWatcherLoopRunning.get()) return
            if (!forceReplace && js.allPendingJobs.any { it.id == JOB_ID_FAST }) return

            val safeDelay = delayMs.coerceAtLeast(1_500L)
            val comp = ComponentName(context, ZunifyNotifJobService::class.java)
            val job = JobInfo.Builder(JOB_ID_FAST, comp)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setMinimumLatency(safeDelay)
                .setOverrideDeadline(safeDelay + 4_500L)
                .setPersisted(true)
                .build()
            js.schedule(job)
        } catch (_: Exception) {}
    }

    fun scheduleNextAlarm(context: Context, delayMs: Long = ALARM_BACKUP_MS) {
        if (isAdminPackage(context)) return
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, ZunifyNotifReceiver::class.java).apply {
                action = ACTION_POLL
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pi = PendingIntent.getBroadcast(context, REQ_ALARM, intent, flags)
            val triggerAt = System.currentTimeMillis() + delayMs.coerceAtLeast(3_000L)

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
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (_: Exception) {}
    }

    /**
     * Runs a continuous 7-second background watcher loop for up to [maxDurationMs],
     * then hands off cleanly to the next scheduled Job / Alarm.
     */
    fun startBackgroundWatcherLoop(
        context: Context,
        maxDurationMs: Long = 240_000L,
        stopSignal: AtomicBoolean? = null,
        onLoopEnded: (() -> Unit)? = null
    ) {
        if (isAdminPackage(context)) {
            onLoopEnded?.invoke()
            return
        }
        if (!isWatcherLoopRunning.compareAndSet(false, true)) {
            onLoopEnded?.invoke()
            return
        }
        val appCtx = context.applicationContext
        Thread {
            try {
                val startedAt = System.currentTimeMillis()
                while (stopSignal?.get() != true &&
                    (System.currentTimeMillis() - startedAt) < maxDurationMs
                ) {
                    try {
                        checkNowSync(appCtx)
                    } catch (_: Exception) {}
                    try {
                        Thread.sleep(POLL_STEP_MS)
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            } finally {
                isWatcherLoopRunning.set(false)
                scheduleFastOneShotJob(appCtx, 2_000L, forceReplace = true)
                scheduleNextAlarm(appCtx, 8_000L)
                onLoopEnded?.invoke()
            }
        }.apply {
            isDaemon = true
            name = "ZunifyNotifWatcher"
            start()
        }
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
            initStateIfNeeded(context)

            var knownSha = ""
            var knownSeenId = ""
            var firstInstallMs = 0L
            withLockedState(context) { state, _ ->
                knownSha = state.optString("lastCheckedSha", "")
                knownSeenId = state.optString("lastSeenId", "")
                firstInstallMs = state.optLong("firstInstallMs", 0L)
            }

            // Step 1: Ultra-fast 754-byte Git Smart-HTTP HEAD SHA check (0 CDN cache lag, 0 rate limit!)
            val remoteHeadSha = fetchRemoteMainHeadSha()
            if (remoteHeadSha != null &&
                remoteHeadSha == knownSha &&
                knownSeenId.isNotEmpty()
            ) {
                return
            }

            // Step 2: Fetch fresh announcements.json using immutable commit SHA URL (bypasses CDN cache 100%)
            val rawJson = fetchFreshAnnouncementJson(remoteHeadSha) ?: return
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

            if (!active || id.isEmpty() || message.isEmpty()) {
                if (remoteHeadSha != null) {
                    withLockedState(context) { state, save ->
                        state.put("lastCheckedSha", remoteHeadSha)
                        save(state)
                    }
                }
                return
            }

            if (!canPostNotification(context)) {
                // Keep unseen until notification permission is active
                return
            }

            var shouldPost = false
            withLockedState(context) { state, save ->
                val latestSeenId = state.optString("lastSeenId", "")
                val installBaseline = state.optLong("firstInstallMs", firstInstallMs)
                if (remoteHeadSha != null) {
                    state.put("lastCheckedSha", remoteHeadSha)
                }
                if (id == latestSeenId) {
                    save(state)
                    shouldPost = false
                } else if (latestSeenId.isEmpty() &&
                    installBaseline > 0L &&
                    createdAtMs > 0L &&
                    createdAtMs < (installBaseline - 15 * 60 * 1000L)
                ) {
                    // Stale broadcast from before fresh install -> mark seen silently
                    state.put("lastSeenId", id)
                    save(state)
                    shouldPost = false
                } else {
                    state.put("lastSeenId", id)
                    save(state)
                    shouldPost = true
                }
            }

            if (shouldPost) {
                postSystemNotification(
                    context = context,
                    notifId = (id.hashCode() and 0x7FFFFFFF).coerceAtLeast(1001),
                    title = title,
                    body = message,
                    imageUrl = imageUrl
                )
            }
        } catch (_: Exception) {
        } finally {
            isChecking.set(false)
        }
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

    private fun fetchRemoteMainHeadSha(): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(
                "https://github.com/$REPO/info/refs?service=git-upload-pack&t=${System.currentTimeMillis()}"
            )
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 5500
                readTimeout = 5500
                useCaches = false
                setRequestProperty("User-Agent", "git/2.43.0")
                setRequestProperty("Cache-Control", "no-cache, no-store, max-age=0")
                setRequestProperty("Pragma", "no-cache")
            }
            if (conn.responseCode != HttpURLConnection.HTTP_OK) return null
            val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            shaRegex.find(body)?.groupValues?.getOrNull(1)
        } catch (_: Exception) {
            null
        } finally {
            try {
                conn?.disconnect()
            } catch (_: Exception) {}
        }
    }

    private fun fetchFreshAnnouncementJson(commitSha: String?): String? {
        val urlsToTry = mutableListOf<String>()
        if (!commitSha.isNullOrBlank()) {
            // Immutable SHA path: 0.0s Fastly CDN cache lag + unlimited requests!
            urlsToTry.add("https://raw.githubusercontent.com/$REPO/$commitSha/announcements.json")
        }
        urlsToTry.add(
            "https://raw.githubusercontent.com/$REPO/main/announcements.json?cb=${System.currentTimeMillis()}"
        )

        for (target in urlsToTry) {
            var conn: HttpURLConnection? = null
            try {
                conn = (URL(target).openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 6500
                    readTimeout = 6500
                    useCaches = false
                    setRequestProperty("Cache-Control", "no-cache, no-store, max-age=0")
                    setRequestProperty("Pragma", "no-cache")
                    setRequestProperty("User-Agent", "Zunify-Android-Notif")
                }
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    return conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                }
            } catch (_: Exception) {
            } finally {
                try {
                    conn?.disconnect()
                } catch (_: Exception) {}
            }
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

        val launchIntent = Intent(context, MainActivity::class.java).apply {
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

/**
 * Sticky lightweight background service in `:notif` process.
 * Catches `onTaskRemoved` the instant Zunify is swiped away from Recent Apps
 * and immediately re-arms both the fast JobScheduler watcher and exact AlarmManager.
 */
class ZunifyKeepAliveService : Service() {
    private val stopFlag = AtomicBoolean(false)

    override fun onCreate() {
        super.onCreate()
        if (ZunifyNotifEngine.isAdminPackage(this)) {
            stopSelf()
            return
        }
        ZunifyNotifEngine.ensureScheduled(this, startKeepAliveService = false)
        ZunifyNotifEngine.startBackgroundWatcherLoop(
            context = this,
            maxDurationMs = 30 * 60 * 1000L,
            stopSignal = stopFlag
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (ZunifyNotifEngine.isAdminPackage(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        ZunifyNotifEngine.startBackgroundWatcherLoop(
            context = this,
            maxDurationMs = 30 * 60 * 1000L,
            stopSignal = stopFlag
        )
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!ZunifyNotifEngine.isAdminPackage(this)) {
            ZunifyNotifEngine.scheduleFastOneShotJob(this, 1_800L, forceReplace = true)
            ZunifyNotifEngine.scheduleNextAlarm(this, 3_500L)
            ZunifyNotifEngine.checkNowAsync(this)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopFlag.set(true)
        if (!ZunifyNotifEngine.isAdminPackage(this)) {
            ZunifyNotifEngine.scheduleFastOneShotJob(this, 2_000L, forceReplace = true)
            ZunifyNotifEngine.scheduleNextAlarm(this, 4_000L)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

/**
 * OS-managed `JobService` in `:notif` process (`JOB_ID_FAST` + `JOB_ID_PERIODIC`).
 * Survives app swipe-away even when background services are restricted.
 */
class ZunifyNotifJobService : JobService() {
    private val stopFlag = AtomicBoolean(false)

    override fun onStartJob(params: JobParameters?): Boolean {
        if (ZunifyNotifEngine.isAdminPackage(this)) {
            jobFinished(params, false)
            return false
        }
        stopFlag.set(false)
        ZunifyNotifEngine.schedulePeriodicWatchdogJob(this)
        ZunifyNotifEngine.scheduleNextAlarm(this, 20_000L)

        // Run live 7s SHA watcher for up to 4 minutes inside this JobService slice, then re-chain
        ZunifyNotifEngine.startBackgroundWatcherLoop(
            context = this,
            maxDurationMs = 240_000L,
            stopSignal = stopFlag
        ) {
            try {
                jobFinished(params, false)
            } catch (_: Exception) {}
        }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        stopFlag.set(true)
        ZunifyNotifEngine.scheduleFastOneShotJob(this, 2_000L, forceReplace = true)
        ZunifyNotifEngine.scheduleNextAlarm(this, 5_000L)
        return true
    }
}

class ZunifyNotifReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (ZunifyNotifEngine.isAdminPackage(context)) return
        ZunifyNotifEngine.schedulePeriodicWatchdogJob(context)
        ZunifyNotifEngine.scheduleFastOneShotJob(context, 2_000L)
        ZunifyNotifEngine.scheduleNextAlarm(context, 20_000L)
        val pendingResult = goAsync()
        ZunifyNotifEngine.checkNowAsync(context) {
            try {
                pendingResult.finish()
            } catch (_: Exception) {}
        }
    }
}
