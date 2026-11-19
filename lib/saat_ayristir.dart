/// Söylenen cümleden saati çıkaran saf Dart kodu.
///
/// Örnekler:
///   "her gün saat dokuzda hatırlat" → 09:00
///   "her gün sabah 9'da"            → 09:00
///   "akşam sekizde hatırlat"        → 20:00
///   "saat dokuz buçukta"            → 09:30
///   "öğlen on ikide"                → 12:00
///   "gece on birde"                 → 23:00
library;

import 'turkce.dart';

/// Cümleden çıkarılan saat bilgisi.
class SaatBilgisi {
  const SaatBilgisi(
    this.saat,
    this.dakika, {
    this.donemBelirtildi = false,
    this.dakikaBelirtildi = false,
  });

  /// 0-23 arası saat.
  final int saat;
  final int dakika;

  /// Cümlede sabah/akşam/gece gibi bir söz ya da 13-23 arası bir saat
  /// geçiyorsa `true`. Geçmiyorsa saat sabah kabul edilmiştir.
  final bool donemBelirtildi;

  /// Dakika açıkça söylendiyse (ör. "buçuk", "9:30") `true`.
  final bool dakikaBelirtildi;

  String get metin => saatMetni(saat, dakika);

  @override
  bool operator ==(Object other) =>
      other is SaatBilgisi && other.saat == saat && other.dakika == dakika;

  @override
  int get hashCode => Object.hash(saat, dakika);

  @override
  String toString() => metin;
}

const Map<String, int> _sayiKelimeleri = {
  'bir': 1,
  'iki': 2,
  'üç': 3,
  'dört': 4,
  'dörd': 4, // dörde, dördü
  'beş': 5,
  'altı': 6,
  'yedi': 7,
  'sekiz': 8,
  'dokuz': 9,
  'on': 10,
  'yirmi': 20,
  'otuz': 30,
  'kırk': 40,
  'elli': 50,
};

/// "-de/-da/-te/-ta" (bulunma) ve "-deki/-daki" ekleri.
const Set<String> _bulunmaEkleri = {
  'de',
  'da',
  'te',
  'ta',
  'deki',
  'daki',
  'teki',
  'taki',
};

/// Sayı kelimelerinin alabileceği ekler.
const Set<String> _sayiEkleri = {
  '',
  ..._bulunmaEkleri,
  'e', 'a', 'ye', 'ya', // yönelme: dokuza, ikiye
  'i', 'ı', 'u', 'ü', 'yi', 'yı', 'yu', 'yü', // belirtme: dokuzu
  'den', 'dan', 'ten', 'tan', // ayrılma: dokuzdan
};

/// Bir kelimeyi oluşturan parça.
sealed class _Parca {}

class _Sayi extends _Parca {
  _Sayi(this.deger, this.ek, {this.rakamla = false, this.dakika});
  int deger;
  String ek;
  final bool rakamla;

  /// "9:30" gibi rakamla yazılan saatlerde dakika.
  final int? dakika;

  bool get bulunmaEkli => _bulunmaEkleri.contains(ek);
}

class _Bucuk extends _Parca {}

class _Ceyrek extends _Parca {}

class _Gece extends _Parca {} // "geçe"

class _Var extends _Parca {}

class _SaatKelimesi extends _Parca {}

class _Diger extends _Parca {}

enum _Donem { sabah, ogle, aksam, gece }

_Parca _parcala(String kelime) {
  final rakam = RegExp(r'^(\d{1,2})(?:[:.](\d{2}))?([a-zçğıöşü]*)$')
      .firstMatch(kelime);
  if (rakam != null) {
    return _Sayi(
      int.parse(rakam.group(1)!),
      rakam.group(3)!,
      rakamla: true,
      dakika: rakam.group(2) == null ? null : int.parse(rakam.group(2)!),
    );
  }
  if (kelime.startsWith('buçu') || kelime.startsWith('buçuğ')) return _Bucuk();
  if (kelime.startsWith('çeyrek')) return _Ceyrek();
  if (kelime == 'geçe' || kelime == 'geçiyor') return _Gece();
  if (kelime == 'var' || kelime == 'kala') return _Var();
  if (kelime == 'saat' || kelime == 'saatte' || kelime == 'saati') {
    return _SaatKelimesi();
  }

  // En uzun kelime önce denenir ki "on" ile "onda" karışmasın.
  final adaylar = _sayiKelimeleri.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final kok in adaylar) {
    if (kelime.startsWith(kok)) {
      final ek = kelime.substring(kok.length);
      if (_sayiEkleri.contains(ek)) return _Sayi(_sayiKelimeleri[kok]!, ek);
    }
  }
  return _Diger();
}

_Donem? _donemBul(List<String> kelimeListesi) {
  for (final k in kelimeListesi) {
    if (k.startsWith('sabah')) return _Donem.sabah;
    if (k.startsWith('öğle') || k.startsWith('ikindi')) return _Donem.ogle;
    if (k.startsWith('akşam')) return _Donem.aksam;
    if (k.startsWith('gece')) return _Donem.gece;
  }
  return null;
}

/// "on" + "bir" gibi ardışık sayı kelimelerini birleştirir.
List<_Parca> _birlestir(List<_Parca> parcalar) {
  final sonuc = <_Parca>[];
  for (final p in parcalar) {
    final onceki = sonuc.isEmpty ? null : sonuc.last;
    if (p is _Sayi &&
        !p.rakamla &&
        p.deger < 10 &&
        onceki is _Sayi &&
        !onceki.rakamla &&
        onceki.ek.isEmpty &&
        onceki.deger % 10 == 0 &&
        onceki.deger >= 10) {
      onceki
        ..deger += p.deger
        ..ek = p.ek;
      continue;
    }
    sonuc.add(p);
  }
  return sonuc;
}

/// Cümledeki saati bulur. Bulamazsa `null` döner.
SaatBilgisi? saatiAyikla(String cumle) {
  final kelimeListesi = kelimeler(cumle);
  final parcalar = _birlestir(kelimeListesi.map(_parcala).toList());

  // Saat olabilecek sayıyı öncelik sırasıyla seç.
  int? secilen;
  bool uygun(int i) {
    final p = parcalar[i];
    return p is _Sayi && p.deger <= 24;
  }

  bool ardindanDakikaVar(int i) =>
      i + 1 < parcalar.length &&
      (parcalar[i + 1] is _Bucuk || parcalar[i + 1] is _Ceyrek);

  // 1) "saat" kelimesinden hemen sonra gelen sayı.
  for (var i = 0; i + 1 < parcalar.length && secilen == null; i++) {
    if (parcalar[i] is _SaatKelimesi && uygun(i + 1)) secilen = i + 1;
  }
  // 2) "-de/-da" ekli ya da ardından "buçuk" gelen sayı.
  for (var i = 0; i < parcalar.length && secilen == null; i++) {
    final p = parcalar[i];
    if (uygun(i) && ((p as _Sayi).bulunmaEkli || ardindanDakikaVar(i))) {
      secilen = i;
    }
  }
  // 3) Rakamla yazılmış sayı.
  for (var i = 0; i < parcalar.length && secilen == null; i++) {
    if (uygun(i) && (parcalar[i] as _Sayi).rakamla) secilen = i;
  }
  // 4) Herhangi bir sayı ("bir" tek başına çok yaygın olduğu için hariç).
  for (var i = 0; i < parcalar.length && secilen == null; i++) {
    final p = parcalar[i];
    if (uygun(i) && !(p is _Sayi && p.deger == 1 && p.ek.isEmpty)) {
      secilen = i;
    }
  }
  if (secilen == null) return null;

  final saatParcasi = parcalar[secilen] as _Sayi;
  var saat = saatParcasi.deger % 24;
  var dakika = saatParcasi.dakika ?? 0;
  var dakikaBelirtildi = saatParcasi.dakika != null;
  if (dakika > 59) return null;

  // Dakikayı bul: "buçuk", "otuz", "çeyrek geçe", "on var".
  if (saatParcasi.dakika == null && !saatParcasi.bulunmaEkli) {
    final sonraki = secilen + 1 < parcalar.length
        ? parcalar[secilen + 1]
        : null;
    final dahaSonraki = secilen + 2 < parcalar.length
        ? parcalar[secilen + 2]
        : null;
    int? miktar;
    if (sonraki is _Bucuk) {
      dakika = 30;
      dakikaBelirtildi = true;
    } else if (sonraki is _Ceyrek) {
      miktar = 15;
    } else if (sonraki is _Sayi && sonraki.deger < 60) {
      miktar = sonraki.deger;
    }
    if (miktar != null) {
      if (dahaSonraki is _Gece) {
        dakika = miktar;
        dakikaBelirtildi = true;
      } else if (dahaSonraki is _Var) {
        saat = (saat + 23) % 24;
        dakika = 60 - miktar;
        dakikaBelirtildi = true;
      } else if (sonraki is _Sayi && sonraki.deger >= 10) {
        // "dokuz otuzda", "sekiz kırk beşte"
        dakika = miktar;
        dakikaBelirtildi = true;
      }
    }
  }

  // Sabah/akşam/gece sözüne göre saati düzelt.
  final donem = _donemBul(kelimeListesi);
  switch (donem) {
    case _Donem.aksam:
      if (saat >= 1 && saat <= 11) saat += 12;
      if (saat == 12) saat = 0;
    case _Donem.gece:
      if (saat >= 6 && saat <= 11) saat += 12;
      if (saat == 12) saat = 0;
    case _Donem.ogle:
      if (saat >= 1 && saat <= 7) saat += 12;
    case _Donem.sabah:
    case null:
      break;
  }

  return SaatBilgisi(
    saat,
    dakika,
    donemBelirtildi: donem != null || saat >= 13 || saat == 0,
    dakikaBelirtildi: dakikaBelirtildi,
  );
}
