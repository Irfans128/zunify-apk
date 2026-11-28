package com.fannz.zunify

import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityOptions
import android.app.AlertDialog
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextUtils
import android.text.TextWatcher
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.GridView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Zunify Built-In Native Android Launcher (1 APK inside Zunify v3.0.0)
 * - 100% Native Kotlin Views (does NOT spin up Flutter engine while on Home Screen -> ~18–28 MB RAM)
 * - System Wallpaper + 10% subtle ambient color aura matching current song album art
 * - Anti-Collision Dynamic Capsule (default: sub-status bar; optional: top camera DisplayCutout or hidden)
 * - 3 Editorial Clock Styles (Minimal Sans / Bold / Retro Mono) + optional Mini Music Card toggle
 * - Uniform iOS-style Squircle App Icons, 4-Icon Label-Free Frosted Glass Dock & 4-Col App Drawer
 * - One-handed gestures: Swipe Up = App Drawer, Swipe Down = Notification Shade, Long-Press = Settings
 */
class ZunifyLauncherActivity : Activity() {

    private data class AppEntry(
        val label: String,
        val packageName: String,
        val activityName: String,
        val squircleIcon: Bitmap,
    )

    private lateinit var prefs: SharedPreferences
    private val bgExecutor = Executors.newSingleThreadExecutor()

    private lateinit var rootFrame: FrameLayout
    private lateinit var ambientOverlay: View
    private lateinit var homeColumn: LinearLayout
    private lateinit var capsuleHolder: FrameLayout
    private lateinit var capsuleView: DynamicCapsuleView
    private lateinit var clockText: TextView
    private lateinit var dateText: TextView
    private lateinit var miniMusicCard: LinearLayout
    private lateinit var miniCardArt: ImageView
    private lateinit var miniCardTitle: TextView
    private lateinit var miniCardArtist: TextView
    private lateinit var miniCardPlay: TextView
    private lateinit var dockContainer: LinearLayout
    private lateinit var drawerOverlay: LinearLayout
    private lateinit var drawerSearch: EditText
    private lateinit var drawerGrid: GridView

    private var allApps: List<AppEntry> = emptyList()
    private var filteredApps: List<AppEntry> = emptyList()
    private var dockPackages: MutableList<String> = mutableListOf()
    private var drawerAdapter: AppGridAdapter? = null

    private var capsuleMode: String = "sub_status" // sub_status | top_camera | hidden
    private var clockStyle: String = "minimal"     // minimal | bold | mono
    private var launcherTheme: String = "sync"     // sync | liquid_glass | neo_brutalism | classic_ipod
    private var showMiniCard: Boolean = false
    private var isDrawerOpen: Boolean = false
    private var isPreviewMode: Boolean = false
    private var statusBarHeightPx: Int = 0
    private var navBarBottomPx: Int = 0
    private var cutoutTopPx: Int = 0
    private var previewBanner: TextView? = null

    private lateinit var gestureDetector: GestureDetector

    private val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    private val dateFormat = SimpleDateFormat("EEEE, d MMM", Locale("id", "ID"))

    private val musicListener: (LauncherMusicState) -> Unit = { state ->
        applyMusicState(state)
    }

    private val systemReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_TIME_TICK, Intent.ACTION_TIME_CHANGED, Intent.ACTION_DATE_CHANGED -> {
                    refreshClockAndDate()
                }
                Intent.ACTION_BATTERY_CHANGED -> {
                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                    val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                    val pct = if (level >= 0 && scale > 0) (level * 100) / scale else 100
                    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL
                    capsuleView.updateBattery(pct, charging)
                }
                Intent.ACTION_POWER_CONNECTED -> {
                    capsuleView.updateBattery(readCurrentBatteryPct(), true)
                }
                Intent.ACTION_HEADSET_PLUG -> {
                    if (intent.getIntExtra("state", 0) == 1) {
                        capsuleView.showBluetoothEvent("Headset Kabel")
                    }
                }
                BluetoothDevice.ACTION_ACL_CONNECTED -> {
                    @Suppress("DEPRECATION")
                    val dev = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    val name = try {
                        dev?.name ?: "Bluetooth Audio"
                    } catch (_: SecurityException) {
                        "Perangkat Bluetooth"
                    }
                    capsuleView.showBluetoothEvent(name)
                }
                BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED -> {
                    val connState = intent.getIntExtra(BluetoothAdapter.EXTRA_CONNECTION_STATE, 0)
                    if (connState == BluetoothAdapter.STATE_CONNECTED) {
                        capsuleView.showBluetoothEvent("Bluetooth Tersambung")
                    }
                }
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge-to-edge transparent window so system wallpaper renders natively underneath
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )

        prefs = getSharedPreferences("zunify_launcher_prefs", Context.MODE_PRIVATE)
        isPreviewMode = intent?.getBooleanExtra("zunify_preview_mode", false) == true
        loadLauncherPrefs()
        statusBarHeightPx = resolveStatusBarHeight()
        navBarBottomPx = resolveNavBarHeight()

        buildRootUi()
        setContentView(rootFrame)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            rootFrame.setOnApplyWindowInsetsListener { _, insets ->
                val cutout = insets.displayCutout
                cutoutTopPx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    cutout?.boundingRectTop?.top ?: 0
                } else {
                    0
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val sysBars = insets.getInsets(WindowInsets.Type.systemBars())
                    statusBarHeightPx = sysBars.top.coerceAtLeast(resolveStatusBarHeight())
                    navBarBottomPx = sysBars.bottom
                } else {
                    @Suppress("DEPRECATION")
                    statusBarHeightPx = insets.systemWindowInsetTop.coerceAtLeast(resolveStatusBarHeight())
                    @Suppress("DEPRECATION")
                    navBarBottomPx = insets.systemWindowInsetBottom
                }
                homeColumn.setPadding(dp(18), 0, dp(18), navBarBottomPx + dp(18))
                drawerOverlay.setPadding(dp(16), statusBarHeightPx + dp(14), dp(16), navBarBottomPx + dp(18))
                updateCapsulePlacement()
                insets
            }
        }

        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onFling(
                e1: MotionEvent?,
                e2: MotionEvent,
                velocityX: Float,
                velocityY: Float
            ): Boolean {
                if (e1 == null || isDrawerOpen) return false
                val dy = e2.y - e1.y
                val dx = e2.x - e1.x
                if (kotlin.math.abs(dy) > kotlin.math.abs(dx) * 1.2f) {
                    if (dy < -dp(54) && velocityY < -350f) {
                        openAppDrawer()
                        return true
                    } else if (dy > dp(54) && velocityY > 350f) {
                        expandNotificationShade()
                        return true
                    }
                }
                return false
            }

            override fun onLongPress(e: MotionEvent) {
                if (!isDrawerOpen) {
                    showLauncherSettingsDialog()
                }
            }

            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                if (capsuleView.isCurrentlyExpanded()) {
                    capsuleView.setExpanded(false)
                    return true
                }
                return false
            }
        })

        homeColumn.setOnTouchListener { _, ev ->
            gestureDetector.onTouchEvent(ev)
            true
        }

        registerReceivers()
        ZunifyLauncherBridge.addListener(musicListener)
        refreshClockAndDate()
        loadInstalledAppsAsync()
    }

    private fun buildRootUi() {
        rootFrame = FrameLayout(this)

        // 10% Ambient Album Glow Scrim over System Wallpaper (per user preference A2)
        ambientOverlay = View(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
        }
        rootFrame.addView(ambientOverlay, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))

        // Main Home Screen Column (1 clean page)
        homeColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(18), 0, dp(18), navBarBottomPx + dp(18))
        }

        // Dynamic Capsule Slot
        capsuleHolder = FrameLayout(this).apply {
            clipChildren = false
            clipToPadding = false
        }
        capsuleView = DynamicCapsuleView(
            context = this,
            onAction = { action -> ZunifyLauncherBridge.dispatchAction(this, action) },
            onExpandedChanged = { /* Smooth spring expansion handled internally */ }
        )
        capsuleHolder.addView(
            capsuleView,
            FrameLayout.LayoutParams(dp(170), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_HORIZONTAL)
        )
        homeColumn.addView(
            capsuleHolder,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        // Editorial Clock + Date
        clockText = TextView(this).apply {
            text = "12:30"
            setTextColor(Color.WHITE)
            setShadowLayer(12f, 0f, 3f, 0x55000000)
            gravity = Gravity.CENTER
        }
        homeColumn.addView(
            clockText,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(24) }
        )

        dateText = TextView(this).apply {
            text = "Sabtu, 28 Nov"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            setTextColor(0xE6FFFFFF.toInt())
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setShadowLayer(8f, 0f, 2f, 0x55000000)
            gravity = Gravity.CENTER
        }
        homeColumn.addView(
            dateText,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(2) }
        )

        // Optional Mini Music Card (OFF by default per A3, toggleable in Launcher Settings)
        miniMusicCard = buildOptionalMiniMusicCard()
        homeColumn.addView(
            miniMusicCard,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(22)
                leftMargin = dp(6)
                rightMargin = dp(6)
            }
        )

        // Clean Open Wallpaper Spacer
        homeColumn.addView(
            View(this),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        )

        // Subtle Preview-Only Exit Pill (only visible when opened via Settings -> Pratinjau)
        if (isPreviewMode) {
            previewBanner = TextView(this).apply {
                text = "Pratinjau Launcher • Tahan layar utk atur • Tutup ✕"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.2f)
                setTextColor(Color.WHITE)
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(dp(14), dp(7), dp(14), dp(7))
                background = GradientDrawable().apply {
                    setColor(0xBB0B0F1A.toInt())
                    setStroke(dp(1), 0x44FFFFFF)
                    cornerRadius = dp(18).toFloat()
                }
                setOnClickListener { finish() }
            }
            homeColumn.addView(
                previewBanner,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dp(12) }
            )
        }

        // Subtle "Geser atas" Drawer Hint Pill
        val drawerHint = View(this).apply {
            background = GradientDrawable().apply {
                setColor(0x66FFFFFF)
                cornerRadius = dp(4).toFloat()
            }
            setOnClickListener { openAppDrawer() }
        }
        homeColumn.addView(
            drawerHint,
            LinearLayout.LayoutParams(dp(36), dp(4)).apply { bottomMargin = dp(14) }
        )

        // 4-Icon Label-Free iOS Squircle Frosted Glass Dock
        dockContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(10))
            elevation = dp(8).toFloat()
        }
        homeColumn.addView(
            dockContainer,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(18)
            }
        )

        rootFrame.addView(
            homeColumn,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        // App Drawer Overlay (4-Column Squircle Grid + Instant Search)
        drawerOverlay = buildAppDrawerOverlay()
        rootFrame.addView(
            drawerOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        applyClockStyle()
        applyThemeChrome()
        updateCapsulePlacement()
        updateMiniCardVisibility()
    }

    private fun buildOptionalMiniMusicCard(): LinearLayout {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
            visibility = View.GONE
            setOnClickListener { ZunifyLauncherBridge.dispatchAction(this@ZunifyLauncherActivity, "openApp") }
        }
        miniCardArt = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = SquircleOutlineProvider(dp(10).toFloat())
            setBackgroundColor(0xFF1E293B.toInt())
        }
        card.addView(miniCardArt, LinearLayout.LayoutParams(dp(44), dp(44)))

        val textCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), 0, dp(8), 0)
        }
        miniCardTitle = TextView(this).apply {
            text = "Zunify Music"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        miniCardArtist = TextView(this).apply {
            text = "Ketuk untuk putar musik"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.8f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        textCol.addView(miniCardTitle)
        textCol.addView(miniCardArtist)
        card.addView(textCol, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        miniCardPlay = TextView(this).apply {
            text = "▶"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            gravity = Gravity.CENTER
            setOnClickListener { ZunifyLauncherBridge.dispatchAction(this@ZunifyLauncherActivity, "playPause") }
        }
        card.addView(miniCardPlay, LinearLayout.LayoutParams(dp(38), dp(38)))
        return card
    }

    private fun buildAppDrawerOverlay(): LinearLayout {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xEE090C14.toInt())
            setPadding(dp(16), statusBarHeightPx + dp(14), dp(16), dp(22))
            visibility = View.GONE
            alpha = 0f
        }

        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        drawerSearch = EditText(this).apply {
            hint = "Cari aplikasi..."
            setHintTextColor(0x88FFFFFF.toInt())
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f)
            isSingleLine = true
            setPadding(dp(16), dp(11), dp(16), dp(11))
            background = GradientDrawable().apply {
                setColor(0x20FFFFFF)
                cornerRadius = dp(22).toFloat()
                setStroke(dp(1), 0x33FFFFFF)
            }
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    filterDrawerApps(s?.toString() ?: "")
                }
                override fun afterTextChanged(s: Editable?) {}
            })
        }
        topRow.addView(drawerSearch, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(0xCCFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            gravity = Gravity.CENTER
            setOnClickListener { closeAppDrawer() }
        }
        topRow.addView(closeBtn, LinearLayout.LayoutParams(dp(42), dp(42)).apply { leftMargin = dp(8) })
        container.addView(topRow)

        drawerGrid = GridView(this).apply {
            numColumns = 4
            verticalSpacing = dp(16)
            horizontalSpacing = dp(8)
            isVerticalScrollBarEnabled = false
            setPadding(0, dp(16), 0, dp(24))
            clipToPadding = false
        }
        container.addView(
            drawerGrid,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        )

        return container
    }

    private fun effectiveThemeMode(): String {
        return if (launcherTheme == "sync") ZunifyLauncherBridge.currentState.themeMode else launcherTheme
    }

    private fun applyClockStyle() {
        when (clockStyle) {
            "bold" -> {
                clockText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 68f)
                clockText.typeface = Typeface.create("sans-serif-black", Typeface.BOLD)
                clockText.letterSpacing = -0.04f
            }
            "mono" -> {
                clockText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 58f)
                clockText.typeface = Typeface.MONOSPACE
                clockText.letterSpacing = 0.02f
            }
            else -> {
                clockText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
                clockText.typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
                clockText.letterSpacing = -0.02f
            }
        }
    }

    private fun applyThemeChrome() {
        val mode = effectiveThemeMode()
        capsuleView.updateThemeMode(mode)

        val isBrutal = mode == "neo_brutalism"
        val isIpod = mode == "classic_ipod"

        dockContainer.background = GradientDrawable().apply {
            setColor(
                when {
                    isBrutal -> 0xF2FAF4E6.toInt()
                    isIpod -> 0xE6F1F5F9.toInt()
                    else -> 0x80101524.toInt()
                }
            )
            setStroke(
                dp(if (isBrutal) 2 else 1),
                when {
                    isBrutal -> 0xFF111111.toInt()
                    isIpod -> 0xFFCBD5E1.toInt()
                    else -> 0x38FFFFFF
                }
            )
            cornerRadius = dp(if (isBrutal) 18 else 28).toFloat()
        }

        val cardInk = if (isBrutal || isIpod) 0xFF0F172A.toInt() else Color.WHITE
        val cardSub = if (isBrutal || isIpod) 0xFF475569.toInt() else 0xB8FFFFFF.toInt()
        miniMusicCard.background = GradientDrawable().apply {
            setColor(
                when {
                    isBrutal -> 0xF2FAF4E6.toInt()
                    isIpod -> 0xEAF8FAFC.toInt()
                    else -> 0x990D1220.toInt()
                }
            )
            setStroke(
                dp(if (isBrutal) 2 else 1),
                when {
                    isBrutal -> 0xFF111111.toInt()
                    isIpod -> 0xFFCBD5E1.toInt()
                    else -> 0x33FFFFFF
                }
            )
            cornerRadius = dp(if (isBrutal) 14 else 22).toFloat()
        }
        miniCardTitle.setTextColor(cardInk)
        miniCardArtist.setTextColor(cardSub)
        miniCardPlay.setTextColor(cardInk)

        drawerOverlay.setBackgroundColor(
            when {
                isBrutal -> 0xF7FAF4E6.toInt()
                isIpod -> 0xF5F1F5F9.toInt()
                else -> 0xEE090C14.toInt()
            }
        )
        val drawerInk = if (isBrutal || isIpod) 0xFF0F172A.toInt() else Color.WHITE
        drawerSearch.setTextColor(drawerInk)
        drawerSearch.setHintTextColor(if (isBrutal || isIpod) 0xFF64748B.toInt() else 0x88FFFFFF.toInt())
        drawerAdapter?.notifyDataSetChanged()
    }

    private fun updateCapsulePlacement() {
        val lp = capsuleHolder.layoutParams as? LinearLayout.LayoutParams ?: return
        when (capsuleMode) {
            "hidden" -> {
                capsuleHolder.visibility = View.GONE
                lp.topMargin = statusBarHeightPx + dp(12)
            }
            "top_camera" -> {
                capsuleHolder.visibility = View.VISIBLE
                lp.topMargin = if (cutoutTopPx > 0) cutoutTopPx + dp(4) else dp(10)
            }
            else -> {
                // Default 'sub_status': sits ~10dp cleanly below status bar -> 100% anti-collision!
                capsuleHolder.visibility = View.VISIBLE
                lp.topMargin = statusBarHeightPx + dp(10)
            }
        }
        capsuleHolder.layoutParams = lp
    }

    private fun updateMiniCardVisibility() {
        miniMusicCard.visibility = if (showMiniCard) View.VISIBLE else View.GONE
    }

    private fun applyMusicState(state: LauncherMusicState) {
        capsuleView.updateMusicState(state)
        if (launcherTheme == "sync") {
            applyThemeChrome()
        }

        // Subtle ~10% Ambient Album Glow over real system wallpaper when music is active
        if (state.hasTrack && state.isPlaying) {
            val c = state.ambientColor
            val tint = Color.argb(30, Color.red(c), Color.green(c), Color.blue(c))
            ambientOverlay.background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(tint, Color.TRANSPARENT, tint)
            )
        } else {
            ambientOverlay.setBackgroundColor(Color.TRANSPARENT)
        }

        if (state.hasTrack) {
            miniCardTitle.text = state.title
            miniCardArtist.text = state.artist
            miniCardPlay.text = if (state.isPlaying) "⏸" else "▶"
            ZunifyLauncherBridge.loadAlbumArt(state.artUrl) { bmp ->
                if (bmp != null) miniCardArt.setImageBitmap(bmp)
            }
        }
    }

    private fun refreshClockAndDate() {
        val now = Date()
        clockText.text = timeFormat.format(now)
        dateText.text = dateFormat.format(now)
    }

    private fun loadInstalledAppsAsync() {
        bgExecutor.execute {
            val pm = packageManager
            val queryIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val resolved = pm.queryIntentActivities(queryIntent, 0)
            val iconPx = dp(52)
            val entries = resolved.mapNotNull { ri ->
                try {
                    val pkg = ri.activityInfo.packageName
                    val act = ri.activityInfo.name
                    val label = ri.loadLabel(pm)?.toString() ?: pkg
                    val drawable = ri.loadIcon(pm)
                    val squircleBmp = renderUniformSquircleIcon(drawable, iconPx)
                    AppEntry(label, pkg, act, squircleBmp)
                } catch (_: Exception) {
                    null
                }
            }.sortedBy { it.label.lowercase(Locale.getDefault()) }

            runOnUiThread {
                allApps = entries
                filteredApps = entries
                if (dockPackages.isEmpty()) {
                    initDefaultDock(entries)
                }
                rebuildDockViews()
                drawerAdapter = AppGridAdapter()
                drawerGrid.adapter = drawerAdapter
            }
        }
    }

    /** Wraps every app icon into a uniform smooth iOS-style Squircle bitmap */
    private fun renderUniformSquircleIcon(drawable: Drawable, sizePx: Int): Bitmap {
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val radius = sizePx * 0.24f
        val rect = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
        val clipPath = Path().apply {
            addRoundRect(rect, radius, radius, Path.Direction.CW)
        }
        canvas.save()
        canvas.clipPath(clipPath)
        // Clean soft white base so transparent icons still have crisp uniform squircle shape
        canvas.drawColor(0xF0FFFFFF.toInt())
        val inset = (sizePx * 0.04f).toInt()
        drawable.setBounds(inset, inset, sizePx - inset, sizePx - inset)
        drawable.draw(canvas)
        canvas.restore()

        // Subtle glass border edge around squircle
        val rim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1).toFloat()
            color = 0x22000000
        }
        canvas.drawRoundRect(rect, radius, radius, rim)
        return out
    }

    private fun initDefaultDock(apps: List<AppEntry>) {
        val picks = mutableListOf<String>()
        // Always include Zunify in dock by default!
        if (apps.any { it.packageName == packageName }) {
            picks.add(packageName)
        }
        val preferredHints = listOf("whatsapp", "chrome", "browser", "camera", "dialer", "phone", "messaging", "gallery")
        for (hint in preferredHints) {
            if (picks.size >= 4) break
            val match = apps.firstOrNull {
                !picks.contains(it.packageName) &&
                    (it.packageName.lowercase().contains(hint) || it.label.lowercase().contains(hint))
            }
            if (match != null) picks.add(match.packageName)
        }
        for (app in apps) {
            if (picks.size >= 4) break
            if (!picks.contains(app.packageName)) picks.add(app.packageName)
        }
        dockPackages = picks
        saveDockPrefs()
    }

    private fun rebuildDockViews() {
        dockContainer.removeAllViews()
        val dockApps = dockPackages.mapNotNull { pkg -> allApps.firstOrNull { it.packageName == pkg } }.take(4)
        for ((slotIdx, app) in dockApps.withIndex()) {
            val slot = FrameLayout(this).apply {
                setPadding(dp(8), dp(4), dp(8), dp(4))
            }
            val iv = ImageView(this).apply {
                setImageBitmap(app.squircleIcon)
                scaleType = ImageView.ScaleType.FIT_CENTER
                setOnClickListener { v -> launchAppWithScale(app, v) }
                setOnLongClickListener {
                    showSwapDockAppDialog(slotIdx)
                    true
                }
            }
            slot.addView(iv, FrameLayout.LayoutParams(dp(50), dp(50), Gravity.CENTER))
            dockContainer.addView(
                slot,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            )
        }
    }

    private fun launchAppWithScale(app: AppEntry, sourceView: View) {
        sourceView.animate().scaleX(0.88f).scaleY(0.88f).setDuration(80).withEndAction {
            sourceView.animate().scaleX(1f).scaleY(1f).setDuration(140)
                .setInterpolator(OvershootInterpolator(1.1f)).start()
            try {
                val launchIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    setClassName(app.packageName, app.activityName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                }
                val opts = ActivityOptions.makeScaleUpAnimation(
                    sourceView, 0, 0, sourceView.width, sourceView.height
                )
                startActivity(launchIntent, opts.toBundle())
                if (isDrawerOpen) closeAppDrawer()
            } catch (_: Exception) {}
        }.start()
    }

    private fun openAppDrawer() {
        if (isDrawerOpen) return
        isDrawerOpen = true
        drawerOverlay.visibility = View.VISIBLE
        drawerOverlay.translationY = dp(48).toFloat()
        drawerOverlay.alpha = 0f
        drawerOverlay.animate()
            .translationY(0f)
            .alpha(1f)
            .setDuration(220L)
            .setInterpolator(DecelerateInterpolator())
            .start()
    }

    private fun closeAppDrawer() {
        if (!isDrawerOpen) return
        isDrawerOpen = false
        drawerSearch.setText("")
        drawerOverlay.animate()
            .translationY(dp(40).toFloat())
            .alpha(0f)
            .setDuration(170L)
            .withEndAction { drawerOverlay.visibility = View.GONE }
            .start()
    }

    private fun filterDrawerApps(query: String) {
        val clean = query.trim().lowercase(Locale.getDefault())
        filteredApps = if (clean.isEmpty()) {
            allApps
        } else {
            allApps.filter { it.label.lowercase(Locale.getDefault()).contains(clean) }
        }
        drawerAdapter?.notifyDataSetChanged()
    }

    private fun showSwapDockAppDialog(slotIdx: Int) {
        if (allApps.isEmpty()) return
        val names = allApps.map { it.label }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle("Pilih Aplikasi untuk Dock #${slotIdx + 1}")
            .setItems(names) { _, which ->
                val chosen = allApps[which].packageName
                if (slotIdx < dockPackages.size) {
                    dockPackages[slotIdx] = chosen
                } else {
                    dockPackages.add(chosen)
                }
                saveDockPrefs()
                rebuildDockViews()
            }
            .setNegativeButton("Batal", null)
            .show()
    }

    private fun showLauncherSettingsDialog() {
        val items = arrayOf(
            "Posisi Dynamic Capsule (${capsuleLabel()})",
            "Gaya Jam Editorial (${clockLabel()})",
            "Tema Launcher (${themeLabel()})",
            "Mini Music Card di Home (${if (showMiniCard) "Aktif" else "Mati"})",
            "Ganti Wallpaper HP",
            "Buka Pengaturan Home Default Android",
            "Buka Zunify Music"
        )
        AlertDialog.Builder(this)
            .setTitle("Pengaturan Zunify Launcher")
            .setItems(items) { _, which ->
                when (which) {
                    0 -> pickCapsulePosition()
                    1 -> pickClockStyle()
                    2 -> pickLauncherTheme()
                    3 -> {
                        showMiniCard = !showMiniCard
                        prefs.edit().putBoolean("show_mini_card", showMiniCard).apply()
                        updateMiniCardVisibility()
                    }
                    4 -> {
                        try {
                            startActivity(Intent(Intent.ACTION_SET_WALLPAPER))
                        } catch (_: Exception) {}
                    }
                    5 -> ZunifyLauncherBridge.openHomeSettingsPicker(this)
                    6 -> ZunifyLauncherBridge.dispatchAction(this, "openApp")
                }
            }
            .setNegativeButton("Tutup", null)
            .show()
    }

    private fun pickCapsulePosition() {
        val labels = arrayOf("Bawah Status Bar (Anti-Nabrak)", "Atas Kamera Depan", "Sembunyikan Pil")
        val keys = arrayOf("sub_status", "top_camera", "hidden")
        AlertDialog.Builder(this)
            .setTitle("Posisi Dynamic Capsule")
            .setItems(labels) { _, i ->
                capsuleMode = keys[i]
                prefs.edit().putString("capsule_mode", capsuleMode).apply()
                updateCapsulePlacement()
            }
            .show()
    }

    private fun pickClockStyle() {
        val labels = arrayOf("Minimal Sans", "Bold Editorial", "Retro Mono")
        val keys = arrayOf("minimal", "bold", "mono")
        AlertDialog.Builder(this)
            .setTitle("Gaya Jam Editorial")
            .setItems(labels) { _, i ->
                clockStyle = keys[i]
                prefs.edit().putString("clock_style", clockStyle).apply()
                applyClockStyle()
            }
            .show()
    }

    private fun pickLauncherTheme() {
        val labels = arrayOf("Ikuti Tema Zunify", "Liquid Glass", "Neo-Brutalism", "Classic iPod")
        val keys = arrayOf("sync", "liquid_glass", "neo_brutalism", "classic_ipod")
        AlertDialog.Builder(this)
            .setTitle("Tema Zunify Launcher")
            .setItems(labels) { _, i ->
                launcherTheme = keys[i]
                prefs.edit().putString("launcher_theme", launcherTheme).apply()
                applyThemeChrome()
            }
            .show()
    }

    private fun capsuleLabel(): String = when (capsuleMode) {
        "top_camera" -> "Atas Kamera"
        "hidden" -> "Sembunyi"
        else -> "Bawah Status Bar"
    }

    private fun clockLabel(): String = when (clockStyle) {
        "bold" -> "Bold"
        "mono" -> "Retro Mono"
        else -> "Minimal Sans"
    }

    private fun themeLabel(): String = when (launcherTheme) {
        "liquid_glass" -> "Liquid Glass"
        "neo_brutalism" -> "Neo-Brutalism"
        "classic_ipod" -> "Classic iPod"
        else -> "Ikuti Zunify"
    }

    private fun loadLauncherPrefs() {
        capsuleMode = prefs.getString("capsule_mode", "sub_status") ?: "sub_status"
        clockStyle = prefs.getString("clock_style", "minimal") ?: "minimal"
        launcherTheme = prefs.getString("launcher_theme", "sync") ?: "sync"
        showMiniCard = prefs.getBoolean("show_mini_card", false)
        val savedDock = prefs.getString("dock_packages", "") ?: ""
        dockPackages = savedDock.split(",").filter { it.isNotBlank() }.toMutableList()
    }

    private fun saveDockPrefs() {
        prefs.edit().putString("dock_packages", dockPackages.joinToString(",")).apply()
    }

    @SuppressLint("WrongConstant")
    private fun expandNotificationShade() {
        try {
            val sbService = getSystemService("statusbar") ?: return
            val sbManager = Class.forName("android.app.StatusBarManager")
            val method = sbManager.getMethod("expandNotificationsPanel")
            method.invoke(sbService)
        } catch (_: Exception) {}
    }

    private fun readCurrentBatteryPct(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        return bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)?.coerceIn(0, 100) ?: 100
    }

    private fun resolveStatusBarHeight(): Int {
        val resId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else dp(28)
    }

    private fun resolveNavBarHeight(): Int {
        val resId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else dp(18)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val nextPreview = intent.getBooleanExtra("zunify_preview_mode", false)
        if (nextPreview != isPreviewMode) {
            isPreviewMode = nextPreview
            previewBanner?.visibility = if (isPreviewMode) View.VISIBLE else View.GONE
        }
    }

    private fun registerReceivers() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_TICK)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_HEADSET_PLUG)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(systemReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(systemReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (isDrawerOpen) {
            closeAppDrawer()
        } else if (capsuleView.isCurrentlyExpanded()) {
            capsuleView.setExpanded(false)
        } else if (isPreviewMode || !isTaskRoot) {
            finish()
        }
    }

    override fun onDestroy() {
        ZunifyLauncherBridge.removeListener(musicListener)
        try {
            unregisterReceiver(systemReceiver)
        } catch (_: Exception) {}
        try {
            bgExecutor.shutdownNow()
        } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private inner class AppGridAdapter : BaseAdapter() {
        override fun getCount(): Int = filteredApps.size
        override fun getItem(position: Int): Any = filteredApps[position]
        override fun getItemId(position: Int): Long = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val app = filteredApps[position]
            val mode = effectiveThemeMode()
            val labelInk = if (mode == "neo_brutalism" || mode == "classic_ipod") {
                0xFF0F172A.toInt()
            } else {
                Color.WHITE
            }

            val cell = (convertView as? LinearLayout) ?: LinearLayout(this@ZunifyLauncherActivity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(4), dp(6), dp(4), dp(6))
                val iv = ImageView(this@ZunifyLauncherActivity).apply {
                    id = android.R.id.icon
                    scaleType = ImageView.ScaleType.FIT_CENTER
                }
                addView(iv, LinearLayout.LayoutParams(dp(50), dp(50)))
                val tv = TextView(this@ZunifyLauncherActivity).apply {
                    id = android.R.id.text1
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.2f)
                    typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    gravity = Gravity.CENTER
                    setPadding(dp(2), dp(6), dp(2), 0)
                }
                addView(tv, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            }

            val iv = cell.findViewById<ImageView>(android.R.id.icon)
            val tv = cell.findViewById<TextView>(android.R.id.text1)
            iv.setImageBitmap(app.squircleIcon)
            tv.text = app.label
            tv.setTextColor(labelInk)

            cell.setOnClickListener { launchAppWithScale(app, iv) }
            cell.setOnLongClickListener {
                AlertDialog.Builder(this@ZunifyLauncherActivity)
                    .setTitle(app.label)
                    .setItems(arrayOf("Pasang ke Dock #1", "Pasang ke Dock #2", "Pasang ke Dock #3", "Pasang ke Dock #4")) { _, slot ->
                        while (dockPackages.size <= slot) dockPackages.add(packageName)
                        dockPackages[slot] = app.packageName
                        saveDockPrefs()
                        rebuildDockViews()
                    }
                    .show()
                true
            }
            return cell
        }
    }
}
