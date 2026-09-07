package com.pokatuha.app

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var initialLink: String? = null
    private var pendingLink: String? = null
    private var sink: EventChannel.EventSink? = null

    // V3.0.4 bug 1 — Wi-Fi multicast lock so the Wi-Fi chip keeps delivering
    // UDP broadcast/multicast packets to the app while it is in the
    // foreground. Acquired on demand from Dart via the "pokatuha/network"
    // method channel (LocalNetworkCommunicationService). Best-effort: if the
    // lock cannot be acquired the Dart side falls back to foreground-only
    // delivery, chat still works while the screen is on.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cold start link (intent the activity was launched with).
        intent?.dataString?.let { maybeCapture(it) { link -> initialLink = link } }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pokatuha/deep_links")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> result.success(initialLink)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "pokatuha/deep_links/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    pendingLink?.let { link ->
                        events?.success(link)
                        pendingLink = null
                    }
                }

                override fun onCancel(args: Any?) {
                    sink = null
                }
            })

        // V3.0.4 bug 1 — multicast lock channel for the local-network UDP
        // transport. Both methods are idempotent.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pokatuha/network")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        try {
                            acquireMulticastLock()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("MULTICAST_LOCK_FAILED", e.message, null)
                        }
                    }
                    "releaseMulticastLock" -> {
                        try {
                            releaseMulticastLock()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("MULTICAST_LOCK_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val lock = multicastLock ?: wifi.createMulticastLock("pokatuha_udp").apply {
            setReferenceCounted(false)
            acquire()
            multicastLock = this
        }
        lock.acquire()
    }

    private fun releaseMulticastLock() {
        val lock = multicastLock ?: return
        if (lock.isHeld) {
            lock.release()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm start link (app already running, singleTop launch mode).
        intent.dataString?.let { data ->
            if (data.startsWith("pokatuha://")) {
                val s = sink
                if (s != null) s.success(data) else pendingLink = data
            }
        }
    }

    private fun maybeCapture(data: String, store: (String?) -> Unit) {
        if (data.startsWith("pokatuha://")) store(data)
    }
}
