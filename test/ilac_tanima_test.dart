// Bu dosyadaki ilaç kayıtları (barkod ve ad) TEST İÇİN UYDURULMUŞ ÖRNEKLERDİR;
// gerçek ilaçlara ait değildir. Gerçek liste assets/ilaclar.tsv dosyasındadır.
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/ajanda.dart';
import 'package:ilac_asistani/ilac_veritabani.dart';
import 'package:ilac_asistani/karekod.dart';
import 'package:ilac_asistani/yazi_eslestirme.dart';

/// Uydurma örnek liste (gerçek değil).
const _ornekListe =
    '8690000000011\tORNEKSPIRIN 100 MG 30 ENTERIK KAPLI TABLET\n'
    '8690000000028\tORNEKSPIRIN 300 MG 30 ENTERIK KAPLI TABLET\n'
    '8690000000035\tDENEMOL 500 MG 20 TABLET\n'
    '8690000000042\tDENEMOL PLUS 500 MG/30 MG 20 FILM TABLET\n'
    '8690000000059\tSAHTEKS %0,2 GOZ DAMLASI, COZELTI (1 SISE)\n'
    '8690000000066\tSODYUM KLORUR %0,9 ENJEKSIYONLUK COZELTI\n'
    '8690000000073\tUYDURAMIN 30 G KREM\n';

String karekod(String gtin14, {String skt = '270331'}) =>
    '01$gtin14'
    '21SERI1\u001d'
    '17$skt'
    '10L1';

void main() {
  final db = IlacVeritabani.metindenOlustur(_ornekListe);
  final bugun = DateTime(2026, 11, 19);

  group('Kısa ad (söylenecek ilaç adı)', () {
    test('paket bilgisi atılır, doz okunur', () {
      expect(
        kisaAd('ORNEKSPIRIN 100 MG 30 ENTERIK KAPLI TABLET'),
        'Ornekspirin 100 miligram',
      );
      expect(
        kisaAd('DENEMOL PLUS 500 MG/30 MG 20 FILM TABLET'),
        'Denemol plus 500 miligram ve 30 miligram',
      );
      expect(kisaAd('UYDURAMIN 30 G KREM'), 'Uyduramin 30 gram');
    });

    test('yüzdeli ve dozsuz adlar', () {
      expect(
        kisaAd('SAHTEKS %0,2 GOZ DAMLASI, COZELTI (1 SISE)'),
        'Sahteks yüzde 0,2',
      );
      expect(kisaAd('ORNEK IGNE UCU 32G (0,23 MM)'), 'Ornek igne ucu');
      expect(kisaAd('%5 DEKSTROZ COZELTISI'), 'Yüzde 5 dekstroz cozeltisi');
    });

    test('gerçek listedeki biçimle istenen örnek', () {
      expect(
        kisaAd('CORASPIN 100 MG 30 ENTERIK KAPLI TABLET'),
        'Coraspin 100 miligram',
      );
    });
  });

  group('Karekoddan ilaç adı (GTIN eşleştirme)', () {
    test('GTIN-14 ile 13 haneli barkod eşleşir', () {
      expect(db.ad('08690000000011'), contains('ORNEKSPIRIN 100'));
      expect(IlacVeritabani.ayniUrun('08690000000011', '8690000000011'), true);
      expect(IlacVeritabani.ayniUrun('08690000000011', '8690000000028'), false);
      expect(IlacVeritabani.ayniUrun(null, '8690000000028'), false);
    });

    test('ad bulunursa istenen cümle', () {
      final ham = karekod('08690000000011');
      final ad = db.ad(karekoduCoz(ham)!.gtin);
      expect(
        sesliMetinHazirla(ham, bugun: bugun, ilacAdi: kisaAd(ad!)),
        'Ornekspirin 100 miligram. Son kullanma tarihi Mart 2027.',
      );
    });

    test('listede yoksa söylenir', () {
      final ham = karekod('08699999999999');
      expect(db.ad(karekoduCoz(ham)!.gtin), isNull);
      expect(
        sesliMetinHazirla(ham, bugun: bugun, adListedeYok: true),
        'İlaç karekodu okundu ama ilacın adı listede yok. '
        'Son kullanma tarihi Mart 2027.',
      );
    });

    test('ilaç karekodu olmayan kodda "listede yok" denmez', () {
      expect(
        sesliMetinHazirla('merhaba', bugun: bugun, adListedeYok: true),
        'Kod okundu: merhaba',
      );
    });
  });

  group('Hatırlatma ilaç adıyla konuşur', () {
    test('alma zamanı cümlesi', () {
      const h = Hatirlatma(
        id: 1,
        saat: 9,
        dakika: 0,
        gtin: '08690000000011',
        ilacAdi: 'ORNEKSPIRIN 100 MG 30 ENTERIK KAPLI TABLET',
      );
      expect(
        h.almaZamaniCumlesi,
        'Saat 09:00. Ornekspirin 100 miligram alma zamanı.',
      );
      const adsiz = Hatirlatma(id: 2, saat: 20, dakika: 0);
      expect(adsiz.almaZamaniCumlesi, 'Saat 20:00. İlacınızı alma zamanı.');
    });
  });

  group('Hatırlatma saatinde doğru ilaç kontrolü', () {
    late Ajanda a;
    setUp(() {
      a = Ajanda()
        ..ekle(
          saat: 9,
          dakika: 0,
          gtin: '08690000000011',
          ilacAdi: 'ORNEKSPIRIN 100 MG 30 ENTERIK KAPLI TABLET',
        )
        ..ekle(
          saat: 21,
          dakika: 0,
          gtin: '08690000000035',
          ilacAdi: 'DENEMOL 500 MG 20 TABLET',
        );
    });

    test('doğru kutu: "Evet, doğru ilaç."', () {
      final k = a.ilacKontrolu('8690000000011', DateTime(2026, 1, 1, 9, 5))!;
      expect(k.dogru, isTrue);
      expect(Ajanda.ilacKontrolCumlesi(k), 'Evet, doğru ilaç.');
    });

    test('yanlış kutu: uyarı ve hatırlatılan ilacın adı', () {
      final k = a.ilacKontrolu('08690000000035', DateTime(2026, 1, 1, 8, 50))!;
      expect(k.dogru, isFalse);
      expect(
        Ajanda.ilacKontrolCumlesi(k),
        'Dikkat, bu hatırlatılan ilaç değil. Şu an hatırlatılan: '
        'Ornekspirin 100 miligram.',
      );
    });

    test('hatırlatma saati değilse kontrol yapılmaz', () {
      expect(a.ilacKontrolu('8690000000011', DateTime(2026, 1, 1, 15)), isNull);
    });

    test('bildirimden açıldıysa o hatırlatmaya bakılır', () {
      final k = a.ilacKontrolu(
        '8690000000035',
        DateTime(2026, 1, 1, 15),
        bildirimId: 2,
      )!;
      expect(k.dogru, isTrue);
    });
  });

  group('Kutu yazısından tahmin (OCR metni)', () {
    final indeks = db.markaIndeksi;

    test('marka ve doz yazıdan bulunur', () {
      const yazi =
          'Ornekspirin®\n100 mg\n30 enterik kaplı tablet\n'
          'Asetilsalisilik asit\nReçetesiz satılır';
      final e = yazidanIlacBul(yazi, indeks)!;
      expect(e.marka, 'ORNEKSPIRIN');
      expect(e.ad, contains('100 MG'));
      expect(
        e.cumle,
        'Karekod bulunamadı, kutunun yazısından okuyorum: muhtemelen '
        'Ornekspirin 100 miligram. Bu tahmin kesin değil, mümkünse karekodu '
        'okutun.',
      );
    });

    test('doz okunamazsa yalnızca marka söylenir', () {
      final e = yazidanIlacBul('ORNEKSPIRIN enterik tablet', indeks)!;
      expect(e.ad, isNull);
      expect(e.okunacakAd, 'Ornekspirin');
      expect(e.cumle, contains('muhtemelen Ornekspirin.'));
    });

    test('harf yerine okunan rakamlar düzeltilir (0→O, 1→I)', () {
      final e = yazidanIlacBul('0RNEKSP1RIN 300 mg', indeks)!;
      expect(e.marka, 'ORNEKSPIRIN');
      expect(e.ad, contains('300 MG'));
    });

    test('yazı tanıma hatalarına (bir iki harf) tolerans', () {
      final e = yazidanIlacBul('ORNEKSPRIN 300 mg', indeks);
      expect(e, isNotNull);
      expect(e!.marka, 'ORNEKSPIRIN');
      expect(e.yaklasik, isTrue);
      expect(e.ad, contains('300 MG'));
    });

    test('kısa kelimelerde fazla harf hatası kabul edilmez', () {
      expect(yazidanIlacBul('DENEMAL', indeks), isNotNull); // 7 harf: 1 hata
      expect(yazidanIlacBul('DENAMAL', indeks), isNull); // 2 hata: fazla
    });

    test('iki kelimelik marka tek kelimelikten önce gelir', () {
      final e = yazidanIlacBul('Denemol Plus 500 mg / 30 mg', indeks)!;
      expect(e.marka, 'DENEMOL PLUS');
    });

    test('Türkçe karakterler ve küçük harf sorun olmaz', () {
      expect(yazidanIlacBul('uyduramın krem 30 g', indeks)!.marka, 'UYDURAMIN');
    });

    test('genel kelimeler (sodyum klorür vb.) marka sayılmaz', () {
      expect(
        yazidanIlacBul('Yardımcı maddeler: sodyum klorür, laktoz', indeks),
        isNull,
      );
    });

    test('ilgisiz yazıda tahmin yapılmaz', () {
      expect(yazidanIlacBul('Kullanma talimatını okuyunuz', indeks), isNull);
      expect(yazidanIlacBul('', indeks), isNull);
    });

    test('iki farklı marka eşit güçteyse tahmin yapılmaz', () {
      expect(yazidanIlacBul('Ornekspirin Uyduramin', indeks), isNull);
    });

    test('cümle doz önerisi ya da tıbbi tavsiye içermez', () {
      final e = yazidanIlacBul('Denemol 500 mg', indeks)!;
      for (final yasak in ['günde', 'kez', 'alın', 'kullanın', 'doz']) {
        expect(e.cumle.toLowerCase(), isNot(contains(yasak)));
      }
    });

    test('harf farkı hesabı', () {
      expect(harfFarki('CORASPIN', 'CORASPIN'), 0);
      expect(harfFarki('C0RASPIN', 'CORASPIN'), 1);
      expect(harfFarki('CORASPN', 'CORASPIN'), 1);
      expect(harfFarki('ABC', 'XYZQWE', sinir: 2), 3);
    });
  });
}
