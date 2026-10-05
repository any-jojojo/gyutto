package com.example.gyutto

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Direct reference: fail compilation if plugin generation was skipped.
        // This activity creates its own engine; register once, without super's
        // reflective registration path.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
