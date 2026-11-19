/// NFC etiketlerini ilaçlarla eşleştirip telefonda saklar.
///
/// Etiketin kendisine bir şey yazılmaz; yalnızca etiketin değişmez kimliği
/// (UID) okunur ve "bu kimlik şu ilacın kutusu" diye telefonda saklanır.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Etiket kimliğini "04:A2:1B:..." biçiminde yazar.
String etiketKimligi(List<int> baytlar) => baytlar
    .map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');

/// Bir etikete bağlanan ilaç bilgisi.
class EtiketKaydi {
  const EtiketKaydi({required this.karekod, this.gtin, this.ilacAdi});

  factory EtiketKaydi.jsondan(Map<String, dynamic> j) => EtiketKaydi(
    karekod: j['karekod'] as String,
    gtin: j['gtin'] as String?,
    ilacAdi: j['ilacAdi'] as String?,
  );

  /// Kutudan okunan ham karekod. Son kullanma tarihi buradan çıkarılır;
  /// kutu değişince etiket yeniden eşleştirilmelidir.
  final String karekod;
  final String? gtin;
  final String? ilacAdi;

  Map<String, dynamic> jsona() => {
    'karekod': karekod,
    'gtin': gtin,
    'ilacAdi': ilacAdi,
  };
}

class EtiketDeposu {
  static const _anahtar = 'nfc_etiketleri';

  Future<Map<String, EtiketKaydi>> _hepsi() async {
    final t = await SharedPreferences.getInstance();
    final metin = t.getString(_anahtar);
    if (metin == null || metin.isEmpty) return {};
    try {
      final j = jsonDecode(metin) as Map<String, dynamic>;
      return j.map(
        (k, v) => MapEntry(k, EtiketKaydi.jsondan(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<EtiketKaydi?> bul(String kimlik) async => (await _hepsi())[kimlik];

  /// Etiketi ilaçla eşleştirir; etiket daha önce başka ilaca bağlıysa
  /// yeni ilaçla değiştirilir.
  Future<void> eslestir(String kimlik, EtiketKaydi kayit) async {
    final hepsi = await _hepsi();
    hepsi[kimlik] = kayit;
    final t = await SharedPreferences.getInstance();
    await t.setString(
      _anahtar,
      jsonEncode(hepsi.map((k, v) => MapEntry(k, v.jsona()))),
    );
  }

  Future<int> adet() async => (await _hepsi()).length;
}
