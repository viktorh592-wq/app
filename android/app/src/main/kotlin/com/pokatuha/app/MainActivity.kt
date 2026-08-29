package com.pokatuha.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var initialLink: String? = null
    private var pendingLink: String? = null
    private var sink: EventChannel.EventSink? = null

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
