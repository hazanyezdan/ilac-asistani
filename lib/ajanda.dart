/// Kurulu hatırlatmaların listesi (ajanda) ve telefonda kalıcı saklanması.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ilac_veritabani.dart';
import 'karekod.dart';
import 'saat_ayristir.dart';
import 'turkce.dart';

/// Her gün aynı saatte tekrarlanan bir ilaç hatırlatması.
class Hatirlatma {
  const Hatirlatma({
    required this.id,
    required this.saat,
    required this.dakika,
    this.gtin,
    this.ilacAdi,
    this.sonAlim,
    this.sonErteleme,
    this.sonKullanma,
  });

  factory Hatirlatma.jsondan(Map<String, dynamic> j) => Hatirlatma(
    id: j['id'] as int,
    saat: j['saat'] as int,
    dakika: j['dakika'] as int,
    gtin: j['gtin'] as String?,
    ilacAdi: j['ilacAdi'] as String?,
    sonAlim: _tarih(j['sonAlim']),
    sonErteleme: _tarih(j['sonErteleme']),
    sonKullanma: _tarih(j['sonKullanma']),
  );

  final int id;
  final int saat;
  final int dakika;

  /// İlacı ayırt etmek için karekoddaki ürün numarası.
  final String? gtin;

  /// TİTCK listesindeki ilaç adı (bulunabildiyse).
  final String? ilacAdi;

  /// "Aldım" denilen son zaman.
  final DateTime? sonAlim;

  /// "Ertele" denilen son zaman.
  final DateTime? sonErteleme;

  /// Son okutulan kutunun karekodundaki son kullanma tarihi. Aynı ilacın
  /// yeni kutusu okutulunca güncellenir.
  final DateTime? sonKullanma;

  String get saatYazisi => saatMetni(saat, dakika);

  /// Sesli okunacak kısa ad: "Coraspin 100 miligram" ya da "ilacınız".
  String get okunacakAd => ilacAdi == null ? 'ilacınız' : kisaAd(ilacAdi!);

  /// "Saat 09:00. Coraspin 100 miligram alma zamanı." cümlesi.
  String get almaZamaniCumlesi =>
      'Saat $saatYazisi. '
      '${ilacAdi == null ? 'İlacınızı' : kisaAd(ilacAdi!)} alma zamanı.';

  /// Kayıtlı kutunun son kullanma tarihi geçtiyse ya da [sktUyariEsigi]
  /// günden az kaldıysa uyarı cümlesi; değilse `null`.
  String? sktCumlesi({DateTime? bugun}) {
    final skt = sonKullanma;
    if (skt == null) return null;
    final kalan = sktKalanGun(skt, bugun: bugun);
    if (kalan > sktUyariEsigi) return null;
    final bas = 'Dikkat, $okunacakAd için kayıtlı kutunun son kullanma tarihi';
    if (kalan < 0) return '$bas geçmiş (${gunAyYilYaz(skt)}).';
    if (kalan == 0) return '$bas bugün.';
    return '${bas}ne $kalan gün kaldı (${gunAyYilYaz(skt)}).';
  }

  Hatirlatma kopyala({
    DateTime? sonAlim,
    DateTime? sonErteleme,
    DateTime? sonKullanma,
  }) => Hatirlatma(
    id: id,
    saat: saat,
    dakika: dakika,
    gtin: gtin,
    ilacAdi: ilacAdi,
    sonAlim: sonAlim ?? this.sonAlim,
    sonErteleme: sonErteleme ?? this.sonErteleme,
    sonKullanma: sonKullanma ?? this.sonKullanma,
  );

  Map<String, dynamic> jsona() => {
    'id': id,
    'saat': saat,
    'dakika': dakika,
    'gtin': gtin,
    'ilacAdi': ilacAdi,
    'sonAlim': sonAlim?.toIso8601String(),
    'sonErteleme': sonErteleme?.toIso8601String(),
    'sonKullanma': sonKullanma?.toIso8601String(),
  };

  static DateTime? _tarih(Object? deger) =>
      deger is String ? DateTime.tryParse(deger) : null;
}

/// Hatırlatma listesi. Saf Dart'tır; saklama işini [AjandaDeposu] yapar.
class Ajanda {
  Ajanda([List<Hatirlatma>? hatirlatmalar]) : _liste = [...?hatirlatmalar];

  factory Ajanda.jsondan(String metin) {
    final liste = jsonDecode(metin) as List<dynamic>;
    return Ajanda(
      liste.map((e) => Hatirlatma.jsondan(e as Map<String, dynamic>)).toList(),
    );
  }

  final List<Hatirlatma> _liste;

  bool get bosMu => _liste.isEmpty;
  int get adet => _liste.length;

  /// Saat sırasına göre hatırlatmalar.
  List<Hatirlatma> get sirali => [..._liste]
    ..sort((a, b) {
      final fark = (a.saat * 60 + a.dakika) - (b.saat * 60 + b.dakika);
      return fark != 0 ? fark : a.id.compareTo(b.id);
    });

  Hatirlatma? bul(int id) {
    for (final h in _liste) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Yeni hatırlatma ekler. Aynı ilaç için aynı saatte zaten varsa onu
  /// döner (son kullanma tarihini güncelleyerek) ve `yeni` alanı `false` olur.
  ({Hatirlatma hatirlatma, bool yeni}) ekle({
    required int saat,
    required int dakika,
    String? gtin,
    String? ilacAdi,
    DateTime? sonKullanma,
  }) {
    for (final h in _liste) {
      if (h.saat == saat && h.dakika == dakika && h.gtin == gtin) {
        final guncel = h.kopyala(sonKullanma: sonKullanma);
        guncelle(guncel);
        return (hatirlatma: guncel, yeni: false);
      }
    }
    final enBuyuk = _liste.fold<int>(0, (m, h) => h.id > m ? h.id : m);
    final h = Hatirlatma(
      id: enBuyuk + 1,
      saat: saat,
      dakika: dakika,
      gtin: gtin,
      ilacAdi: ilacAdi,
      sonKullanma: sonKullanma,
    );
    _liste.add(h);
    return (hatirlatma: h, yeni: true);
  }

  /// Hatırlatmayı siler; silineni döner (yoksa `null`).
  Hatirlatma? sil(int id) {
    final h = bul(id);
    if (h != null) _liste.removeWhere((e) => e.id == id);
    return h;
  }

  void guncelle(Hatirlatma yeni) {
    final i = _liste.indexWhere((e) => e.id == yeni.id);
    if (i >= 0) _liste[i] = yeni;
  }

  /// Aynı ilacın (aynı GTIN) yeni bir kutusu okutulunca, o ilacın
  /// hatırlatmalarındaki son kullanma tarihini günceller. Değişenleri döner.
  List<Hatirlatma> sktGuncelle(String barkod, DateTime skt) {
    final degisenler = <Hatirlatma>[];
    for (final h in [..._liste]) {
      if (IlacVeritabani.ayniUrun(h.gtin, barkod) && h.sonKullanma != skt) {
        final guncel = h.kopyala(sonKullanma: skt);
        guncelle(guncel);
        degisenler.add(guncel);
      }
    }
    return degisenler;
  }

  /// "dokuzdaki hatırlatmayı sil" için eşleşenleri bulur. Sabah/akşam
  /// söylenmediyse 09:00 ile 21:00'in ikisi de eşleşir; dakika
  /// söylenmediyse o saatteki tüm dakikalar eşleşir.
  List<Hatirlatma> saateGoreBul(SaatBilgisi aranan) {
    bool saatUyar(int saat) {
      if (aranan.donemBelirtildi) return saat == aranan.saat;
      return saat % 12 == aranan.saat % 12;
    }

    return sirali
        .where(
          (h) =>
              saatUyar(h.saat) &&
              (!aranan.dakikaBelirtildi || h.dakika == aranan.dakika),
        )
        .toList();
  }

  /// Şu anki zamana en yakın hatırlatma: saati 2 saat öncesi ile 1 saat
  /// sonrası arasında olan. "Aldım" denince hangi ilaç olduğunu bulmak için.
  Hatirlatma? simdikiHatirlatma(DateTime simdi) {
    final liste = simdikiHatirlatmalar(simdi);
    return liste.isEmpty ? null : liste.first;
  }

  /// Saati şu an civarında (2 saat önce ile 1 saat sonra arası) olan
  /// hatırlatmalar, şu ana en yakın olan önce.
  List<Hatirlatma> simdikiHatirlatmalar(DateTime simdi) {
    final simdiDakika = simdi.hour * 60 + simdi.minute;
    int fark(Hatirlatma h) {
      // Gece yarısını aşan farkları da doğru hesapla.
      var f = simdiDakika - (h.saat * 60 + h.dakika);
      if (f > 720) f -= 1440;
      if (f < -720) f += 1440;
      return f;
    }

    return _liste.where((h) => fark(h) >= -60 && fark(h) <= 120).toList()
      ..sort((a, b) => fark(a).abs().compareTo(fark(b).abs()));
  }

  /// Hatırlatma saatinde bir kutu okutulunca doğru ilaç mı diye bakar.
  ///
  /// Bildirime dokunularak açıldıysa [bildirimId] o hatırlatmadır; yoksa
  /// saati şu an civarında olan hatırlatmalara bakılır. Şu an bekleyen bir
  /// hatırlatma yoksa `null` döner.
  ({bool dogru, Hatirlatma hatirlatma})? ilacKontrolu(
    String? barkod,
    DateTime simdi, {
    int? bildirimId,
  }) {
    final bildirimdeki = bildirimId == null ? null : bul(bildirimId);
    final adaylar =
        (bildirimdeki != null ? [bildirimdeki] : simdikiHatirlatmalar(simdi))
            .where((h) => h.gtin != null)
            .toList();
    if (adaylar.isEmpty || barkod == null) return null;
    for (final h in adaylar) {
      if (IlacVeritabani.ayniUrun(h.gtin, barkod)) {
        return (dogru: true, hatirlatma: h);
      }
    }
    return (dogru: false, hatirlatma: adaylar.first);
  }

  /// Kontrol sonucunun söylenecek cümlesi.
  static String ilacKontrolCumlesi(({bool dogru, Hatirlatma hatirlatma}) k) =>
      k.dogru
      ? 'Evet, doğru ilaç.'
      : 'Dikkat, bu hatırlatılan ilaç değil. Şu an hatırlatılan: '
            '${k.hatirlatma.okunacakAd}.';

  /// Ajandanın sesli okunacak metni. Son kullanma tarihi yaklaşan ya da
  /// geçen kutular için sonda uyarı eklenir.
  String okunacakMetin({DateTime? bugun}) {
    if (_liste.isEmpty) return 'Kurulu hatırlatmanız yok.';
    final parcalar = sirali.map(
      (h) =>
          '${gununBolumu(h.saat)} ${ekliSaatMetni(h.saat, h.dakika)} '
          '${h.okunacakAd}',
    );
    final uyarilar = {for (final h in sirali) ?h.sktCumlesi(bugun: bugun)}
        .join(' ');
    return '${_liste.length} hatırlatmanız var. ${parcalar.join('. ')}.'
        '${uyarilar.isEmpty ? '' : ' $uyarilar'}';
  }

  /// "Bugün ilacımı aldım mı?" sorusunun cevabı. Yalnızca kayıtları
  /// söyler; ilacın alınıp alınmaması konusunda öneri vermez.
  ///
  /// [kayitlar], [AjandaDeposu.alimKayitlari] biçimindedir: "zaman|id".
  String bugunkuAlimOzeti(List<String> kayitlar, DateTime simdi) {
    bool bugunMu(DateTime t) =>
        t.year == simdi.year && t.month == simdi.month && t.day == simdi.day;

    // Bugünkü kayıtlar: hatırlatma numarası → kayıt saatleri.
    final hatirlatmaya = <int, List<DateTime>>{};
    final digerleri = <DateTime>[];
    for (final kayit in kayitlar) {
      final parca = kayit.split('|');
      final zaman = DateTime.tryParse(parca.first)?.toLocal();
      if (zaman == null || !bugunMu(zaman)) continue;
      final id = parca.length > 1 ? int.tryParse(parca[1]) : null;
      if (id != null && bul(id) != null) {
        (hatirlatmaya[id] ??= []).add(zaman);
      } else {
        digerleri.add(zaman);
      }
    }

    String saatte(DateTime t) => ekliSaatMetni(t.hour, t.minute);
    final cumleler = <String>[];
    for (final h in sirali) {
      final bas = '${gununBolumu(h.saat)} ${h.saatYazisi} ${h.okunacakAd}: ';
      final alimlar = hatirlatmaya[h.id];
      final saatGeldi =
          simdi.hour * 60 + simdi.minute >= h.saat * 60 + h.dakika;
      if (alimlar != null) {
        cumleler.add('${bas}aldınız, saat ${saatte(alimlar.last)}.');
      } else if (saatGeldi) {
        cumleler.add('${bas}aldım kaydı yok.');
      } else {
        cumleler.add('${bas}saati henüz gelmedi.');
      }
    }
    if (digerleri.isNotEmpty) {
      final saatler = digerleri.map(saatte).join(', ');
      cumleler.add(
        _liste.isEmpty
            ? 'Bugün ${digerleri.length} aldım kaydı var: saat $saatler.'
            : 'Ayrıca bugün hatırlatma dışında ${digerleri.length} aldım '
                  'kaydı var: saat $saatler.',
      );
    }
    if (cumleler.isEmpty) return 'Bugün için aldım kaydı yok.';
    return 'Bugünkü kayıtlarınız. ${cumleler.join(' ')}';
  }

  String jsona() => jsonEncode(_liste.map((h) => h.jsona()).toList());
}

/// Ajandayı ve "aldım" kayıtlarını telefonda saklar (shared_preferences).
class AjandaDeposu {
  static const _ajandaAnahtari = 'hatirlatmalar';
  static const _alimAnahtari = 'alim_gecmisi';
  static const _enFazlaAlimKaydi = 500;

  Future<SharedPreferences> _tercihler() async {
    final t = await SharedPreferences.getInstance();
    // Bildirim düğmeleri ayrı bir arka plan sürecinde çalışabilir;
    // onların yazdıklarını görmek için önbelleği tazele.
    await t.reload();
    return t;
  }

  Future<Ajanda> yukle() async {
    final metin = (await _tercihler()).getString(_ajandaAnahtari);
    if (metin == null || metin.isEmpty) return Ajanda();
    try {
      return Ajanda.jsondan(metin);
    } catch (_) {
      return Ajanda();
    }
  }

  Future<void> kaydet(Ajanda ajanda) async {
    await (await _tercihler()).setString(_ajandaAnahtari, ajanda.jsona());
  }

  /// "Aldım" kaydı ekler. Kayıtlar "zaman|hatırlatmaId" biçimindedir.
  Future<void> alimKaydet(DateTime zaman, {int? hatirlatmaId}) async {
    final t = await _tercihler();
    final kayitlar = t.getStringList(_alimAnahtari) ?? [];
    kayitlar.add('${zaman.toIso8601String()}|${hatirlatmaId ?? ''}');
    if (kayitlar.length > _enFazlaAlimKaydi) {
      kayitlar.removeRange(0, kayitlar.length - _enFazlaAlimKaydi);
    }
    await t.setStringList(_alimAnahtari, kayitlar);
  }

  Future<List<String>> alimKayitlari() async =>
      (await _tercihler()).getStringList(_alimAnahtari) ?? [];
}
