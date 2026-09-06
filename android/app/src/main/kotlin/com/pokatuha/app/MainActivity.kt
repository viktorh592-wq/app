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

    // V3.0.3 bug 1 — Wi-Fi multicast lock so the chip keeps delivering UDP
    // broadcast/multicast packets to the app while it is in the foreground.
    // Acquired on demand from Dart via the "pokatuha/network" method channel.
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

        // V3.0.3 bug 1 — multicast lock channel for the local-network UDP
        // transport (LocalNetworkCommunicationService). Two methods:
        //   acquireMulticastLock — request the lock (idempotent)
        //   releaseMulticastLock — release the lock (idempotent)
        // Both are best-effort: failures are reported via result.error but
        // the Dart side swallows them and falls back to in-process loopback.
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

    @Synchronized
    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: throw IllegalStateException("WifiManager unavailable")
        val lock = wifi.createMulticastLock("pokatuha.network.udp").apply {
            setReferenceCounted(false)
            acquire()
        }
        multicastLock = lock
    }

    @Synchronized
    private fun releaseMulticastLock() {
        val lock = multicastLock ?: return
        if (lock.isHeld) {
            try {
                lock.release()
            } catch (_: Throwable) {
                // ignore — best effort
            }
        }
        multicastLock = null
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

    override fun onDestroy() {
        super.onDestroy()
        // Always release the lock when the activity goes away — Android will
        // otherwise hold it for the process lifetime and drain the battery.
        releaseMulticastLock()
    }

    private fun maybeCapture(data: String, store: (String?) -> Unit) {
        if (data.startsWith("pokatuha://")) store(data)
    }
}
