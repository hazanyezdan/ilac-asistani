import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/ayarlar.dart';
import 'package:ilac_asistani/bip.dart';
import 'package:ilac_asistani/komutlar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Merkezi [merkez], kenarı [kenar] olan kare kodun köşeleri.
List<Offset> kare(Offset merkez, double kenar) {
  final y = kenar / 2;
  return [
    merkez + Offset(-y, -y),
    merkez + Offset(y, -y),
    merkez + Offset(y, y),
    merkez + Offset(-y, y),
  ];
}

void main() {
  const goruntu = Size(1000, 1000);
  const orta = Offset(500, 500);

  group('Bip aralığı (park sensörü)', () {
    test('kod kameraya yaklaştıkça bipler hızlanır', () {
      final uzak = bipAraligi(kare(orta, 50), goruntu)!;
      final orta1 = bipAraligi(kare(orta, 150), goruntu)!;
      final yakin = bipAraligi(kare(orta, 350), goruntu)!;
      expect(uzak > orta1, isTrue);
      expect(orta1 > yakin, isTrue);
    });

    test('kod ortaya geldikçe bipler hızlanır', () {
      final kenarda = bipAraligi(kare(const Offset(100, 100), 100), goruntu)!;
      final ortaya = bipAraligi(kare(const Offset(300, 300), 100), goruntu)!;
      final ortada = bipAraligi(kare(orta, 100), goruntu)!;
      expect(kenarda > ortaya, isTrue);
      expect(ortaya > ortada, isTrue);
    });

    test('tam ortada ve yakınken en hızlı, sınırlar aşılmaz', () {
      expect(bipAraligi(kare(orta, 400), goruntu), enKisaBipAraligi);
      final enYavas = bipAraligi(kare(Offset.zero, 2), goruntu)!;
      expect(enYavas <= enUzunBipAraligi, isTrue);
      expect(enYavas > const Duration(milliseconds: 900), isTrue);
    });

    test('köşe ya da görüntü boyutu yoksa hesaplanmaz', () {
      expect(bipAraligi([], goruntu), isNull);
      expect(bipAraligi(kare(orta, 10), Size.zero), isNull);
    });
  });

  group('15 saniye ipucu', () {
    final t0 = DateTime(2026, 1, 1, 10);
    DateTime sn(int s) => t0.add(Duration(seconds: s));

    test('15 saniye kod görülmezse ipucu verilir', () {
      final ipucu = AramaIpucu()..sifirla(t0);
      expect(ipucu.ipucuVerilsinMi(sn(14)), isFalse);
      expect(ipucu.ipucuVerilsinMi(sn(15)), isTrue);
      // Hemen ardından tekrar söylenmez.
      expect(ipucu.ipucuVerilsinMi(sn(16)), isFalse);
    });

    test('kod görülünce sayaç baştan başlar', () {
      final ipucu = AramaIpucu()..sifirla(t0);
      ipucu.sifirla(sn(10));
      expect(ipucu.ipucuVerilsinMi(sn(20)), isFalse);
      expect(ipucu.ipucuVerilsinMi(sn(25)), isTrue);
    });

    test('meşgul geçen süre sayılmaz', () {
      final ipucu = AramaIpucu()..sifirla(t0);
      ipucu.mesgulOldu(sn(12)); // ör. bir soru soruldu
      expect(ipucu.ipucuVerilsinMi(sn(20)), isFalse);
      expect(ipucu.ipucuVerilsinMi(sn(27)), isTrue);
    });

    test('30 saniyede bir tekrarlanır, en fazla 2 kez', () {
      final ipucu = AramaIpucu()..sifirla(t0);
      expect(ipucu.ipucuVerilsinMi(sn(15)), isTrue);
      expect(ipucu.ipucuVerilsinMi(sn(40)), isFalse);
      expect(ipucu.ipucuVerilsinMi(sn(45)), isTrue);
      expect(ipucu.ipucuVerilsinMi(sn(500)), isFalse);
      expect(ipucu.verilenIpucu, 2);
      // Kod görülünce yeniden ipucu verilebilir.
      ipucu.sifirla(sn(600));
      expect(ipucu.ipucuVerilsinMi(sn(615)), isTrue);
    });

    test('istenen ipucu cümlesi', () {
      expect(
        AramaIpucu.metin,
        'Kutuyu yavaşça çevirin, karekod genelde kutunun yan yüzündedir.',
      );
    });
  });

  group('Bip sesli komutları', () {
    test('kapatma ve açma', () {
      expect(komutuTani('bip sesini kapat').tur, KomutTuru.bipKapat);
      expect(komutuTani('bip sesini sustur').tur, KomutTuru.bipKapat);
      expect(komutuTani('bipleri kes').tur, KomutTuru.bipKapat);
      expect(komutuTani('bip sesini aç').tur, KomutTuru.bipAc);
      expect(komutuTani('Bip sesini aç').tur, KomutTuru.bipAc);
    });

    test('fener ve sus komutlarıyla karışmaz', () {
      expect(komutuTani('feneri kapat').tur, KomutTuru.fenerKapat);
      expect(komutuTani('sus').tur, KomutTuru.sus);
    });
  });

  group('Bip ayarı kalıcı saklanır', () {
    test('varsayılan açık, kapatılınca kapalı kalır', () async {
      SharedPreferences.setMockInitialValues({});
      final ayarlar = AyarDeposu();
      expect(await ayarlar.bipAcikMi(), isTrue);
      await ayarlar.bipAyarla(false);
      expect(await AyarDeposu().bipAcikMi(), isFalse);
      await ayarlar.bipAyarla(true);
      expect(await ayarlar.bipAcikMi(), isTrue);
    });
  });
}
