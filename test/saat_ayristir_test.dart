import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/saat_ayristir.dart';
import 'package:ilac_asistani/turkce.dart';

void main() {
  group('İstenen örnekler', () {
    const ornekler = {
      'her gün saat dokuzda hatırlat': '09:00',
      "her gün sabah 9'da": '09:00',
      'akşam sekizde hatırlat': '20:00',
      'saat dokuz buçukta': '09:30',
      'öğlen on ikide': '12:00',
      'gece on birde': '23:00',
    };
    ornekler.forEach((cumle, beklenen) {
      test('"$cumle" → $beklenen', () {
        expect(saatiAyikla(cumle)?.metin, beklenen);
      });
    });
  });

  group('Rakamlı ve diğer biçimler', () {
    const ornekler = {
      'Her gün 21:00 de hatırlat': '21:00',
      "saat 8.30'da": '08:30',
      'Akşam 9’da': '21:00',
      'AKŞAM SEKİZDE': '20:00',
      'dokuzu çeyrek geçe': '09:15',
      'dokuza çeyrek var': '08:45',
      'saat yedi otuzda': '07:30',
      'öğleden sonra üçte': '15:00',
      'gece ikide': '02:00',
      'sabah on birde': '11:00',
      'yirmi üçte': '23:00',
      'dörtte': '04:00',
      'dokuzdaki hatırlatmayı sil': '09:00',
      'bir hatırlatma kur saat dokuzda': '09:00',
    };
    ornekler.forEach((cumle, beklenen) {
      test('"$cumle" → $beklenen', () {
        expect(saatiAyikla(cumle)?.metin, beklenen);
      });
    });
  });

  test('Akşam/gece yoksa sabah varsayılır ve bu işaretlenir', () {
    final s = saatiAyikla('dokuzda hatırlat')!;
    expect(s.metin, '09:00');
    expect(s.donemBelirtildi, isFalse);
    expect(saatiAyikla('akşam dokuzda')!.donemBelirtildi, isTrue);
    expect(saatiAyikla('21:00')!.donemBelirtildi, isTrue);
  });

  test('Dakika söylendi mi bilgisi', () {
    expect(saatiAyikla('dokuzda')!.dakikaBelirtildi, isFalse);
    expect(saatiAyikla('dokuz buçukta')!.dakikaBelirtildi, isTrue);
  });

  test('Saat olmayan cümleler null döner', () {
    expect(saatiAyikla('hatırlatma kur'), isNull);
    expect(saatiAyikla('evet'), isNull);
    expect(saatiAyikla('bir daha söyle'), isNull);
    expect(saatiAyikla(''), isNull);
  });

  group('Onay cümlesi için Türkçe saat yazımı', () {
    test('ek ünlü uyumuna göre seçilir', () {
      expect(ekliSaatMetni(9, 0), "09:00'da");
      expect(ekliSaatMetni(20, 0), "20:00'de");
      expect(ekliSaatMetni(23, 0), "23:00'te");
      expect(ekliSaatMetni(9, 30), "09:30'da");
      expect(ekliSaatMetni(9, 15), "09:15'te");
      expect(ekliSaatMetni(12, 0), "12:00'de");
    });

    test('günün bölümü', () {
      expect(gununBolumu(9), 'sabah');
      expect(gununBolumu(12), 'öğlen');
      expect(gununBolumu(15), 'öğleden sonra');
      expect(gununBolumu(20), 'akşam');
      expect(gununBolumu(23), 'gece');
    });

    test('istenen onay cümlesi', () {
      final s = saatiAyikla('her gün saat dokuzda hatırlat')!;
      expect(
        'Her gün ${gununBolumu(s.saat)} ${ekliSaatMetni(s.saat, s.dakika)} '
            'hatırlatma kurulacak. Onaylıyor musunuz?',
        "Her gün sabah 09:00'da hatırlatma kurulacak. Onaylıyor musunuz?",
      );
    });
  });
}
