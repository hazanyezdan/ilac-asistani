/// Kamerada kod görülüp henüz okunamadığında "park sensörü" gibi bip
/// sesleriyle yönlendirme ve uzun süre kod bulunamazsa ipucu verme.
/// Saf Dart'tır; ses çalma işi uygulamada yapılır.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Bipler arası en kısa ve en uzun süre.
const Duration enKisaBipAraligi = Duration(milliseconds: 120);
const Duration enUzunBipAraligi = Duration(milliseconds: 1000);

/// Kodun kenarı görüntünün bu oranına ulaşınca "yeterince yakın" sayılır.
const double _hedefBoyutOrani = 0.35;

/// Kodun köşelerine ve kamera görüntüsünün boyutuna göre iki bip arasındaki
/// süreyi hesaplar. Kod ortaya ve kameraya yaklaştıkça süre kısalır.
/// Köşe ya da görüntü boyutu yoksa `null` döner.
Duration? bipAraligi(List<Offset> koseler, Size goruntu) {
  if (koseler.isEmpty || goruntu.isEmpty) return null;
  final kod = Rect.fromPoints(
    Offset(
      koseler.map((k) => k.dx).reduce(math.min),
      koseler.map((k) => k.dy).reduce(math.min),
    ),
    Offset(
      koseler.map((k) => k.dx).reduce(math.max),
      koseler.map((k) => k.dy).reduce(math.max),
    ),
  );

  // Merkeze uzaklık: 0 = tam ortada, 1 = köşede.
  final merkez = goruntu.center(Offset.zero);
  final yariKosegen = Offset(goruntu.width, goruntu.height).distance / 2;
  final uzaklik = ((kod.center - merkez).distance / yariKosegen).clamp(
    0.0,
    1.0,
  );

  // Yakınlık: kodun kenarının görüntüye oranı, hedefe göre 0..1.
  final boyutOrani = math.sqrt(
    (kod.width * kod.height) / (goruntu.width * goruntu.height),
  );
  final yakinlik = (boyutOrani / _hedefBoyutOrani).clamp(0.0, 1.0);

  final skor = 0.5 * (1 - uzaklik) + 0.5 * yakinlik;
  final aralik =
      enUzunBipAraligi.inMilliseconds -
      skor *
          (enUzunBipAraligi.inMilliseconds - enKisaBipAraligi.inMilliseconds);
  return Duration(milliseconds: aralik.round());
}

/// "15 saniyedir kod bulunamadı" ipucunun zamanlamasını tutar.
///
/// İlk ipucu, [ilkBekleme] boyunca boşta durup kod görülmezse verilir;
/// sonra her [sonrakiBekleme]'de bir tekrarlanır, en fazla [enFazla] kez.
/// Uygulamanın meşgul olduğu (konuştuğu, dinlediği) süre sayılmaz. Bir kod
/// görülünce her şey baştan başlar.
class AramaIpucu {
  AramaIpucu({
    this.ilkBekleme = const Duration(seconds: 15),
    this.sonrakiBekleme = const Duration(seconds: 30),
    this.enFazla = 2,
  });

  static const String metin =
      'Kutuyu yavaşça çevirin, karekod genelde kutunun yan yüzündedir.';

  final Duration ilkBekleme;
  final Duration sonrakiBekleme;
  final int enFazla;

  DateTime? _baslangic;
  int _verilen = 0;

  int get verilenIpucu => _verilen;

  /// Kod görüldü ya da okundu: her şeye baştan başla.
  void sifirla(DateTime simdi) {
    _baslangic = simdi;
    _verilen = 0;
  }

  /// Uygulama meşgul: boşta geçen süre sayacını yeniden başlat ama verilen
  /// ipucu sayısını unutma.
  void mesgulOldu(DateTime simdi) => _baslangic = simdi;

  /// Şimdi ipucu söylenmeli mi? `true` dönerse ipucu verilmiş sayılır.
  bool ipucuVerilsinMi(DateTime simdi) {
    final baslangic = _baslangic ??= simdi;
    if (_verilen >= enFazla) return false;
    final gereken = _verilen == 0 ? ilkBekleme : sonrakiBekleme;
    if (simdi.difference(baslangic) < gereken) return false;
    _verilen++;
    _baslangic = simdi;
    return true;
  }
}
