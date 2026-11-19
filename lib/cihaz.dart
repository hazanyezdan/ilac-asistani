/// Android'e özel küçük işler (MainActivity.kt ile konuşur).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Cihaz {
  static const _kanal = MethodChannel('ilac_asistani/cihaz');

  /// Kısa bir "bip" sesi çalar.
  static Future<void> bip({int sureMs = 60}) async {
    try {
      await _kanal.invokeMethod<void>('bip', {'sure': sureMs});
    } catch (e) {
      debugPrint('Bip çalınamadı: $e');
    }
  }

  /// Telefonun metin okuma (ses paketi) ayarlarını açar.
  static Future<bool> sesAyarlariniAc() async {
    try {
      return await _kanal.invokeMethod<bool>('sesAyarlariniAc') ?? false;
    } catch (_) {
      return false;
    }
  }
}
