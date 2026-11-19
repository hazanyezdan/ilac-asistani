/// Barkoddan ilaç adını bulan küçük veritabanı.
///
/// Veriler `assets/ilaclar.tsv` dosyasındadır ve TİTCK'nin yayımladığı
/// "SKRS e-Reçete İlaç ve Diğer Farmasötik Ürünler Listesi"nden
/// `tool/ilac_listesi_guncelle.py` ile üretilir.
library;

import 'package:flutter/services.dart' show rootBundle;

class IlacVeritabani {
  IlacVeritabani(Map<String, String> ilaclar) : _ilaclar = ilaclar;

  /// `barkod<TAB>ad` satırlarından veritabanı oluşturur.
  factory IlacVeritabani.metindenOlustur(String tsv) {
    final ilaclar = <String, String>{};
    for (final satir in tsv.split('\n')) {
      final sekme = satir.indexOf('\t');
      if (sekme <= 0) continue;
      ilaclar[_anahtar(satir.substring(0, sekme))] = satir
          .substring(sekme + 1)
          .trim();
    }
    return IlacVeritabani(ilaclar);
  }

  static Future<IlacVeritabani> yukle() async {
    try {
      return IlacVeritabani.metindenOlustur(
        await rootBundle.loadString('assets/ilaclar.tsv'),
      );
    } catch (_) {
      return IlacVeritabani({});
    }
  }

  final Map<String, String> _ilaclar;

  int get adet => _ilaclar.length;

  /// Karekoddaki 14 haneli GTIN ("08699...") ile kutudaki 13 haneli barkod
  /// ("8699...") aynı ürünü gösterir; baştaki sıfırlar atılarak karşılaştırılır.
  static String _anahtar(String barkod) =>
      barkod.trim().replaceFirst(RegExp(r'^0+'), '');

  /// İlacın listedeki adını döner, bulunamazsa `null`.
  String? ad(String? barkod) {
    if (barkod == null || barkod.isEmpty) return null;
    return _ilaclar[_anahtar(barkod)];
  }
}

/// Listedeki büyük harfli, kısaltmalı adı sesli okumaya uygun hale getirir:
/// "PAROL 500 MG 20 TABLET" → "parol 500 miligram 20 tablet".
String konusmaIcinAd(String ad) {
  // TİTCK listesi Türkçe karakter kullanmaz ("MAJEZIK"); oradaki "I"
  // aslında "i"dir. Bu yüzden Türkçe küçültme yerine düz küçültme yapılır.
  var metin = ad.replaceAll('İ', 'i').toLowerCase();
  const kisaltmalar = {
    'mg': 'miligram',
    'mcg': 'mikrogram',
    'µg': 'mikrogram',
    'ml': 'mililitre',
    'gr': 'gram',
    'g': 'gram',
    'iu': 'ünite',
    'ui': 'ünite',
  };
  kisaltmalar.forEach((kisa, uzun) {
    metin = metin.replaceAllMapped(
      RegExp('(?<=[0-9 ])$kisa(?=[ /),]|\$)'),
      (_) => ' $uzun',
    );
  });
  return metin
      .replaceAll('%', ' yüzde ')
      .replaceAll('/', ' ve ')
      .replaceAll(RegExp(r'[()\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
