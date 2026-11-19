/// Türkçe metin işleme için küçük yardımcılar.
library;

/// Türkçeye uygun küçük harfe çevirir ("I" → "ı", "İ" → "i").
String kucukHarf(String metin) => metin
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase()
    // Bazı sistemler "İ"yi "i" + birleşik nokta olarak küçültür.
    .replaceAll('̇', '');

/// Metni küçük harfli kelimelere böler. Kesme işaretleri silinir
/// ("9'da" → "9da"), "9:30" ve "9.30" gibi saatler tek parça kalır.
List<String> kelimeler(String metin) {
  final temiz = kucukHarf(metin).replaceAll(RegExp(r"['’`´]"), '');
  return temiz
      .split(RegExp(r'[^a-zçğıöşüâîû0-9:.]+'))
      .map((k) => k.replaceAll(RegExp(r'^[.:]+|[.:]+$'), ''))
      .where((k) => k.isNotEmpty)
      .toList();
}

const _birler = [
  'sıfır',
  'bir',
  'iki',
  'üç',
  'dört',
  'beş',
  'altı',
  'yedi',
  'sekiz',
  'dokuz',
];
const _onlar = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli'];

/// 0-59 arası sayının okunuşundaki son kelime ("15" → "beş").
String _sonKelime(int sayi) {
  if (sayi == 0) return 'sıfır';
  if (sayi % 10 != 0) return _birler[sayi % 10];
  return _onlar[sayi ~/ 10];
}

/// Bir kelimeye ünlü uyumuna göre "-de/-da/-te/-ta" ekini seçer.
String bulunmaEki(String kelime) {
  final unluler = RegExp('[aıoueiöü]');
  final sonUnlu = unluler
      .allMatches(kelime)
      .map((m) => m.group(0)!)
      .lastWhere((_) => true, orElse: () => 'e');
  final kalin = 'aıou'.contains(sonUnlu);
  final sert = 'çfhkpsşt'.contains(kelime[kelime.length - 1]);
  return '${sert ? 't' : 'd'}${kalin ? 'a' : 'e'}';
}

/// "09:00" biçiminde saat yazar.
String saatMetni(int saat, int dakika) =>
    '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}';

/// "09:00'da", "20:00'de", "09:15'te" biçiminde, ekiyle saat yazar.
String ekliSaatMetni(int saat, int dakika) {
  final okunus = _sonKelime(dakika == 0 ? saat % 24 : dakika);
  return "${saatMetni(saat, dakika)}'${bulunmaEki(okunus)}";
}

/// Saate göre günün bölümü: sabah, öğlen, öğleden sonra, akşam, gece.
String gununBolumu(int saat) {
  if (saat >= 5 && saat < 12) return 'sabah';
  if (saat >= 12 && saat < 14) return 'öğlen';
  if (saat >= 14 && saat < 18) return 'öğleden sonra';
  if (saat >= 18 && saat < 22) return 'akşam';
  return 'gece';
}
