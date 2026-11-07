package com.fannz.zunify

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.PKCS8EncodedKeySpec
import java.text.SimpleDateFormat
import java.util.Locale

object ZunifyFcmHelper {
    const val CHANNEL_ID = "zunify_fcm_sound_v1"
    const val TOPIC_ALL = "zunify_all"
    private const val CHANNEL_NAME = "Notifikasi Zunify"

    fun isAdminPackage(context: Context): Boolean {
        return context.packageName.endsWith(".admin")
    }

    /**
     * Cleans up legacy polling artifacts (jobs, alarms, state files) from previous builds,
     * ensures high-importance sound notification channel exists, and subscribes the device
     * anonymously to the FCM topic (NO Google login required by any user).
     */
    fun initAndSubscribe(context: Context) {
        val appCtx = context.applicationContext
        cleanupLegacyPollingArtifacts(appCtx)
        if (isAdminPackage(appCtx)) return
        ensureSoundChannel(appCtx)
        try {
            FirebaseMessaging.getInstance().subscribeToTopic(TOPIC_ALL)
        } catch (_: Exception) {}
    }

    private fun cleanupLegacyPollingArtifacts(context: Context) {
        try {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
            js?.cancel(9410)
            js?.cancel(9412)
        } catch (_: Exception) {}
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val intent = Intent("com.fannz.zunify.ACTION_POLL_NOTIF").apply {
                setPackage(context.packageName)
            }
            val flags = PendingIntent.FLAG_NO_CREATE or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pi = PendingIntent.getBroadcast(context, 9411, intent, flags)
            if (pi != null) {
                am?.cancel(pi)
                pi.cancel()
            }
        } catch (_: Exception) {}
        try {
            File(context.filesDir, "zunify_notif_state.json").delete()
            File(context.filesDir, "zunify_notif.lock").delete()
        } catch (_: Exception) {}
    }

    fun ensureSoundChannel(context: Context) {
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
                    description = "Notifikasi resmi Zunify"
                    setSound(soundUri, audioAttrs)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 240, 120, 240)
                    enableLights(true)
                }
                nm.createNotificationChannel(channel)
            } catch (_: Exception) {}
        }
    }

    private fun downloadScaledBitmap(imageUrl: String): Bitmap? {
        if (imageUrl.isBlank()) return null
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(imageUrl).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 8000
                readTimeout = 8000
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", "Zunify-FCM")
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
        title: String,
        body: String,
        imageUrl: String = ""
    ) {
        ensureSoundChannel(context)
        val bmp = if (imageUrl.isNotBlank()) downloadScaledBitmap(imageUrl) else null
        val notifId = ((System.currentTimeMillis() and 0x7FFFFFFF).toInt()).coerceAtLeast(1001)

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
 * Official Firebase Cloud Messaging Service for Zunify.
 * - When app is swiped closed/killed: Android OS & Google Play Services automatically show the notification.
 * - When app is open in foreground: shows ONLY in the OS status bar with sound (never popup in app UI).
 */
class ZunifyFcmService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        if (!ZunifyFcmHelper.isAdminPackage(this)) {
            try {
                FirebaseMessaging.getInstance().subscribeToTopic(ZunifyFcmHelper.TOPIC_ALL)
            } catch (_: Exception) {}
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        if (ZunifyFcmHelper.isAdminPackage(this)) return

        val notif = message.notification
        val title = (notif?.title ?: message.data["title"] ?: "Zunify").trim()
        val body = (notif?.body ?: message.data["body"] ?: "").trim()
        val imgUrl = (notif?.imageUrl?.toString() ?: message.data["image"] ?: "").trim()

        if (body.isEmpty()) return
        ZunifyFcmHelper.postSystemNotification(
            context = applicationContext,
            title = if (title.isEmpty()) "Zunify" else title,
            body = body,
            imageUrl = imgUrl
        )
    }
}

/**
 * Native FCM HTTP v1 Dispatcher for Zunify Notif Admin APK.
 * Uses Service Account credentials to send real-time sound notifications directly to all Zunify users.
 */
object ZunifyFcmSender {
    private const val PROJECT_ID = "zunify-376c4"
    private const val CLIENT_EMAIL = "firebase-adminsdk-fbsvc@zunify-376c4.iam.gserviceaccount.com"
    private const val PKCS8_B64 = "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDZGuGt4ZzBPAiAvtPjBGXy4RZkK+qKgewszByz9uXgoHSP67El42drICUQV5bL+4hXGImwTf3WgqZNMEzRZ6kgoqeLNoCIZwUAKsLYPCspYNRM5Jtp7kMO0cer/cCFO3USYW3yp1w6vn8820qyhG1qpYNofZMWcCKDy5VeZEbZP+uJbnKcLPDsI7BRJY7rvcNAi+s2gIWXNn7fXebKX/EIE18d/iy1ZCL3nzhS65hj4jjA5Uv1avOBrCUF6BsaO8wAWHRTTFMkz167KH5lbpmK7nRpNVbp4rl1A1lQY16/y/2x3F68oWbAGjvhAV6QPgE/TRsMJ2tJwLsJ3NsIuaXdAgMBAAECggEADlh+4hj+3Svk2fECGkWfoPFro9ndCSL1oq4oFWIypWmk2h+2WG0S19rLaC2JetgXlb2612oH5GVErOQMp2ekntHwpTvIOXspMu4gat5q8bSCwsP2WwUR7EhDW+OMFaGspjbG55pUd1NAIBrTcEFc44elS8HEdt6ZAUFyEMcqgU9fQdVRrf9vuquaxijW5I+KMmQnit7uQXAmyDua7FBVxCNN769kQGdXra5MI+vfGYUM0c5agiWTE2VAHzFwOLXCPQhtIfCf0cbfGxCaG0S/dP+jCN7ym1bDWlaYaF5hIsfNae2JNqqJWZljD6gx/aM5NO5hSaxA5EeUg6J/OjKjwQKBgQD5bMgP+Ua1grLxpKUFlm0OQhJFQpye53Js8t5PHlsicogL+rX9L6Wp2JtxszClNe0zVyu92Qh6GL5r2wntJLPYBQTRB1pX/Ybej5Q+sQRfuanUPCT/7God06nBlc0mtzgKdMys5oO8mTmVw74N/hPZSqNRYsIilfQO1WXPRIDovQKBgQDe0/4NjN82pZIebOqlVJSOdGtnwvlDkJ4TQsEzmBThtatca2nEW6XvcIlbq8J0049/6LHhjXA0meL2l4TNRE3Bvu4vjmfQCNPQPvx9MU4h8yLAIKaNxfgjcTui2D7vOSUgY6Me3PVgXhtmeUpt7oUk5vF7Y7m6DfPRwpuWaRpToQKBgB8SMgnrX6eU1H3NqND9YDB6gpQmLCSPaG2yA4ePnIK6CcCURr93hAeYeCS90b2C7j2LCmPn+WpcUrxU2PO1ssGiPmtboyF676Yh9LGqk4TpOAK8S0+mP8HfcDIxWxELmeuTiTuwq5B+9fF2JOLRV9+lsJqe1thAHdsLMleTjQtxAoGBAIkxAHQbTbr5idNNv9J3Ftf2ecJy2sFsosa9DPLVKdYl4hGO2Jnay3l2Ujusrpb7QpjADfUO/gyEyqaEd3FiInWtNjz1cpk1NiQ7A32ZA8AHUFf2QlV7k+FOcCc8+NKU3nToo5/27uScTEZ1WwwAFN25iugraEhTGtEE/oJGx7zBAoGAJ0iMknCI53kIDWiaHlq7dNPy9zSWinifZHK6xrzKQc3nSZydmUR2QehmKTqtIN/On3iNgZDJyxINqMFN9r04+kx454Vs2Wu/PwbKfzT/9WkMD8ntJZUwPYB2AOiEpZFq2x03Qh+WWXF1ZqiskBYjYhHv70+mK617qJdpzk/NEMo="

    private fun base64Url(bytes: ByteArray): String {
        return android.util.Base64.encodeToString(
            bytes,
            android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP
        )
    }

    private fun getOAuth2AccessToken(): String? {
        var epochSec = System.currentTimeMillis() / 1000L
        try {
            val dateConn = URL("https://www.google.com").openConnection() as HttpURLConnection
            dateConn.requestMethod = "HEAD"
            dateConn.connectTimeout = 4000
            dateConn.readTimeout = 4000
            val dateHeader = dateConn.getHeaderField("Date")
            if (!dateHeader.isNullOrBlank()) {
                val parsed = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss z", Locale.US).parse(dateHeader)
                if (parsed != null) {
                    epochSec = parsed.time / 1000L
                }
            }
            dateConn.disconnect()
        } catch (_: Exception) {}

        val headerJson = "{\"alg\":\"RS256\",\"typ\":\"JWT\"}"
        val claimsJson = "{\"iss\":\"$CLIENT_EMAIL\",\"scope\":\"https://www.googleapis.com/auth/firebase.messaging\",\"aud\":\"https://oauth2.googleapis.com/token\",\"iat\":$epochSec,\"exp\":${epochSec + 3600}}"
        val headerB64 = base64Url(headerJson.toByteArray(Charsets.UTF_8))
        val claimsB64 = base64Url(claimsJson.toByteArray(Charsets.UTF_8))
        val unsignedJwt = "$headerB64.$claimsB64"

        val keyBytes = android.util.Base64.decode(PKCS8_B64, android.util.Base64.DEFAULT)
        val keySpec = PKCS8EncodedKeySpec(keyBytes)
        val kf = KeyFactory.getInstance("RSA")
        val privateKey = kf.generatePrivate(keySpec)

        val signer = Signature.getInstance("SHA256withRSA")
        signer.initSign(privateKey)
        signer.update(unsignedJwt.toByteArray(Charsets.UTF_8))
        val sigBytes = signer.sign()
        val jwt = "$unsignedJwt.${base64Url(sigBytes)}"

        val conn = URL("https://oauth2.googleapis.com/token").openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.doOutput = true
        conn.connectTimeout = 7000
        conn.readTimeout = 7000
        conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
        val postData = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$jwt"
        conn.outputStream.use { it.write(postData.toByteArray(Charsets.UTF_8)) }
        if (conn.responseCode != 200) return null
        val responseText = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        val json = JSONObject(responseText)
        return json.optString("access_token", null)
    }

    fun sendBroadcast(title: String, body: String, imageUrl: String = ""): Boolean {
        return try {
            val token = getOAuth2AccessToken() ?: return false
            val conn = URL("https://fcm.googleapis.com/v1/projects/$PROJECT_ID/messages:send").openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")

            val messageObj = JSONObject().apply {
                put("topic", ZunifyFcmHelper.TOPIC_ALL)
                val notifObj = JSONObject().apply {
                    put("title", title)
                    put("body", body)
                    if (imageUrl.isNotBlank()) {
                        put("image", imageUrl.trim())
                    }
                }
                put("notification", notifObj)
                val androidObj = JSONObject().apply {
                    put("priority", "high")
                    val androidNotif = JSONObject().apply {
                        put("channel_id", ZunifyFcmHelper.CHANNEL_ID)
                        put("default_sound", true)
                        put("default_vibrate_timings", true)
                        put("notification_priority", "priority_max")
                    }
                    put("notification", androidNotif)
                }
                put("android", androidObj)
            }

            val rootObj = JSONObject().apply {
                put("message", messageObj)
            }

            conn.outputStream.use { it.write(rootObj.toString().toByteArray(Charsets.UTF_8)) }
            conn.responseCode == 200
        } catch (_: Exception) {
            false
        }
    }
}
