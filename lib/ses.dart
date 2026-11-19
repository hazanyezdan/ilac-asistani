/// Uygulamanın konuşması (flutter_tts) ve kullanıcıyı dinlemesi
/// (speech_to_text) burada toplanır.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'komutlar.dart';
import 'turkce.dart';

class SesServisi {
  /// Uygulama konuşurken kullanıcı araya girerse sussun mu?
  /// Kısa cümlelerde gereksiz "bip" sesleri olmasın diye yalnızca en az
  /// bu kadar kelimelik cümlelerde araya girme dinlenir.
  static const int sozKesmeIcinEnAzKelime = 6;

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  /// Ekranda "Dinliyorum" göstergesi için.
  final ValueNotifier<bool> dinliyor = ValueNotifier(false);

  bool _sttHazir = false;
  bool get sttHazir => _sttHazir;

  bool _konusuyor = false;
  bool get konusuyor => _konusuyor;

  Completer<String?>? _dinlemeSonucu;
  String _sonDuyulan = '';
  void Function(String metin, bool son)? _sonucIsleyici;

  Future<void> hazirla() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    // speak() konuşma bitene kadar beklesin; böylece sözler üst üste binmez.
    await _tts.awaitSpeakCompletion(true);
  }

  /// Konuşma tanımayı başlatır. Mikrofon izni verilmiş olmalıdır.
  Future<bool> dinlemeyiHazirla() async {
    if (_sttHazir) return true;
    try {
      _sttHazir = await _stt.initialize(onError: _hata, onStatus: _durum);
    } catch (e) {
      debugPrint('Konuşma tanıma başlatılamadı: $e');
      _sttHazir = false;
    }
    return _sttHazir;
  }

  void _hata(SpeechRecognitionError hata) => _oturumBitti();

  void _durum(String durum) {
    if (durum == SpeechToText.doneStatus) _oturumBitti();
  }

  void _oturumBitti() {
    dinliyor.value = false;
    _tamamla(_sonDuyulan.trim().isEmpty ? null : _sonDuyulan);
  }

  void _tamamla(String? sonuc) {
    final c = _dinlemeSonucu;
    if (c != null && !c.isCompleted) c.complete(sonuc);
  }

  Future<void> _oturumuKapat() async {
    _sonucIsleyici = null;
    if (_stt.isListening) await _stt.cancel();
    _tamamla(null);
    dinliyor.value = false;
  }

  Future<void> _dinlemeyeBasla(Duration sure, Duration sessizlik) async {
    _sonDuyulan = '';
    _dinlemeSonucu = Completer<String?>();
    dinliyor.value = true;
    await _stt.listen(
      onResult: (r) => _sonucIsleyici?.call(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: 'tr_TR',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        listenFor: sure,
        pauseFor: sessizlik,
      ),
    );
  }

  /// Uygulamayı susturur ve dinlemeyi bırakır.
  Future<void> sustur() async {
    await _tts.stop();
    await _oturumuKapat();
  }

  /// Kullanıcıyı dinler; söylenen cümleyi döner. Bir şey duyulmazsa `null`.
  Future<String?> dinle({Duration sure = const Duration(seconds: 8)}) async {
    if (!_sttHazir) return null;
    await sustur();
    _sonucIsleyici = (metin, son) {
      _sonDuyulan = metin;
      if (son) _tamamla(metin);
    };
    await _dinlemeyeBasla(sure, const Duration(seconds: 3));
    final sonuc = await _dinlemeSonucu!.future.timeout(
      sure + const Duration(seconds: 4),
      onTimeout: () => _sonDuyulan.isEmpty ? null : _sonDuyulan,
    );
    await _oturumuKapat();
    return (sonuc == null || sonuc.trim().isEmpty) ? null : sonuc;
  }

  /// Metni sesli söyler.
  ///
  /// Uzun cümlelerde konuşurken mikrofonu da dinler. Kullanıcı araya girip
  /// konuşursa uygulama hemen susar ve kullanıcının söylediğini döner.
  /// Araya girilmezse `null` döner.
  Future<String?> soyle(String metin, {bool kesilebilir = true}) async {
    await sustur();
    final kesmeDinlensin =
        kesilebilir &&
        _sttHazir &&
        kelimeler(metin).length >= sozKesmeIcinEnAzKelime;

    _konusuyor = true;
    var kesildi = false;
    Future<String?>? kesme;
    if (kesmeDinlensin) {
      kesme = _arayaGirmeyiDinle(metin, () {
        kesildi = true;
        unawaited(_tts.stop());
      });
    }
    try {
      await _tts.speak(metin);
    } finally {
      _konusuyor = false;
    }
    if (kesme == null) return null;
    if (!kesildi) {
      await _oturumuKapat();
      await kesme;
      return null;
    }
    // Kullanıcı konuşmayı kesti; sözünü bitirmesini bekle.
    return kesme.timeout(const Duration(seconds: 10), onTimeout: () => null);
  }

  Future<String?> _arayaGirmeyiDinle(String soylenen, VoidCallback kes) async {
    var kesildi = false;
    // Android tanıyıcı kısa bir sessizlikte kendiliğinden durur; konuşma
    // sürdüğü sürece birkaç kez yeniden başlatılır.
    for (var deneme = 0; deneme < 3 && (_konusuyor || kesildi); deneme++) {
      _sonucIsleyici = (metin, son) {
        // Mikrofon uygulamanın kendi sesini de duyar; onu ayıkla.
        final kullaniciSozu = yankidanArindir(metin, soylenen);
        if (!kesildi && sozKesmeyeYeterMi(kullaniciSozu)) {
          kesildi = true;
          kes();
        }
        if (kesildi) {
          _sonDuyulan = kullaniciSozu;
          if (son) _tamamla(kullaniciSozu);
        } else if (son) {
          _tamamla(null);
        }
      };
      try {
        await _dinlemeyeBasla(
          const Duration(seconds: 30),
          const Duration(seconds: 2),
        );
      } catch (_) {
        return null;
      }
      // Dinleme başlarken konuşma bitmiş olabilir; mikrofonu açık bırakma.
      if (!_konusuyor && !kesildi) {
        await _oturumuKapat();
        return null;
      }
      final sonuc = await _dinlemeSonucu!.future;
      if (kesildi) {
        await _oturumuKapat();
        return sonuc;
      }
    }
    return null;
  }
}
