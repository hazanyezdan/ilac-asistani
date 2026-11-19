/// Uygulamanın söylediği her şeyin hangi yoldan söyleneceğine karar veren
/// tek yer.
///
/// - TalkBack (ekran okuyucu) kapalıysa: flutter_tts ile konuşulur.
/// - TalkBack açıksa: duyuru TalkBack'e verilir; böylece iki ses aynı anda
///   konuşmaz ve kullanıcı TalkBack'in hız/ses ayarlarıyla duyar.
library;

import 'dart:async';
import 'dart:ui' show FlutterView, TextDirection;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_tts/flutter_tts.dart';

enum DuyuruYolu { sesMotoru, ekranOkuyucu }

class Duyurucu {
  Duyurucu({
    required this.sesMotoruylaSoyle,
    required this.sesMotorunuSustur,
    required this.ekranOkuyucuyaDuyur,
    required this.ekranOkuyucuAcikMi,
  });

  /// Gerçek uygulamada kullanılan kurulum.
  factory Duyurucu.uygulama(FlutterTts tts) => Duyurucu(
    sesMotoruylaSoyle: (metin) => tts.speak(metin),
    sesMotorunuSustur: () => tts.stop(),
    ekranOkuyucuyaDuyur: (metin) {
      final FlutterView gorunum =
          WidgetsBinding.instance.platformDispatcher.views.first;
      return SemanticsService.sendAnnouncement(
        gorunum,
        metin,
        TextDirection.ltr,
      );
    },
    ekranOkuyucuAcikMi: () => WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .accessibleNavigation,
  );

  final Future<void> Function(String metin) sesMotoruylaSoyle;
  final Future<void> Function() sesMotorunuSustur;
  final Future<void> Function(String metin) ekranOkuyucuyaDuyur;
  final bool Function() ekranOkuyucuAcikMi;

  Completer<void>? _bekleme;

  /// Şu an hangi yoldan konuşulacak?
  DuyuruYolu get yol =>
      ekranOkuyucuAcikMi() ? DuyuruYolu.ekranOkuyucu : DuyuruYolu.sesMotoru;

  /// Metni söyler ve söylenmesi bitene kadar bekler.
  ///
  /// TalkBack duyurusunun ne zaman bittiği bilinemediği için okuma süresi
  /// metnin uzunluğundan tahmin edilir; böylece hemen ardından açılan
  /// mikrofon TalkBack'in sesini duymaz.
  Future<DuyuruYolu> duyur(String metin) async {
    final secilen = yol;
    if (secilen == DuyuruYolu.sesMotoru) {
      await sesMotoruylaSoyle(metin);
      return secilen;
    }
    await sesMotorunuSustur();
    await ekranOkuyucuyaDuyur(metin);
    final bekleme = Completer<void>();
    _bekleme = bekleme;
    final zamanlayici = Timer(tahminiOkumaSuresi(metin), () {
      if (!bekleme.isCompleted) bekleme.complete();
    });
    await bekleme.future;
    zamanlayici.cancel();
    return secilen;
  }

  /// Konuşmayı keser. TalkBack'in kendi sesi uygulamadan durdurulamaz
  /// (ekrana dokunmak TalkBack'i susturur); yalnızca beklemeyi bitiririz.
  Future<void> sustur() async {
    final b = _bekleme;
    if (b != null && !b.isCompleted) b.complete();
    await sesMotorunuSustur();
  }

  /// TalkBack'in bir metni okuma süresi tahmini: harf başına ~70 ms,
  /// en az 1, en fazla 20 saniye.
  static Duration tahminiOkumaSuresi(String metin) {
    final ms = 600 + metin.trim().length * 70;
    return Duration(milliseconds: ms.clamp(1000, 20000));
  }
}

/// flutter_tts'in "isLanguageAvailable" / "isLanguageInstalled" cevaplarına
/// bakarak Türkçe sesin kullanılabilir olup olmadığına karar verir.
/// Cevaplar bazı sürümlerde bool, bazılarında 1/0 gelir; `null` "bilinmiyor"
/// demektir ve yüklü sayılır (yanlış uyarı vermemek için).
bool turkceSesHazirMi({Object? mevcut, Object? yuklu}) {
  bool? oku(Object? deger) => switch (deger) {
    bool b => b,
    int i => i > 0,
    _ => null,
  };
  return (oku(mevcut) ?? true) && (oku(yuklu) ?? true);
}
