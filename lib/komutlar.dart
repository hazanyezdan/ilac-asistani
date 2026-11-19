/// Kullanıcının söylediği cümleden komut çıkaran saf Dart kodu.
library;

import 'saat_ayristir.dart';
import 'turkce.dart';

enum KomutTuru {
  tekrar,
  fenerAc,
  fenerKapat,
  ajandaOku,
  hatirlatmaKur,
  hatirlatmaSil,
  aldim,
  alimSorgula,
  ertele,
  kameraIzni,
  yardim,
  sus,
  bipAc,
  bipKapat,
  bilinmiyor,
}

class Komut {
  const Komut(this.tur, {this.saat});

  final KomutTuru tur;

  /// Cümlede bir saat geçiyorsa (ör. "dokuzdaki hatırlatmayı sil").
  final SaatBilgisi? saat;
}

enum Yanit { evet, hayir, belirsiz }

const Set<String> _hayirKelimeleri = {
  'hayır',
  'hayir',
  'istemiyorum',
  'istemem',
  'iptal',
  'vazgeç',
  'vazgeçtim',
  'yok',
  'onaylamıyorum',
  'kalsın',
  'kurma',
  'silme',
};

const Set<String> _evetKelimeleri = {
  'evet',
  'tamam',
  'olur',
  'onaylıyorum',
  'onayla',
  'onay',
  'isterim',
  'istiyorum',
  'peki',
  'aynen',
  'tabii',
  'tabi',
  'elbette',
  'kur',
  'kurulsun',
  'sil',
  'silinsin',
};

/// Evet/hayır sorusuna verilen cevabı anlar. "Hayır" önce aranır ki
/// "istemiyorum" gibi cevaplar yanlışlıkla evet sayılmasın.
Yanit yanitiAnla(String cumle) {
  final k = kelimeler(cumle);
  if (k.any(_hayirKelimeleri.contains)) return Yanit.hayir;
  if (k.any(_evetKelimeleri.contains)) return Yanit.evet;
  return Yanit.belirsiz;
}

bool _baslayan(List<String> k, List<String> onekler) =>
    k.any((kelime) => onekler.any(kelime.startsWith));

const Set<String> _soruEkleri = {'mı', 'mi', 'mu', 'mü', 'mıyım', 'miyim'};
const List<String> _almaFiilleri = ['aldım', 'aldim', 'içtim', 'ictim'];

/// "Bugün ilacımı aldım mı?", "ilacımı içtim mi", "bugün neleri aldım",
/// "ilaç geçmişim" gibi soruları tanır.
bool alimSorusuMu(List<String> k) {
  final almaFiili = _baslayan(k, _almaFiilleri);
  // "aldım mı" ya da bitişik yazılmış "aldımmı".
  final soruEki =
      k.any(_soruEkleri.contains) ||
      k.any(
        (w) =>
            _almaFiilleri.any(w.startsWith) &&
            _soruEkleri.any((e) => w.endsWith(e) && w.length > e.length + 3),
      );
  if (almaFiili && soruEki) return true;
  final soruKelimesi = _baslayan(k, ['ne', 'hangi', 'kaç']);
  if (almaFiili && soruKelimesi) return true;
  return _baslayan(k, ['geçmiş']) && _baslayan(k, ['ilaç', 'alım', 'alim']);
}

/// Cümleyi bir komuta çevirir.
Komut komutuTani(String cumle) {
  final k = kelimeler(cumle);
  if (k.isEmpty) return const Komut(KomutTuru.bilinmiyor);
  final saat = saatiAyikla(cumle);
  final hatirlatmaGeciyor = _baslayan(k, ['hatırlat', 'alarm', 'ajanda']);

  if (_baslayan(k, ['sil']) || (k.contains('iptal') && hatirlatmaGeciyor)) {
    return Komut(KomutTuru.hatirlatmaSil, saat: saat);
  }
  // "Bugün ilacımı aldım mı?" soru olduğu için "aldım" kaydından önce denenir.
  if (alimSorusuMu(k)) return const Komut(KomutTuru.alimSorgula);
  if (_baslayan(k, ['aldım', 'aldim', 'içtim', 'ictim'])) {
    return const Komut(KomutTuru.aldim);
  }
  if (_baslayan(k, ['ertele'])) return const Komut(KomutTuru.ertele);
  if (_baslayan(k, ['ajanda']) ||
      (hatirlatmaGeciyor &&
          _baslayan(k, ['oku', 'söyle', 'neler', 'listele', 'say']))) {
    return const Komut(KomutTuru.ajandaOku);
  }
  if (hatirlatmaGeciyor) return Komut(KomutTuru.hatirlatmaKur, saat: saat);
  // "bip sesini kapat" fener ya da "sus" komutlarından önce denenir.
  if (_baslayan(k, ['bip', 'bib'])) {
    return _baslayan(k, ['kapa', 'sus', 'kes', 'durdur', 'istemiyorum'])
        ? const Komut(KomutTuru.bipKapat)
        : const Komut(KomutTuru.bipAc);
  }
  if (_baslayan(k, ['fener', 'ışık', 'ışığ', 'lamba', 'flaş'])) {
    if (_baslayan(k, ['kapa', 'söndür'])) {
      return const Komut(KomutTuru.fenerKapat);
    }
    return const Komut(KomutTuru.fenerAc);
  }
  if (_baslayan(k, ['tekrar', 'yinele', 'yeniden', 'anlamadım']) ||
      k.join(' ').contains('bir daha')) {
    return const Komut(KomutTuru.tekrar);
  }
  if (_baslayan(k, ['kamera'])) return const Komut(KomutTuru.kameraIzni);
  if (_baslayan(k, ['yardım', 'komut', 'yapabil'])) {
    return const Komut(KomutTuru.yardim);
  }
  if (_baslayan(k, ['sus', 'yeter', 'sessiz']) ||
      (k.contains('dur') || k.contains('durdur'))) {
    return const Komut(KomutTuru.sus);
  }
  return const Komut(KomutTuru.bilinmiyor);
}

/// Uygulama konuşurken mikrofon uygulamanın kendi sesini de duyar.
/// Duyulan kelimelerden, o an söylenen metinde geçenleri çıkarır;
/// geriye kalan kullanıcının kendi sözüdür.
String yankidanArindir(String duyulan, String soylenen) {
  final soylenenler = kelimeler(soylenen).toSet();
  return kelimeler(duyulan).where((k) => !soylenenler.contains(k)).join(' ');
}

/// Araya girilen söz, konuşmayı kesmeye yetecek kadar anlamlı mı?
/// Tanınan bir komut, evet/hayır ya da en az iki yeni kelime olmalı.
bool sozKesmeyeYeterMi(String kullaniciSozu) {
  if (kullaniciSozu.trim().isEmpty) return false;
  return komutuTani(kullaniciSozu).tur != KomutTuru.bilinmiyor ||
      yanitiAnla(kullaniciSozu) != Yanit.belirsiz ||
      kelimeler(kullaniciSozu).length >= 2;
}
