/// Kutunun üzerindeki yazıdan (OCR) ilacı tahmin eden saf Dart kodu.
///
/// Bu yöntem kesin değildir: yazı tanıma hata yapabilir ve kutuda başka
/// kelimeler de yazar. Bu yüzden sonuç her zaman "muhtemelen" diye söylenir.
library;

import 'dart:math' as math;

import 'ilac_veritabani.dart';

/// Yazıdan bulunan tahmin.
class YaziEslesmesi {
  const YaziEslesmesi({required this.marka, this.ad, this.yaklasik = false});

  /// Bulunan marka ("CORASPIN").
  final String marka;

  /// Kutudaki dozla da eşleşen tam ürün adı (bulunabildiyse).
  final String? ad;

  /// Marka birebir değil, harf hatasıyla (yaklaşık) bulunduysa `true`.
  final bool yaklasik;

  /// Söylenecek ad: "Coraspin 100 miligram" ya da yalnızca "Coraspin".
  String get okunacakAd {
    if (ad != null) return kisaAd(ad!);
    final kucuk = konusmaIcinAd(marka);
    return kucuk.isEmpty ? kucuk : kucuk[0].toUpperCase() + kucuk.substring(1);
  }

  /// Uygulamanın söyleyeceği cümle. Doz önerisi ya da tıbbi tavsiye içermez.
  String get cumle =>
      'Karekod bulunamadı, kutunun yazısından okuyorum: muhtemelen '
      '$okunacakAd. Bu tahmin kesin değil, mümkünse karekodu okutun.';
}

/// Yazı tanıma harf yerine benzer rakam okuyabilir ("0RNEK" → "ORNEK").
const Map<String, String> _rakamHarf = {'0': 'O', '1': 'I', '5': 'S', '8': 'B'};

/// Yazı tanımanın verdiği metni kelimelere böler (büyük harf, ASCII).
/// İçinde harf de olan kelimelerdeki benzer rakamlar harfe çevrilir; yalnızca
/// rakamdan oluşan kelimeler (dozlar) olduğu gibi kalır.
List<String> _kelimeler(String metin) => asciiBuyuk(metin)
    .split(RegExp(r'[^A-Z0-9]+'))
    .where((k) => k.isNotEmpty)
    .map(
      (k) => RegExp('[A-Z]').hasMatch(k)
          ? k.split('').map((h) => _rakamHarf[h] ?? h).join()
          : k,
    )
    .toList();

/// İki kelime arasındaki harf farkı (Levenshtein). [sinir]'ı aşınca erken
/// durur ve sinir+1 döner.
int harfFarki(String a, String b, {int sinir = 3}) {
  if ((a.length - b.length).abs() > sinir) return sinir + 1;
  var onceki = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final simdiki = List<int>.filled(b.length + 1, 0)..[0] = i;
    var satirEnKucuk = i;
    for (var j = 1; j <= b.length; j++) {
      final maliyet = a[i - 1] == b[j - 1] ? 0 : 1;
      simdiki[j] = math.min(
        math.min(simdiki[j - 1] + 1, onceki[j] + 1),
        onceki[j - 1] + maliyet,
      );
      satirEnKucuk = math.min(satirEnKucuk, simdiki[j]);
    }
    if (satirEnKucuk > sinir) return sinir + 1;
    onceki = simdiki;
  }
  return onceki[b.length];
}

/// Uzunluğa göre izin verilen harf hatası: kısa adlarda hiç, uzunlarda 1-2.
int _izinliFark(String kelime) => kelime.length >= 8
    ? 2
    : kelime.length >= 5
    ? 1
    : 0;

/// Metindeki dozlar: "100 mg", "100mg" → {"100 MG"}.
Set<String> _dozlar(String metin) =>
    RegExp(r'(\d+(?:[.,]\d+)?)\s*(MCG|MG|ML|G)\b')
        .allMatches(asciiBuyuk(metin))
        .map((m) => '${m[1]} ${m[2]}')
        .toSet();

/// Kutu yazısından ilacı tahmin eder. [markaIndeksi] marka → ürün adları
/// eşlemesidir ([IlacVeritabani.markaIndeksi]). Emin olunamazsa (hiç ya da
/// birden fazla eşit aday varsa) `null` döner.
YaziEslesmesi? yazidanIlacBul(
  String metin,
  Map<String, List<String>> markaIndeksi,
) {
  final kelimeler = _kelimeler(metin);
  if (kelimeler.isEmpty) return null;

  // 1) Birebir eşleşme: 3, 2 ve 1 kelimelik gruplar.
  final sayac = <String, int>{};
  for (var n = 3; n >= 1; n--) {
    for (var i = 0; i + n <= kelimeler.length; i++) {
      final grup = kelimeler.sublist(i, i + n).join(' ');
      if (markaIndeksi.containsKey(grup)) {
        sayac[grup] = (sayac[grup] ?? 0) + 1;
      }
    }
  }
  String? marka;
  var yaklasik = false;
  if (sayac.isNotEmpty) {
    // Uzun marka ("MAJEZIK DUO") kısasını ("MAJEZIK") içeriyorsa uzun olanı
    // seç; sonra en çok geçen. Eşitlik varsa tahmin etme.
    final adaylar = sayac.keys.toList()
      ..sort((a, b) {
        final uzunluk = b.split(' ').length.compareTo(a.split(' ').length);
        if (uzunluk != 0) return uzunluk;
        final sayi = sayac[b]!.compareTo(sayac[a]!);
        return sayi != 0 ? sayi : b.length.compareTo(a.length);
      });
    final ilk = adaylar.first;
    final ikinci = adaylar.length > 1 ? adaylar[1] : null;
    if (ikinci != null &&
        !ilk.contains(ikinci) &&
        ilk.split(' ').length == ikinci.split(' ').length &&
        sayac[ilk] == sayac[ikinci]) {
      return null;
    }
    marka = ilk;
  } else {
    // 2) Yaklaşık eşleşme: yazı tanıma bir iki harfi yanlış okuyabilir.
    var enIyiFark = 1 << 30;
    final enIyiler = <String>{};
    for (final kelime in kelimeler.toSet()) {
      final izin = _izinliFark(kelime);
      if (izin == 0) continue;
      for (final aday in markaIndeksi.keys) {
        if (aday.contains(' ')) continue;
        final fark = harfFarki(kelime, aday, sinir: izin);
        if (fark > izin) continue;
        if (fark < enIyiFark) {
          enIyiFark = fark;
          enIyiler
            ..clear()
            ..add(aday);
        } else if (fark == enIyiFark) {
          enIyiler.add(aday);
        }
      }
    }
    if (enIyiler.length != 1) return null;
    marka = enIyiler.single;
    yaklasik = true;
  }

  // Kutuda doz yazıyorsa o markanın aynı dozlu ürününü seç.
  final dozlar = _dozlar(metin);
  String? ad;
  for (final urun in markaIndeksi[marka]!) {
    final urunDozlari = _dozlar(urun);
    if (urunDozlari.isNotEmpty && urunDozlari.any(dozlar.contains)) {
      ad = urun;
      break;
    }
  }
  return YaziEslesmesi(marka: marka, ad: ad, yaklasik: yaklasik);
}
