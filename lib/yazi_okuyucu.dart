/// Kutunun fotoğrafını çekip üzerindeki yazıyı cihaz üzerinde (internetsiz)
/// okuyan kod: camera + google_mlkit_text_recognition.
library;

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class KutuYazisiOkuyucu {
  final TextRecognizer _tanima = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Arka kamerayla bir fotoğraf çeker ve içindeki yazıyı döner.
  /// Kamera başka bir yerde açıksa (karekod tarayıcı) önce kapatılmalıdır.
  Future<String?> fotografCekVeOku({bool fenerAcik = false}) async {
    CameraController? kamera;
    String? dosya;
    try {
      final kameralar = await availableCameras();
      if (kameralar.isEmpty) return null;
      final arka = kameralar.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kameralar.first,
      );
      kamera = CameraController(
        arka,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await kamera.initialize();
      await kamera.setFlashMode(fenerAcik ? FlashMode.torch : FlashMode.off);
      final foto = await kamera.takePicture();
      dosya = foto.path;
      final sonuc = await _tanima.processImage(InputImage.fromFilePath(dosya));
      return sonuc.text;
    } catch (e) {
      debugPrint('Kutu yazısı okunamadı: $e');
      return null;
    } finally {
      await kamera?.dispose();
      if (dosya != null) {
        try {
          File(dosya).deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> kapat() => _tanima.close();
}
