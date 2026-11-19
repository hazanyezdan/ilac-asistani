// Bu dosyadaki ilaç adları ve barkodlar TEST İÇİN UYDURULMUŞTUR; gerçek
// ilaçlara ait değildir.
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/ajanda.dart';
import 'package:ilac_asistani/karekod.dart';
import 'package:ilac_asistani/komutlar.dart';
import 'package:ilac_asistani/zamanlama.dart';
import 'package:timezone/data/latest.dart' as tzveri;
import 'package:timezone/timezone.dart' as tz;

const _ornekspirin = 'ORNEKSPIRIN 100 MG 30 ENTERIK KAPLI TABLET';
const _denemol = 'DENEMOL 500 MG 20 TABLET';

void main() {
  group('"Bugün ilacımı aldım mı?" komutu', () {
    const sorular = [
      'bugün ilacımı aldım mı',
      'İlacımı aldım mı?',
      'ilacımı içtim mi',
      'aldımmı',
      'bugün neleri aldım',
      'bugün hangi ilaçları aldım',
      'ilaç geçmişim',
    ];
    for (final soru in sorular) {
      test('"$soru" bir soru', () {
        expect(komutuTani(soru).tur, KomutTuru.alimSorgula);
      });
    }

    test('"aldım" demek hâlâ kayıt eder, soru sayılmaz', () {
      expect(komutuTani('aldım').tur, KomutTuru.aldim);
      expect(komutuTani('ilacımı aldım').tur, KomutTuru.aldim);
      expect(komutuTani('ilacımı içtim').tur, KomutTuru.aldim);
    });
  });

  group('Bugünkü alım özeti', () {
    late Ajanda a;
    setUp(() {
      a = Ajanda()
        ..ekle(
          saat: 9,
          dakika: 0,
          gtin: '08690000000011',
          ilacAdi: _ornekspirin,
        )
        ..ekle(saat: 20, dakika: 0, gtin: '08690000000035', ilacAdi: _denemol);
    });

    test('alınan, saati gelmeyen ve hatırlatma dışı kayıtlar', () {
      final ozet = a.bugunkuAlimOzeti([
        '2026-11-19T09:05:00.000|1',
        '2026-11-18T20:03:00.000|2', // dün: sayılmaz
        '2026-11-19T12:30:00.000|',
      ], DateTime(2026, 11, 19, 14));
      expect(
        ozet,
        "Bugünkü kayıtlarınız. sabah 09:00 Ornekspirin 100 miligram: "
        "aldınız, saat 09:05'te. akşam 20:00 Denemol 500 miligram: saati "
        "henüz gelmedi. Ayrıca bugün hatırlatma dışında 1 aldım kaydı var: "
        "saat 12:30'da.",
      );
    });

    test('saati geçmiş ama kaydı olmayan ilaç', () {
      final ozet = a.bugunkuAlimOzeti([
        '2026-11-19T09:05:00.000|1',
      ], DateTime(2026, 11, 19, 21));
      expect(ozet, contains('Denemol 500 miligram: aldım kaydı yok.'));
    });

    test('silinmiş hatırlatmanın kaydı "hatırlatma dışı" sayılır', () {
      final ozet = a.bugunkuAlimOzeti([
        '2026-11-19T07:00:00.000|99',
      ], DateTime(2026, 11, 19, 8));
      expect(ozet, contains("1 aldım kaydı var: saat 07:00'de."));
    });

    test('hatırlatma ve kayıt yoksa', () {
      expect(
        Ajanda().bugunkuAlimOzeti([], DateTime(2026, 11, 19)),
        'Bugün için aldım kaydı yok.',
      );
    });

    test('hatırlatma yok ama kayıt var', () {
      expect(
        Ajanda().bugunkuAlimOzeti([
          '2026-11-19T08:00:00.000|',
          '2026-11-19T13:15:00.000|',
        ], DateTime(2026, 11, 19, 15)),
        "Bugünkü kayıtlarınız. Bugün 2 aldım kaydı var: saat 08:00'de, "
        "13:15'te.",
      );
    });

    test('bozuk kayıtlar atlanır', () {
      expect(
        Ajanda().bugunkuAlimOzeti(['bozuk', '|', ''], DateTime(2026, 11, 19)),
        'Bugün için aldım kaydı yok.',
      );
    });

    test('özet öneri ya da tavsiye içermez', () {
      final ozet = a
          .bugunkuAlimOzeti([], DateTime(2026, 11, 19, 21))
          .toLowerCase();
      for (final yasak in ['alabilirsiniz', 'alın', 'almayın', 'doz']) {
        expect(ozet, isNot(contains(yasak)));
      }
    });
  });

  group('Son kullanma tarihi yaklaşıyor', () {
    final bugun = DateTime(2026, 11, 19, 23, 59);

    test('kalan gün hesabı (saat farkı sayıyı bozmaz)', () {
      expect(sktKalanGun(DateTime(2026, 12, 1), bugun: bugun), 12);
      expect(sktKalanGun(DateTime(2026, 11, 19), bugun: bugun), 0);
      expect(sktKalanGun(DateTime(2026, 11, 18), bugun: bugun), -1);
    });

    test('30 gün ve altında uyarı, üstünde ya da geçmişte yok', () {
      expect(
        sktYaklasiyorUyarisi(DateTime(2026, 12, 20), bugun: bugun),
        isNull,
      );
      expect(
        sktYaklasiyorUyarisi(DateTime(2026, 12, 19), bugun: bugun),
        'Dikkat, son kullanma tarihine 30 gün kaldı.',
      );
      expect(
        sktYaklasiyorUyarisi(DateTime(2026, 11, 19), bugun: bugun),
        'Dikkat, bugün son kullanma tarihinin son günü.',
      );
      expect(sktYaklasiyorUyarisi(DateTime(2026, 11, 1), bugun: bugun), isNull);
    });

    test('kutu okutulunca uyarı cümlenin sonuna eklenir', () {
      const ham =
          '0108690000000011'
          '21S1\u001d'
          '17261205'
          '10L1';
      expect(
        sesliMetinHazirla(
          ham,
          bugun: bugun,
          ilacAdi: 'Ornekspirin 100 miligram',
        ),
        'Ornekspirin 100 miligram. Son kullanma tarihi Aralık 2026. '
        'Dikkat, son kullanma tarihine 16 gün kaldı.',
      );
    });

    test('tarihi uzak ya da geçmiş kutuda bu uyarı yok', () {
      const uzak =
          '0108690000000011'
          '21S1\u001d'
          '17270331'
          '10L1';
      expect(sesliMetinHazirla(uzak, bugun: bugun), isNot(contains('kaldı')));
      const gecmis =
          '0108690000000011'
          '21S1\u001d'
          '17251031'
          '10L1';
      expect(
        sesliMetinHazirla(gecmis, bugun: bugun),
        'Dikkat! Bu ilacın son kullanma tarihi geçmiş. '
        'Son kullanma tarihi Ekim 2025.',
      );
    });

    test('tarih "31 Mart 2027" biçiminde yazılır', () {
      expect(gunAyYilYaz(DateTime(2027, 3, 31)), '31 Mart 2027');
    });
  });

  group('Hatırlatmada kayıtlı kutunun son kullanma tarihi', () {
    final bugun = DateTime(2026, 11, 19);

    Hatirlatma h(DateTime? skt) => Hatirlatma(
      id: 1,
      saat: 9,
      dakika: 0,
      gtin: '08690000000011',
      ilacAdi: _ornekspirin,
      sonKullanma: skt,
    );

    test('uyarı cümleleri', () {
      expect(h(null).sktCumlesi(bugun: bugun), isNull);
      expect(h(DateTime(2027, 3, 31)).sktCumlesi(bugun: bugun), isNull);
      expect(
        h(DateTime(2026, 12, 1)).sktCumlesi(bugun: bugun),
        'Dikkat, Ornekspirin 100 miligram için kayıtlı kutunun son kullanma '
        'tarihine 12 gün kaldı (1 Aralık 2026).',
      );
      expect(
        h(DateTime(2026, 11, 19)).sktCumlesi(bugun: bugun),
        'Dikkat, Ornekspirin 100 miligram için kayıtlı kutunun son kullanma '
        'tarihi bugün.',
      );
      expect(
        h(DateTime(2026, 10, 31)).sktCumlesi(bugun: bugun),
        'Dikkat, Ornekspirin 100 miligram için kayıtlı kutunun son kullanma '
        'tarihi geçmiş (31 Ekim 2026).',
      );
    });

    test('hatırlatma kurulurken tarih saklanır, JSON ile korunur', () {
      final a = Ajanda()
        ..ekle(
          saat: 9,
          dakika: 0,
          gtin: '08690000000011',
          sonKullanma: DateTime(2027, 3, 31),
        );
      final b = Ajanda.jsondan(a.jsona());
      expect(b.bul(1)!.sonKullanma, DateTime(2027, 3, 31));
    });

    test('aynı hatırlatma yeniden kurulursa tarih güncellenir', () {
      final a = Ajanda()
        ..ekle(
          saat: 9,
          dakika: 0,
          gtin: 'G',
          sonKullanma: DateTime(2026, 12, 1),
        );
      final tekrar = a.ekle(
        saat: 9,
        dakika: 0,
        gtin: 'G',
        sonKullanma: DateTime(2028, 1, 31),
      );
      expect(tekrar.yeni, isFalse);
      expect(a.bul(1)!.sonKullanma, DateTime(2028, 1, 31));
    });

    test('yeni kutu okutulunca o ilacın hatırlatmaları güncellenir', () {
      final a = Ajanda()
        ..ekle(saat: 9, dakika: 0, gtin: '08690000000011')
        ..ekle(saat: 21, dakika: 0, gtin: '08690000000011')
        ..ekle(saat: 13, dakika: 0, gtin: '08690000000035');
      // Kutudaki 13 haneli barkod da karekoddaki GTIN ile eşleşir.
      final degisen = a.sktGuncelle('8690000000011', DateTime(2027, 6, 30));
      expect(degisen.map((h) => h.id), [1, 2]);
      expect(a.bul(3)!.sonKullanma, isNull);
      // Aynı tarih tekrar okutulursa değişiklik yok.
      expect(a.sktGuncelle('8690000000011', DateTime(2027, 6, 30)), isEmpty);
    });

    test('ajanda okunurken yaklaşan tarih için uyarı eklenir', () {
      final a = Ajanda()
        ..ekle(
          saat: 9,
          dakika: 0,
          gtin: 'G',
          ilacAdi: _ornekspirin,
          sonKullanma: DateTime(2026, 12, 1),
        );
      expect(
        a.okunacakMetin(bugun: bugun),
        "1 hatırlatmanız var. sabah 09:00'da Ornekspirin 100 miligram. "
        'Dikkat, Ornekspirin 100 miligram için kayıtlı kutunun son kullanma '
        'tarihine 12 gün kaldı (1 Aralık 2026).',
      );
    });
  });

  group('Son kullanma bildirim zamanları', () {
    late tz.Location istanbul;
    setUpAll(() {
      tzveri.initializeTimeZones();
      istanbul = tz.getLocation('Europe/Istanbul');
    });

    tz.TZDateTime t(int y, int a, int g, [int s = 0]) =>
        tz.TZDateTime(istanbul, y, a, g, s);

    test('30 gün önce, 7 gün önce ve tarih geçince, saat 10:00', () {
      final z = sktUyariZamanlari(t(2026, 11, 19), DateTime(2027, 3, 31));
      expect(z.map((e) => e.kalanGun), [30, 7, -1]);
      expect(z.map((e) => e.zaman), [
        t(2027, 3, 1, 10),
        t(2027, 3, 24, 10),
        t(2027, 4, 1, 10),
      ]);
    });

    test('geçmişte kalan uyarılar kurulmaz', () {
      final z = sktUyariZamanlari(t(2027, 3, 10), DateTime(2027, 3, 31));
      expect(z.map((e) => e.kalanGun), [7, -1]);
      expect(sktUyariZamanlari(t(2027, 5, 1), DateTime(2027, 3, 31)), isEmpty);
    });

    test('bildirim günü söylenecek cümle doğru gün sayısını verir', () {
      const h = Hatirlatma(id: 1, saat: 9, dakika: 0, ilacAdi: _denemol);
      final kayitli = Hatirlatma(
        id: h.id,
        saat: h.saat,
        dakika: h.dakika,
        ilacAdi: h.ilacAdi,
        sonKullanma: DateTime(2027, 3, 31),
      );
      final z = sktUyariZamanlari(t(2026, 11, 19), DateTime(2027, 3, 31));
      expect(kayitli.sktCumlesi(bugun: z[0].zaman), contains('30 gün kaldı'));
      expect(kayitli.sktCumlesi(bugun: z[1].zaman), contains('7 gün kaldı'));
      expect(kayitli.sktCumlesi(bugun: z[2].zaman), contains('geçmiş'));
    });
  });
}
