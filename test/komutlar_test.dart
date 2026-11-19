import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/komutlar.dart';

void main() {
  group('Komut tanıma', () {
    const ornekler = {
      'tekrar söyle': KomutTuru.tekrar,
      'bir daha söyler misin': KomutTuru.tekrar,
      'feneri aç': KomutTuru.fenerAc,
      'ışığı yak': KomutTuru.fenerAc,
      'feneri kapat': KomutTuru.fenerKapat,
      'ajandamı oku': KomutTuru.ajandaOku,
      'hatırlatmalarımı söyle': KomutTuru.ajandaOku,
      'dokuzdaki hatırlatmayı sil': KomutTuru.hatirlatmaSil,
      'akşamki hatırlatmayı iptal et': KomutTuru.hatirlatmaSil,
      'her gün saat dokuzda hatırlat': KomutTuru.hatirlatmaKur,
      'aldım': KomutTuru.aldim,
      'ilacımı içtim': KomutTuru.aldim,
      'ertele': KomutTuru.ertele,
      'kamera izni': KomutTuru.kameraIzni,
      'yardım': KomutTuru.yardim,
      'sus': KomutTuru.sus,
      'bugün hava nasıl': KomutTuru.bilinmiyor,
    };
    ornekler.forEach((cumle, beklenen) {
      test('"$cumle" → $beklenen', () {
        expect(komutuTani(cumle).tur, beklenen);
      });
    });

    test('Silme komutu saati de taşır', () {
      expect(komutuTani('dokuzdaki hatırlatmayı sil').saat?.metin, '09:00');
      expect(komutuTani('akşam sekizde hatırlat').saat?.metin, '20:00');
    });
  });

  group('Evet / hayır', () {
    test('evet cevapları', () {
      for (final c in ['Evet', 'evet istiyorum', 'tamam', 'onaylıyorum']) {
        expect(yanitiAnla(c), Yanit.evet, reason: c);
      }
    });
    test('hayır cevapları, "istemiyorum" evet sayılmaz', () {
      for (final c in ['Hayır', 'istemiyorum', 'vazgeç', 'gerek yok']) {
        expect(yanitiAnla(c), Yanit.hayir, reason: c);
      }
    });
    test('anlaşılmayan', () {
      expect(yanitiAnla('bilmem ki'), Yanit.belirsiz);
      expect(yanitiAnla(''), Yanit.belirsiz);
    });
  });

  group('Araya girme (yankı ayıklama)', () {
    const soylenen =
        'Son kullanma tarihi Mart 2027. Bu ilaç için hatırlatma kurmak '
        'ister misiniz?';

    test('uygulamanın kendi sesi kullanıcı sözü sayılmaz', () {
      final kalan = yankidanArindir(
        'son kullanma tarihi mart 2027 bu ilaç için',
        soylenen,
      );
      expect(kalan, isEmpty);
      expect(sozKesmeyeYeterMi(kalan), isFalse);
    });

    test('kullanıcının komutu yankıdan ayrılır ve konuşmayı keser', () {
      final kalan = yankidanArindir('son kullanma tarihi feneri aç', soylenen);
      expect(kalan, 'feneri aç');
      expect(sozKesmeyeYeterMi(kalan), isTrue);
    });

    test('tek anlamsız kelime konuşmayı kesmez', () {
      expect(sozKesmeyeYeterMi('ııı'), isFalse);
      expect(sozKesmeyeYeterMi('evet'), isTrue);
    });
  });
}
