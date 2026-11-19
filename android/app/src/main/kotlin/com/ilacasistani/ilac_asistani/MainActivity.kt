package com.ilacasistani.ilac_asistani

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Kısa "bip" sesi için. Ses seviyesi medya sesine bağlıdır.
    private var tonUretici: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ilac_asistani/cihaz")
            .setMethodCallHandler { cagri, sonuc ->
                when (cagri.method) {
                    "bip" -> {
                        bip(cagri.argument<Int>("sure") ?: 60)
                        sonuc.success(null)
                    }
                    "sesAyarlariniAc" -> sonuc.success(sesAyarlariniAc())
                    else -> sonuc.notImplemented()
                }
            }
    }

    private fun bip(sureMs: Int) {
        try {
            val uretici = tonUretici ?: ToneGenerator(AudioManager.STREAM_MUSIC, 80)
                .also { tonUretici = it }
            uretici.startTone(ToneGenerator.TONE_PROP_BEEP, sureMs)
        } catch (e: RuntimeException) {
            // Bazı cihazlarda ses kanalı meşgulse ToneGenerator açılamaz.
            tonUretici = null
        }
    }

    // Metin okuma (TTS) ayarlarını açar; açılamazsa Türkçe ses verisi
    // yükleme ekranını, o da yoksa erişilebilirlik ayarlarını dener.
    private fun sesAyarlariniAc(): Boolean {
        val denemeler = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
        )
        for (niyet in denemeler) {
            try {
                startActivity(niyet.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                continue
            }
        }
        return false
    }

    override fun onDestroy() {
        tonUretici?.release()
        tonUretici = null
        super.onDestroy()
    }
}
