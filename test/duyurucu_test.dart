import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/duyurucu.dart';

/// Hangi yoldan ne söylendiğini kaydeden sahte duyurucu.
class _Kayit {
  bool ekranOkuyucuAcik = false;
  final List<String> sesMotoru = [];
  final List<String> ekranOkuyucu = [];
  int susturma = 0;

  late final Duyurucu duyurucu = Duyurucu(
    sesMotoruylaSoyle: (m) async => sesMotoru.add(m),
    sesMotorunuSustur: () async => susturma++,
    ekranOkuyucuyaDuyur: (m) async => ekranOkuyucu.add(m),
    ekranOkuyucuAcikMi: () => ekranOkuyucuAcik,
  );
}

void main() {
  test('TalkBack kapalıyken ses motoru (flutter_tts) kullanılır', () async {
    final k = _Kayit();
    expect(k.duyurucu.yol, DuyuruYolu.sesMotoru);
    expect(await k.duyurucu.duyur('Merhaba'), DuyuruYolu.sesMotoru);
    expect(k.sesMotoru, ['Merhaba']);
    expect(k.ekranOkuyucu, isEmpty);
  });

  test('TalkBack açıkken duyuru TalkBack\'e gider, TTS konuşmaz', () {
    fakeAsync((zaman) {
      final k = _Kayit()..ekranOkuyucuAcik = true;
      DuyuruYolu? sonuc;
      k.duyurucu.duyur('Son kullanma tarihi Mart 2027.').then((y) {
        sonuc = y;
      });
      zaman.flushMicrotasks();
      expect(k.ekranOkuyucu, ['Son kullanma tarihi Mart 2027.']);
      expect(k.sesMotoru, isEmpty);
      // TTS o an konuşuyorsa susturulur ki iki ses çakışmasın.
      expect(k.susturma, 1);
      // Okuma süresi dolana kadar bekler (mikrofon hemen açılmasın).
      expect(sonuc, isNull);
      zaman.elapse(
        Duyurucu.tahminiOkumaSuresi('Son kullanma tarihi Mart 2027.'),
      );
      expect(sonuc, DuyuruYolu.ekranOkuyucu);
    });
  });

  test('TalkBack açılıp kapanınca yol anında değişir', () async {
    final k = _Kayit();
    await k.duyurucu.duyur('bir');
    k.ekranOkuyucuAcik = true;
    expect(k.duyurucu.yol, DuyuruYolu.ekranOkuyucu);
    k.ekranOkuyucuAcik = false;
    await k.duyurucu.duyur('iki');
    expect(k.sesMotoru, ['bir', 'iki']);
  });

  test('Susturmak TalkBack beklemesini hemen bitirir', () {
    fakeAsync((zaman) {
      final k = _Kayit()..ekranOkuyucuAcik = true;
      var bitti = false;
      k.duyurucu.duyur('Uzun bir cümle ' * 10).then((_) => bitti = true);
      zaman.flushMicrotasks();
      expect(bitti, isFalse);
      k.duyurucu.sustur();
      zaman.flushMicrotasks();
      expect(bitti, isTrue);
    });
  });

  test('Okuma süresi tahmini metin uzadıkça artar, sınırlar içinde kalır', () {
    final kisa = Duyurucu.tahminiOkumaSuresi('Tamam');
    final uzun = Duyurucu.tahminiOkumaSuresi('Bu ilaç için ' * 5);
    expect(kisa, const Duration(seconds: 1));
    expect(uzun > kisa, isTrue);
    expect(
      Duyurucu.tahminiOkumaSuresi('a' * 5000),
      const Duration(seconds: 20),
    );
  });

  group('Türkçe ses kontrolü', () {
    test('mevcut ve yüklü ise hazır', () {
      expect(turkceSesHazirMi(mevcut: true, yuklu: true), isTrue);
      expect(turkceSesHazirMi(mevcut: 1, yuklu: 1), isTrue);
    });
    test('dil yoksa ya da ses verisi yüklenmemişse hazır değil', () {
      expect(turkceSesHazirMi(mevcut: false, yuklu: true), isFalse);
      expect(turkceSesHazirMi(mevcut: true, yuklu: false), isFalse);
      expect(turkceSesHazirMi(mevcut: 0, yuklu: null), isFalse);
    });
    test('bilinmiyorsa yanlış uyarı verilmez', () {
      expect(turkceSesHazirMi(), isTrue);
      expect(turkceSesHazirMi(mevcut: 'garip', yuklu: null), isTrue);
    });
  });
}
