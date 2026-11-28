package com.fannz.zunify

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import kotlin.math.sin

/**
 * Ultra-Lightweight Native Dynamic Capsule View for Zunify Built-In Launcher:
 * - Supports 3 themes (Liquid Glass, Neo-Brutalism, Classic iPod)
 * - Compact Music Pill (Squircle cover + track title + animated 3-bar audio spectrum)
 * - Spring-Expanded Music Island (Cover + Title + Artist + 1-line Live Lyric + Progress + Prev/Play/Next/Like/Open)
 * - System Micro-Events: Charging Pill (⚡ + %) & Bluetooth/Headset Pill (🎧 + device)
 * - Idle slim date/battery pill when music is stopped
 */
class DynamicCapsuleView(
    context: Context,
    private val onAction: (String) -> Unit,
    private val onExpandedChanged: (Boolean) -> Unit,
) : FrameLayout(context) {

    private val handler = Handler(Looper.getMainLooper())
    private var musicState = LauncherMusicState()
    private var currentTheme = "liquid_glass"
    private var isExpanded = false
    private var activeTransientEvent: String? = null
    private var currentArtUrl: String = ""
    private var batteryPct: Int = 100
    private var isCharging: Boolean = false

    private val bgDrawable = GradientDrawable()

    // Sub-containers for the 3 states
    private val compactRow: LinearLayout
    private val expandedCol: LinearLayout
    private val transientRow: LinearLayout

    // Compact views
    private val compactArt: ImageView
    private val compactTitle: TextView
    private val spectrumView: MiniSpectrumBarView

    // Expanded views
    private val expArt: ImageView
    private val expTitle: TextView
    private val expArtist: TextView
    private val expLikeBtn: TextView
    private val expLyric: TextView
    private val expProgress: ProgressBar
    private val expPrevBtn: TextView
    private val expPlayBtn: TextView
    private val expNextBtn: TextView
    private val expOpenBtn: TextView

    // Transient system event views (Charging / Bluetooth)
    private val transientIcon: TextView
    private val transientText: TextView

    private val clearTransientRunnable = Runnable {
        activeTransientEvent = null
        refreshLayout(animate = true)
    }

    init {
        clipChildren = false
        clipToPadding = false
        elevation = dp(10).toFloat()
        background = bgDrawable

        // 1. Compact Pill Row
        compactRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(7), dp(12), dp(7))
        }
        compactArt = ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = SquircleOutlineProvider(dp(7).toFloat())
            setBackgroundColor(0xFF1F2937.toInt())
        }
        compactRow.addView(compactArt, LinearLayout.LayoutParams(dp(24), dp(24)))

        compactTitle = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.2f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(8), 0, dp(8), 0)
        }
        compactRow.addView(
            compactTitle,
            LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        )

        spectrumView = MiniSpectrumBarView(context)
        compactRow.addView(spectrumView, LinearLayout.LayoutParams(dp(16), dp(14)))
        addView(compactRow, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        // 2. Transient Event Row (Charging / Bluetooth Headset)
        transientRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(8), dp(14), dp(8))
            visibility = View.GONE
        }
        transientIcon = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            setPadding(0, 0, dp(6), 0)
        }
        transientText = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.2f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        transientRow.addView(transientIcon)
        transientRow.addView(transientText)
        addView(transientRow, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        // 3. Expanded Music + Live Lyric Island
        expandedCol = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(14))
            visibility = View.GONE
        }

        val headerRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        expArt = ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = SquircleOutlineProvider(dp(12).toFloat())
            setBackgroundColor(0xFF1F2937.toInt())
            setOnClickListener { onAction("openApp") }
        }
        headerRow.addView(expArt, LinearLayout.LayoutParams(dp(48), dp(48)))

        val titleCol = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), 0, dp(8), 0)
            setOnClickListener { onAction("openApp") }
        }
        expTitle = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        expArtist = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        titleCol.addView(expTitle)
        titleCol.addView(expArtist)
        headerRow.addView(titleCol, LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))

        expLikeBtn = makeControlButton("♡", 19f) { onAction("toggleFavorite") }
        headerRow.addView(expLikeBtn, LinearLayout.LayoutParams(dp(36), dp(36)))
        expandedCol.addView(headerRow)

        // 1-Line Live Synced Lyric directly from Zunify
        expLyric = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(4), dp(10), dp(4), dp(6))
            visibility = View.GONE
            setOnClickListener { onAction("openLyrics") }
        }
        expandedCol.addView(
            expLyric,
            LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
        )

        // Hairline Progress Bar
        expProgress = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 1000
            progress = 0
        }
        expandedCol.addView(
            expProgress,
            LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(3)).apply {
                topMargin = dp(8)
                bottomMargin = dp(10)
            }
        )

        // Transport Controls Row: Prev | Play/Pause | Next | Buka Zunify
        val ctrlRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        expPrevBtn = makeControlButton("⏮", 20f) { onAction("prev") }
        expPlayBtn = makeControlButton("▶", 22f) { onAction("playPause") }
        expNextBtn = makeControlButton("⏭", 20f) { onAction("next") }
        expOpenBtn = TextView(context).apply {
            text = "Zunify ↗"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.2f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(dp(10), dp(6), dp(10), dp(6))
            setOnClickListener { onAction("openApp") }
        }

        ctrlRow.addView(expPrevBtn, LinearLayout.LayoutParams(0, dp(38), 1f))
        ctrlRow.addView(expPlayBtn, LinearLayout.LayoutParams(0, dp(42), 1.1f))
        ctrlRow.addView(expNextBtn, LinearLayout.LayoutParams(0, dp(38), 1f))
        ctrlRow.addView(expOpenBtn, LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, dp(34)))
        expandedCol.addView(ctrlRow)

        addView(expandedCol, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        setOnClickListener {
            if (activeTransientEvent != null) {
                activeTransientEvent = null
                refreshLayout(animate = true)
                return@setOnClickListener
            }
            if (!musicState.hasTrack) {
                onAction("openApp")
                return@setOnClickListener
            }
            setExpanded(!isExpanded)
        }

        applyThemeStyling()
        refreshLayout(animate = false)
    }

    private fun makeControlButton(symbol: String, sp: Float, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            text = symbol
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            gravity = Gravity.CENTER
            setOnClickListener {
                animate().scaleX(0.84f).scaleY(0.84f).setDuration(70).withEndAction {
                    animate().scaleX(1f).scaleY(1f).setDuration(140)
                        .setInterpolator(OvershootInterpolator(1.2f)).start()
                }.start()
                onClick()
            }
        }
    }

    fun setExpanded(expand: Boolean) {
        if (isExpanded == expand) return
        isExpanded = expand
        onExpandedChanged(expand)
        refreshLayout(animate = true)
    }

    fun isCurrentlyExpanded(): Boolean = isExpanded

    fun updateThemeMode(themeMode: String) {
        currentTheme = themeMode
        applyThemeStyling()
    }

    fun updateBattery(pct: Int, charging: Boolean) {
        val justPlugged = charging && !isCharging
        batteryPct = pct
        isCharging = charging
        if (justPlugged) {
            showTransientEvent("⚡", "Mengisi daya • $pct%", 0xFF4ADE80.toInt())
        } else if (!musicState.hasTrack && activeTransientEvent == null) {
            refreshLayout(animate = false)
        }
    }

    fun showBluetoothEvent(deviceName: String) {
        val label = if (deviceName.isNotBlank()) deviceName else "Headset Tersambung"
        showTransientEvent("🎧", label, 0xFF60A5FA.toInt())
    }

    private fun showTransientEvent(icon: String, label: String, tint: Int) {
        handler.removeCallbacks(clearTransientRunnable)
        activeTransientEvent = label
        transientIcon.text = icon
        transientIcon.setTextColor(tint)
        transientText.text = label
        refreshLayout(animate = true)
        handler.postDelayed(clearTransientRunnable, 3200L)
    }

    fun updateMusicState(state: LauncherMusicState) {
        val artChanged = state.artUrl != currentArtUrl
        musicState = state
        if (artChanged) {
            currentArtUrl = state.artUrl
            ZunifyLauncherBridge.loadAlbumArt(state.artUrl) { bmp ->
                if (bmp != null) {
                    compactArt.setImageBitmap(bmp)
                    expArt.setImageBitmap(bmp)
                }
            }
        }
        applyThemeStyling()
        refreshLayout(animate = false)
    }

    private fun applyThemeStyling() {
        val isBrutal = currentTheme == "neo_brutalism"
        val isIpod = currentTheme == "classic_ipod"
        val accent = if (isIpod) 0xFF2563EB.toInt() else musicState.accentColor

        val surfaceColor = when {
            isBrutal -> 0xFFFAF4E6.toInt()
            isIpod -> 0xF2F8FAFC.toInt()
            else -> 0xE60B0E18.toInt()
        }
        val strokeColor = when {
            isBrutal -> 0xFF111111.toInt()
            isIpod -> 0xFFCBD5E1.toInt()
            else -> 0x42FFFFFF
        }
        val primaryInk = if (isBrutal || isIpod) 0xFF0F172A.toInt() else Color.WHITE
        val secondaryInk = if (isBrutal || isIpod) 0xFF475569.toInt() else 0xB8FFFFFF.toInt()

        bgDrawable.shape = GradientDrawable.RECTANGLE
        bgDrawable.setColor(surfaceColor)
        bgDrawable.setStroke(dp(if (isBrutal) 2 else 1), strokeColor)
        bgDrawable.cornerRadius = dp(if (isExpanded) (if (isBrutal) 18 else 26) else (if (isBrutal) 14 else 22)).toFloat()

        compactTitle.setTextColor(primaryInk)
        transientText.setTextColor(primaryInk)
        expTitle.setTextColor(primaryInk)
        expArtist.setTextColor(secondaryInk)
        expLyric.setTextColor(if (isBrutal || isIpod) accent else Color.argb(235, Color.red(accent), Color.green(accent), Color.blue(accent)))
        expPrevBtn.setTextColor(primaryInk)
        expNextBtn.setTextColor(primaryInk)
        expPlayBtn.setTextColor(if (isBrutal || isIpod) 0xFF0F172A.toInt() else Color.WHITE)
        expLikeBtn.setTextColor(if (musicState.isFavorite) accent else secondaryInk)
        expOpenBtn.setTextColor(if (isBrutal || isIpod) 0xFF111111.toInt() else Color.WHITE)
        expOpenBtn.background = GradientDrawable().apply {
            setColor(if (isBrutal) accent else Color.argb(36, Color.red(accent), Color.green(accent), Color.blue(accent)))
            cornerRadius = dp(12).toFloat()
        }

        spectrumView.setAccentColor(accent)
        spectrumView.setPlaying(musicState.isPlaying)
        expProgress.progressDrawable?.setTint(accent)
    }

    private fun refreshLayout(animate: Boolean) {
        val showTransient = activeTransientEvent != null && !isExpanded
        val hasTrack = musicState.hasTrack

        compactRow.visibility = if (!isExpanded && !showTransient) View.VISIBLE else View.GONE
        transientRow.visibility = if (showTransient) View.VISIBLE else View.GONE
        expandedCol.visibility = if (isExpanded && hasTrack) View.VISIBLE else View.GONE

        if (!hasTrack) {
            isExpanded = false
            compactArt.visibility = View.GONE
            spectrumView.visibility = View.GONE
            val chargeMark = if (isCharging) "⚡ " else ""
            compactTitle.text = "♪ Zunify  •  $chargeMark$batteryPct%"
            compactTitle.gravity = Gravity.CENTER
        } else {
            compactArt.visibility = View.VISIBLE
            spectrumView.visibility = View.VISIBLE
            compactTitle.text = musicState.title
            compactTitle.gravity = Gravity.START or Gravity.CENTER_VERTICAL
            spectrumView.setPlaying(musicState.isPlaying)

            expTitle.text = musicState.title
            expArtist.text = musicState.artist
            expPlayBtn.text = if (musicState.isPlaying) "⏸" else "▶"
            expLikeBtn.text = if (musicState.isFavorite) "♥" else "♡"

            if (musicState.liveLyric.isNotBlank()) {
                expLyric.visibility = View.VISIBLE
                expLyric.text = "“${musicState.liveLyric}”"
            } else {
                expLyric.visibility = View.GONE
            }

            val progressRatio = if (musicState.durationMs > 0) {
                ((musicState.positionMs * 1000L) / musicState.durationMs).toInt().coerceIn(0, 1000)
            } else 0
            expProgress.progress = progressRatio
        }

        val screenW = resources.displayMetrics.widthPixels
        val targetWidth = when {
            isExpanded && hasTrack -> (screenW - dp(28)).coerceAtMost(dp(380))
            showTransient -> dp(218)
            hasTrack -> dp(212)
            else -> dp(156)
        }

        bgDrawable.cornerRadius = dp(
            if (isExpanded) (if (currentTheme == "neo_brutalism") 18 else 26)
            else (if (currentTheme == "neo_brutalism") 14 else 22)
        ).toFloat()

        val lp = layoutParams
        if (lp != null) {
            if (animate && lp.width > 0 && lp.width != targetWidth) {
                ValueAnimator.ofInt(lp.width, targetWidth).apply {
                    duration = if (isExpanded) 340L else 240L
                    interpolator = if (isExpanded) OvershootInterpolator(0.85f) else DecelerateInterpolator()
                    addUpdateListener { anim ->
                        layoutParams = layoutParams.apply { width = anim.animatedValue as Int }
                    }
                    start()
                }
            } else {
                lp.width = targetWidth
                layoutParams = lp
            }
        }
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacksAndMessages(null)
        spectrumView.setPlaying(false)
        super.onDetachedFromWindow()
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

class SquircleOutlineProvider(private val radiusPx: Float) : ViewOutlineProvider() {
    override fun getOutline(view: View, outline: Outline) {
        outline.setRoundRect(0, 0, view.width, view.height, radiusPx)
    }
}

/** Ultra-lightweight 3-bar live audio spectrum drawn directly on Canvas */
class MiniSpectrumBarView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF5EEAD4.toInt()
        style = Paint.Style.FILL
    }
    private val barRect = RectF()
    private var playing = false
    private var phase = 0.0
    private val ticker = object : Runnable {
        override fun run() {
            if (!playing) return
            phase += 0.24
            invalidate()
            postDelayed(this, 55L)
        }
    }

    fun setAccentColor(color: Int) {
        paint.color = color
        invalidate()
    }

    fun setPlaying(isPlaying: Boolean) {
        if (playing == isPlaying) return
        playing = isPlaying
        removeCallbacks(ticker)
        if (playing) post(ticker) else invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        val barW = w / 5f
        val gaps = (w - barW * 3f) / 2f
        val r = barW / 2f

        for (i in 0..2) {
            val frac = if (playing) {
                (0.32 + 0.65 * ((sin(phase + i * 1.4) + 1.0) * 0.5)).toFloat()
            } else {
                0.28f
            }
            val bh = (h * frac).coerceAtLeast(barW)
            val left = i * (barW + gaps)
            val top = (h - bh) / 2f
            barRect.set(left, top, left + barW, top + bh)
            canvas.drawRoundRect(barRect, r, r, paint)
        }
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(ticker)
        super.onDetachedFromWindow()
    }
}
