import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/ajanda.dart';
import 'package:ilac_asistani/ilac_veritabani.dart';
import 'package:ilac_asistani/saat_ayristir.dart';
import 'package:ilac_asistani/zamanlama.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzveri;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('Ajanda ekleme', () {
    test('yeni hatırlatma eklenir, numara artar, GTIN saklanır', () {
      final a = Ajanda();
      final ilk = a.ekle(saat: 9, dakika: 0, gtin: '08699536090115');
      final ikinci = a.ekle(saat: 20, dakika: 0, gtin: '08699536090122');
      expect(ilk.yeni, isTrue);
      expect(ilk.hatirlatma.id, 1);
      expect(ikinci.hatirlatma.id, 2);
      expect(a.adet, 2);
      expect(a.bul(1)!.gtin, '08699536090115');
    });

    test('aynı ilaç aynı saate iki kez eklenmez', () {
      final a = Ajanda()..ekle(saat: 9, dakika: 0, gtin: 'X');
      final tekrar = a.ekle(saat: 9, dakika: 0, gtin: 'X');
      expect(tekrar.yeni, isFalse);
      expect(a.adet, 1);
      // Başka ilaç aynı saate eklenebilir.
      expect(a.ekle(saat: 9, dakika: 0, gtin: 'Y').yeni, isTrue);
    });

    test('liste saat sırasıyla döner', () {
      final a = Ajanda()
        ..ekle(saat: 21, dakika: 0)
        ..ekle(saat: 8, dakika: 30)
        ..ekle(saat: 13, dakika: 0);
      expect(a.sirali.map((h) => h.saatYazisi), ['08:30', '13:00', '21:00']);
    });

    test('ajanda saat sırasıyla sesli okunur', () {
      final a = Ajanda()
        ..ekle(saat: 20, dakika: 0, ilacAdi: 'MAJEZIK 100 MG 15 FILM TABLET')
        ..ekle(saat: 9, dakika: 0);
      expect(
        a.okunacakMetin(),
        "2 hatırlatmanız var. sabah 09:00'da ilacınız. "
        "akşam 20:00'de Majezik 100 miligram.",
      );
      expect(Ajanda().okunacakMetin(), 'Kurulu hatırlatmanız yok.');
    });
  });

  group('Ajanda silme', () {
    late Ajanda a;
    setUp(() {
      a = Ajanda()
        ..ekle(saat: 9, dakika: 0)
        ..ekle(saat: 9, dakika: 30)
        ..ekle(saat: 21, dakika: 0)
        ..ekle(saat: 14, dakika: 0);
    });

    test('silinen döner, liste küçülür', () {
      final silinen = a.sil(3);
      expect(silinen!.saatYazisi, '21:00');
      expect(a.adet, 3);
      expect(a.sil(99), isNull);
    });

    test('"dokuzdaki" sabah ve akşamı birlikte bulur', () {
      final bulunan = a.saateGoreBul(
        saatiAyikla('dokuzdaki hatırlatmayı sil')!,
      );
      expect(bulunan.map((h) => h.saatYazisi), ['09:00', '09:30', '21:00']);
    });

    test('"akşam dokuzdaki" yalnızca 21:00\'i bulur', () {
      final bulunan = a.saateGoreBul(saatiAyikla('akşam dokuzdaki')!);
      expect(bulunan.map((h) => h.saatYazisi), ['21:00']);
    });

    test('"dokuz buçuktaki" yalnızca 09:30\'u bulur', () {
      final bulunan = a.saateGoreBul(saatiAyikla('dokuz buçuktaki')!);
      expect(bulunan.map((h) => h.saatYazisi), ['09:30']);
    });

    test('olmayan saat boş liste döner', () {
      expect(a.saateGoreBul(saatiAyikla('yedideki')!), isEmpty);
    });
  });

  test('"aldım" için şu anki hatırlatma bulunur', () {
    final a = Ajanda()
      ..ekle(saat: 9, dakika: 0)
      ..ekle(saat: 21, dakika: 0)
      ..ekle(saat: 23, dakika: 50);
    expect(a.simdikiHatirlatma(DateTime(2026, 1, 1, 9, 12))!.saat, 9);
    expect(a.simdikiHatirlatma(DateTime(2026, 1, 1, 8, 30))!.saat, 9);
    expect(a.simdikiHatirlatma(DateTime(2026, 1, 1, 15, 0)), isNull);
    // Gece yarısını aşan durum.
    expect(a.simdikiHatirlatma(DateTime(2026, 1, 2, 0, 20))!.saat, 23);
  });

  test('JSON ile kaydedip geri okuma', () {
    final a = Ajanda()..ekle(saat: 9, dakika: 0, gtin: 'G', ilacAdi: 'AD');
    final h = a.bul(1)!.kopyala(sonAlim: DateTime.utc(2026, 1, 1, 9, 5));
    a.guncelle(h);
    final b = Ajanda.jsondan(a.jsona());
    expect(b.bul(1)!.gtin, 'G');
    expect(b.bul(1)!.ilacAdi, 'AD');
    expect(b.bul(1)!.sonAlim, DateTime.utc(2026, 1, 1, 9, 5));
  });

  group('Kalıcı saklama (shared_preferences)', () {
    test('kaydedilen ajanda yeniden yüklenir', () async {
      SharedPreferences.setMockInitialValues({});
      final depo = AjandaDeposu();
      expect((await depo.yukle()).bosMu, isTrue);
      final a = Ajanda()..ekle(saat: 8, dakika: 0, gtin: '123');
      await depo.kaydet(a);
      final yuklenen = await depo.yukle();
      expect(yuklenen.sirali.single.gtin, '123');
      yuklenen.sil(1);
      await depo.kaydet(yuklenen);
      expect((await depo.yukle()).bosMu, isTrue);
    });

    test('aldım kaydı tutulur', () async {
      SharedPreferences.setMockInitialValues({});
      final depo = AjandaDeposu();
      await depo.alimKaydet(DateTime.utc(2026, 1, 1, 9), hatirlatmaId: 3);
      expect(await depo.alimKayitlari(), ['2026-01-01T09:00:00.000Z|3']);
    });

    test('bozuk kayıt uygulamayı çökertmez', () async {
      SharedPreferences.setMockInitialValues({'hatirlatmalar': '{bozuk'});
      expect((await AjandaDeposu().yukle()).bosMu, isTrue);
    });
  });

  group('Bildirim zamanları', () {
    late tz.Location istanbul;
    setUpAll(() {
      tzveri.initializeTimeZones();
      istanbul = tz.getLocation('Europe/Istanbul');
    });
    tz.TZDateTime saat(int g, int s, int d) =>
        tz.TZDateTime(istanbul, 2026, 11, g, s, d);

    test('saat henüz gelmediyse bugün, geçtiyse yarın', () {
      expect(sonrakiZaman(saat(19, 8, 0), 9, 0), saat(19, 9, 0));
      expect(sonrakiZaman(saat(19, 10, 0), 9, 0), saat(19 + 1, 9, 0));
    });

    test('10 ve 20 dakika sonraki tekrarlar', () {
      expect(sonrakiZaman(saat(19, 9, 5), 9, 0, ekDakika: 10), saat(19, 9, 10));
      expect(sonrakiZaman(saat(19, 9, 5), 9, 0, ekDakika: 20), saat(19, 9, 20));
    });

    test('"Aldım" denince bugünkü tekrarlar yarına kayar', () {
      final h = Hatirlatma(id: 1, saat: 9, dakika: 0, sonAlim: saat(19, 9, 3));
      final simdi = saat(19, 9, 4);
      expect(bugunYapildiMi(h.sonAlim, h, simdi), isTrue);
      expect(
        sonrakiZaman(simdi, 9, 0, ekDakika: 10, bugunuAtla: true),
        saat(20, 9, 10),
      );
      // Ertesi gün dünkü "aldım" sayılmaz.
      expect(bugunYapildiMi(h.sonAlim, h, saat(20, 7, 0)), isFalse);
    });
  });

  test('İlaç adı barkoddan ve karekod GTIN\'inden bulunur', () {
    final db = IlacVeritabani.metindenOlustur(
      '8699536090115\tMAJEZIK 100 MG 15 FILM TABLET\n',
    );
    expect(db.ad('8699536090115'), 'MAJEZIK 100 MG 15 FILM TABLET');
    expect(db.ad('08699536090115'), 'MAJEZIK 100 MG 15 FILM TABLET');
    expect(db.ad('0000'), isNull);
    expect(
      konusmaIcinAd('ASIST C 600 MG/300 MG TOZ (20 SASE)'),
      'asist c 600 miligram ve 300 miligram toz 20 sase',
    );
    expect(
      konusmaIcinAd('RIMONAL % 0.2 GOZ DAMLASI'),
      'rimonal yüzde 0.2 goz damlasi',
    );
  });
}
