package com.ryanheise.just_audio

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

class JustAudioPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "com.ryanheise.just_audio",
            AudioPlayerFactory(binding.applicationContext)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    }
}