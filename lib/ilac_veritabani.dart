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

  /// Listedeki tüm ilaç adları.
  Iterable<String> get adlar => _ilaclar.values;

  Map<String, List<String>>? _markaIndeksi;

  /// Marka adı → o markanın ürünleri ("CORASPIN" → [...100 MG..., ...300 MG...]).
  /// Kutu yazısından tanıma için; ilk kullanımda bir kez hazırlanır.
  Map<String, List<String>> get markaIndeksi =>
      _markaIndeksi ??= markaIndeksiOlustur(_ilaclar.values);

  /// Karekoddaki 14 haneli GTIN ("08699...") ile kutudaki 13 haneli barkod
  /// ("8699...") aynı ürünü gösterir; baştaki sıfırlar atılarak karşılaştırılır.
  static String _anahtar(String barkod) =>
      barkod.trim().replaceFirst(RegExp(r'^0+'), '');

  /// İki barkod aynı ürünü mü gösteriyor? (GTIN-14 ile EAN-13 de eşleşir.)
  static bool ayniUrun(String? a, String? b) =>
      a != null && b != null && a.isNotEmpty && _anahtar(a) == _anahtar(b);

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

/// Doz birimleri. Tek harfli "G" yalnızca önünde boşluk varsa birimdir
/// ("30 G" gram, ama "32G" iğne kalınlığıdır).
const String _birim = r'(?:\s*(?:MCG|MG|ML|IU|UI|µG)\b|\s+(?:GRAM|GR|G)\b)';
const String _sayi = r'\d+(?:[.,]\d+)?';

/// Adın ilk kısmı: marka ve doz ("CORASPIN 100 MG 30 ENTERIK KAPLI TABLET"
/// → "CORASPIN 100 MG"). Doz yoksa ilk sayıdan önceki kelimeler.
String _adinBasi(String ad) {
  final temiz = ad.trim();
  final dozlu = RegExp(
    '^(.*?(?:$_sayi$_birim|%\\s*$_sayi)'
    '(?:\\s*/\\s*(?:$_sayi$_birim|$_sayi))*)',
    caseSensitive: false,
  ).firstMatch(temiz);
  if (dozlu != null) return dozlu.group(1)!;
  return markaAdi(temiz, asciiCevir: false);
}

/// Sesli okunacak kısa ad: "CORASPIN 100 MG 30 ENTERIK KAPLI TABLET" →
/// "Coraspin 100 miligram". Paket bilgisi (30 tablet vb.) atılır.
String kisaAd(String ad) {
  final bas = _adinBasi(ad);
  // "%5 DEKSTROZ..." gibi adlarda baştaki kısımda ilaç adı yoktur.
  final metin = konusmaIcinAd(RegExp('[A-Za-z]').hasMatch(bas) ? bas : ad);
  if (metin.isEmpty) return metin;
  return metin[0].toUpperCase() + metin.substring(1);
}

/// Türkçe harfleri ASCII'ye çevirip büyük harf yapar (TİTCK listesi ve
/// kutu yazısı aynı biçimde karşılaştırılsın diye).
String asciiBuyuk(String metin) {
  const harfler = {
    'ç': 'c',
    'Ç': 'C',
    'ğ': 'g',
    'Ğ': 'G',
    'ı': 'i',
    'İ': 'I',
    'ö': 'o',
    'Ö': 'O',
    'ş': 's',
    'Ş': 'S',
    'ü': 'u',
    'Ü': 'U',
  };
  final b = StringBuffer();
  for (final h in metin.split('')) {
    b.write(harfler[h] ?? h);
  }
  return b.toString().toUpperCase();
}

/// İlacın marka adı: ilk sayıdan önceki en fazla üç kelime
/// ("ASIST C 600 MG..." → "ASIST C").
String markaAdi(String ad, {bool asciiCevir = true}) {
  final kelimeler = <String>[];
  for (final k in ad.trim().split(RegExp(r'\s+'))) {
    if (RegExp(r'[0-9%]').hasMatch(k) || k.startsWith('(')) break;
    kelimeler.add(k);
    if (kelimeler.length == 3) break;
  }
  final marka = kelimeler.join(' ');
  return asciiCevir ? asciiBuyuk(marka) : marka;
}

/// Marka sayılmayacak genel kelimeler: bunlar kutularda yardımcı madde
/// olarak da geçtiği için yanlış eşleşmeye yol açar.
const Set<String> genelKelimeler = {
  'SODYUM',
  'POTASYUM',
  'KALSIYUM',
  'MAGNEZYUM',
  'CINKO',
  'DEMIR',
  'IZOTONIK',
  'LAKTATLI',
  'DEKSTROZ',
  'GLUKOZ',
  'STERIL',
  'SU',
  'ENJEKSIYONLUK',
  'TABLET',
  'KAPSUL',
  'SURUP',
  'KREM',
  'POMAD',
  'JEL',
  'VITAMIN',
  'FOLIK',
  'ASIT',
  'ASIDI',
  'KLORUR',
  'LAKTOZ',
  'NISASTA',
  'PF',
  'BD',
  'PKU',
  'BALANCE',
  'RESOURCE',
};

/// Marka → ürün adları indeksi.
Map<String, List<String>> markaIndeksiOlustur(Iterable<String> adlar) {
  final indeks = <String, List<String>>{};
  for (final ad in adlar) {
    final marka = markaAdi(ad);
    // "SODYUM KLORUR" gibi genel kelimeyle başlayan adlar marka sayılmaz.
    if (marka.length < 4 || genelKelimeler.contains(marka.split(' ').first)) {
      continue;
    }
    (indeks[marka] ??= []).add(ad);
  }
  return indeks;
}
