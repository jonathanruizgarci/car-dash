package __PACKAGE__

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.WindowManager
import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.SystemClock
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

@SuppressLint("MissingPermission", "ClickableViewAccessibility")
class MainActivity : FlutterActivity() {
    private val channelName = "autopanel/native"
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var socket: BluetoothSocket? = null
    private var input: InputStream? = null
    private var output: OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val intent = packageManager.getLaunchIntentForPackage(pkg)
                    if (intent != null) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "openUri" -> {
                    try {
                        val uri = call.argument<String>("uri") ?: ""
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "mediaKey" -> {
                    media(call.argument<String>("key") ?: "play")
                    result.success(true)
                }
                "hasNotifAccess" -> result.success(hasNotifAccess())
                "openNotifSettings" -> {
                    try {
                        val i = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                    } catch (e: Exception) {
                    }
                    result.success(true)
                }
                "canOverlay" -> result.success(canOverlay())
                "openOverlaySettings" -> {
                    try {
                        val i = Intent(
                            android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                    } catch (e: Exception) {
                    }
                    result.success(true)
                }
                "showOverlay" -> {
                    showOverlay()
                    result.success(overlay != null)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                "nowPlaying" -> {
                    val c = controller()
                    if (c == null) {
                        result.success(null)
                    } else {
                        val md = c.metadata
                        val st = c.playbackState
                        val map = HashMap<String, Any?>()
                        map["title"] = md?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
                        map["artist"] = md?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                            ?: (md?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST) ?: "")
                        map["album"] = md?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
                        map["duration"] = md?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
                        map["position"] = livePosition(st)
                        map["playing"] = st?.state == PlaybackState.STATE_PLAYING
                        map["package"] = c.packageName
                        result.success(map)
                    }
                }
                "nowPlayingArt" -> {
                    val bmp = artOf(controller())
                    if (bmp == null) {
                        result.success(null)
                    } else {
                        val out = ByteArrayOutputStream()
                        bmp.compress(Bitmap.CompressFormat.JPEG, 88, out)
                        result.success(out.toByteArray())
                    }
                }
                "isMusicActive" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(am.isMusicActive)
                }
                "keepScreenOn" -> {
                    val on = call.argument<Boolean>("on") ?: true
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                "hasBtPermission" -> result.success(hasBtPermission())
                "requestBtPermission" -> {
                    if (Build.VERSION.SDK_INT >= 31) {
                        requestPermissions(
                            arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN),
                            7001
                        )
                    }
                    result.success(true)
                }
                "bondedDevices" -> {
                    try {
                        val mgr = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                        val adapter = mgr.adapter
                        val list = ArrayList<Map<String, String>>()
                        if (adapter != null) {
                            for (d in adapter.bondedDevices) {
                                list.add(mapOf("name" to (d.name ?: "Sin nombre"), "address" to d.address))
                            }
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("BT", e.message, null)
                    }
                }
                "obdConnect" -> {
                    val address = call.argument<String>("address") ?: ""
                    executor.execute {
                        try {
                            closeSocket()
                            val mgr = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                            val adapter = mgr.adapter ?: throw IllegalStateException("Este equipo no tiene Bluetooth")
                            try {
                                adapter.cancelDiscovery()
                            } catch (e: Exception) {
                            }
                            val device = adapter.getRemoteDevice(address)
                            var s: BluetoothSocket = device.createRfcommSocketToServiceRecord(sppUuid)
                            try {
                                s.connect()
                            } catch (e: Exception) {
                                try {
                                    s.close()
                                } catch (ignored: Exception) {
                                }
                                s = device.createInsecureRfcommSocketToServiceRecord(sppUuid)
                                s.connect()
                            }
                            socket = s
                            input = s.inputStream
                            output = s.outputStream
                            mainHandler.post { result.success(true) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("BT", e.message ?: "No se pudo conectar", null) }
                        }
                    }
                }
                "obdSend" -> {
                    val cmd = call.argument<String>("cmd") ?: ""
                    val timeout = call.argument<Int>("timeout") ?: 2000
                    executor.execute {
                        try {
                            val out = output ?: throw IllegalStateException("Adaptador no conectado")
                            val inp = input ?: throw IllegalStateException("Adaptador no conectado")
                            while (inp.available() > 0) {
                                inp.read()
                            }
                            out.write((cmd + "\r").toByteArray())
                            out.flush()
                            val sb = StringBuilder()
                            val deadline = System.currentTimeMillis() + timeout
                            while (System.currentTimeMillis() < deadline) {
                                if (inp.available() > 0) {
                                    val c = inp.read()
                                    if (c < 0) break
                                    val ch = c.toChar()
                                    if (ch == '>') break
                                    sb.append(ch)
                                } else {
                                    Thread.sleep(8)
                                }
                            }
                            val text = sb.toString()
                            mainHandler.post { result.success(text) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("BT", e.message ?: "Error de comunicación", null) }
                        }
                    }
                }
                "obdDisconnect" -> {
                    executor.execute {
                        closeSocket()
                        mainHandler.post { result.success(true) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ---------- Música (MediaSession) ----------

    private fun hasNotifAccess(): Boolean {
        val flat = android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        return flat.contains(packageName)
    }

    private fun controller(): MediaController? {
        if (!hasNotifAccess()) return null
        return try {
            val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            val list = msm.getActiveSessions(ComponentName(this, MediaListener::class.java))
            list.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING } ?: list.firstOrNull()
        } catch (e: Exception) {
            null
        }
    }

    private fun livePosition(st: PlaybackState?): Long {
        if (st == null) return 0L
        if (st.state != PlaybackState.STATE_PLAYING) return st.position
        val elapsed = SystemClock.elapsedRealtime() - st.lastPositionUpdateTime
        return st.position + (elapsed * st.playbackSpeed).toLong()
    }

    private fun artOf(c: MediaController?): Bitmap? {
        val md = c?.metadata ?: return null
        val bmp = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: md.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: md.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
            ?: return null
        val max = 360
        if (bmp.width <= max && bmp.height <= max) return bmp
        val scale = max.toFloat() / maxOf(bmp.width, bmp.height)
        return Bitmap.createScaledBitmap(bmp, (bmp.width * scale).toInt(), (bmp.height * scale).toInt(), true)
    }

    private fun media(key: String) {
        val c = controller()
        if (c != null) {
            val t = c.transportControls
            when (key) {
                "next" -> t.skipToNext()
                "prev" -> t.skipToPrevious()
                else -> {
                    if (c.playbackState?.state == PlaybackState.STATE_PLAYING) t.pause() else t.play()
                }
            }
            return
        }
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val code = when (key) {
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
        }
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
    }

    // ---------- Reproductor flotante sobre Waze / Maps ----------

    private var overlay: View? = null
    private var ovArt: ImageView? = null
    private var ovTitle: TextView? = null
    private var ovArtist: TextView? = null
    private var ovPlay: ImageButton? = null
    private var ovKey: String = ""
    private val overlayTick = object : Runnable {
        override fun run() {
            updateOverlay()
            mainHandler.postDelayed(this, 1000)
        }
    }

    private fun canOverlay(): Boolean =
        Build.VERSION.SDK_INT < 23 || android.provider.Settings.canDrawOverlays(this)

    private fun showOverlay() {
        if (overlay != null || !canOverlay()) return
        val ctx = applicationContext
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val d = resources.displayMetrics.density
        fun dp(v: Int): Int = (v * d).toInt()

        val root = LinearLayout(ctx)
        root.orientation = LinearLayout.HORIZONTAL
        root.gravity = Gravity.CENTER_VERTICAL
        root.setPadding(dp(10), dp(8), dp(8), dp(8))
        val bg = GradientDrawable()
        bg.setColor(0xEE0F1A20.toInt())
        bg.cornerRadius = dp(22).toFloat()
        root.background = bg
        root.elevation = dp(10).toFloat()

        val art = ImageView(ctx)
        art.layoutParams = LinearLayout.LayoutParams(dp(68), dp(68))
        art.scaleType = ImageView.ScaleType.CENTER_CROP
        art.setImageResource(android.R.drawable.ic_media_play)
        val artBg = GradientDrawable()
        artBg.setColor(0xFF1DB954.toInt())
        artBg.cornerRadius = dp(12).toFloat()
        art.background = artBg
        art.clipToOutline = true

        val texts = LinearLayout(ctx)
        texts.orientation = LinearLayout.VERTICAL
        val tlp = LinearLayout.LayoutParams(dp(200), ViewGroup.LayoutParams.WRAP_CONTENT)
        tlp.leftMargin = dp(12)
        tlp.rightMargin = dp(4)
        texts.layoutParams = tlp
        val title = TextView(ctx)
        title.setTextColor(Color.WHITE)
        title.textSize = 16f
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
        title.maxLines = 1
        title.ellipsize = TextUtils.TruncateAt.END
        val artist = TextView(ctx)
        artist.setTextColor(0xFFB0BEC5.toInt())
        artist.textSize = 13f
        artist.maxLines = 1
        artist.ellipsize = TextUtils.TruncateAt.END
        texts.addView(title)
        texts.addView(artist)

        fun btn(icon: Int, size: Int, onClick: () -> Unit): ImageButton {
            val b = ImageButton(ctx)
            b.setImageResource(icon)
            b.setColorFilter(Color.WHITE)
            b.setBackgroundColor(Color.TRANSPARENT)
            b.scaleType = ImageView.ScaleType.FIT_CENTER
            b.setPadding(dp(8), dp(8), dp(8), dp(8))
            b.layoutParams = LinearLayout.LayoutParams(dp(size), dp(size))
            b.setOnClickListener { onClick() }
            return b
        }

        val prev = btn(android.R.drawable.ic_media_previous, 52) {
            media("prev")
            mainHandler.postDelayed({ updateOverlay() }, 400)
        }
        val play = btn(android.R.drawable.ic_media_play, 60) {
            media("play")
            mainHandler.postDelayed({ updateOverlay() }, 400)
        }
        val next = btn(android.R.drawable.ic_media_next, 52) {
            media("next")
            mainHandler.postDelayed({ updateOverlay() }, 400)
        }
        val back = btn(android.R.drawable.ic_menu_revert, 46) {
            val i = Intent(ctx, MainActivity::class.java)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            ctx.startActivity(i)
        }
        val close = btn(android.R.drawable.ic_menu_close_clear_cancel, 42) { hideOverlay() }

        root.addView(art)
        root.addView(texts)
        root.addView(prev)
        root.addView(play)
        root.addView(next)
        root.addView(back)
        root.addView(close)

        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= 26) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.BOTTOM or Gravity.END
        lp.x = dp(16)
        lp.y = dp(16)

        // Se puede arrastrar desde la portada o el texto.
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        root.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = lp.x
                    startY = lp.y
                    touchX = e.rawX
                    touchY = e.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    lp.x = startX - (e.rawX - touchX).toInt()
                    lp.y = startY - (e.rawY - touchY).toInt()
                    try {
                        wm.updateViewLayout(v, lp)
                    } catch (ex: Exception) {
                    }
                    true
                }
                else -> false
            }
        }

        try {
            wm.addView(root, lp)
        } catch (e: Exception) {
            return
        }
        overlay = root
        ovArt = art
        ovTitle = title
        ovArtist = artist
        ovPlay = play
        ovKey = ""
        mainHandler.removeCallbacks(overlayTick)
        mainHandler.post(overlayTick)
    }

    private fun updateOverlay() {
        if (overlay == null) return
        val c = controller()
        val md = c?.metadata
        val t = md?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
        val a = md?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""
        ovTitle?.text = if (t.isEmpty()) (if (hasNotifAccess()) "Sin música" else "Permite el acceso a notificaciones") else t
        ovArtist?.text = if (a.isEmpty()) "Abre Spotify para empezar" else a
        val playing = c?.playbackState?.state == PlaybackState.STATE_PLAYING
        ovPlay?.setImageResource(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        val key = "$t|$a"
        if (key != ovKey) {
            ovKey = key
            val bmp = artOf(c)
            if (bmp != null) {
                ovArt?.setImageBitmap(bmp)
            } else {
                ovArt?.setImageResource(android.R.drawable.ic_media_play)
            }
        }
    }

    private fun hideOverlay() {
        mainHandler.removeCallbacks(overlayTick)
        val v = overlay ?: return
        try {
            val wm = applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.removeView(v)
        } catch (e: Exception) {
        }
        overlay = null
        ovArt = null
        ovTitle = null
        ovArtist = null
        ovPlay = null
    }

    private fun hasBtPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    private fun closeSocket() {
        try {
            socket?.close()
        } catch (e: Exception) {
        }
        socket = null
        input = null
        output = null
    }

    override fun onDestroy() {
        hideOverlay()
        closeSocket()
        super.onDestroy()
    }
}
