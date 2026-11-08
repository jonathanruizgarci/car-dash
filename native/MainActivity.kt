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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

@SuppressLint("MissingPermission")
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
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val code = when (call.argument<String>("key")) {
                        "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                        "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                        else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                    }
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
                    result.success(true)
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
        closeSocket()
        super.onDestroy()
    }
}
