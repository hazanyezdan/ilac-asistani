/// İlaç karekodunu (GS1 DataMatrix) çözmek için yardımcı kodlar.
///
/// Türkiye'de ilaç kutularındaki karekodda bilgiler "uygulama tanımlayıcı"
/// (AI) denen iki haneli etiketlerle sıralanır:
///   01 → ürün numarası (GTIN, 14 hane)
///   21 → seri numarası (değişken uzunluk)
///   17 → son kullanma tarihi (YYAAGG, 6 hane)
///   10 → parti (lot) numarası (değişken uzunluk)
/// Değişken uzunluktaki alanlar "GS" (ASCII 29) karakteri ile biter.
library;

/// GS1 alan ayırıcı karakteri (FNC1 / GS, ASCII 29).
const String gs = '\u001d';

/// Sabit uzunluklu bilinen etiketler ve veri uzunlukları.
const Map<String, int> _sabitUzunluklar = {
  '00': 18,
  '01': 14,
  '02': 14,
  '11': 6,
  '12': 6,
  '13': 6,
  '15': 6,
  '16': 6,
  '17': 6,
};

/// Değişken uzunluklu bilinen etiketler.
const Set<String> _degiskenEtiketler = {'10', '21', '240', '241', '22'};

const List<String> _aylar = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Karekoddan okunan ilaç bilgileri.
class IlacKarekodu {
  const IlacKarekodu({this.gtin, this.seriNo, this.sonKullanma, this.partiNo});

  final String? gtin;
  final String? seriNo;

  /// Son kullanma tarihi. Gün "00" ise ayın son günü kabul edilir.
  final DateTime? sonKullanma;
  final String? partiNo;
}

/// Ham karekod metnini çözer. İlaç karekodu değilse `null` döner.
IlacKarekodu? karekoduCoz(String ham) {
  final alanlar = gs1AlanlariniAyikla(ham);
  if (alanlar == null || !alanlar.containsKey('01')) return null;
  final skt = alanlar['17'];
  return IlacKarekodu(
    gtin: alanlar['01'],
    seriNo: alanlar['21'],
    sonKullanma: skt == null ? null : tarihCoz(skt),
    partiNo: alanlar['10'],
  );
}

/// GS1 metnini etiket → değer haritasına çevirir.
///
/// Hem ham biçimi (`0108699...21ABC<GS>17270331...`) hem de
/// parantezli biçimi (`(01)08699...(17)270331`) destekler.
Map<String, String>? gs1AlanlariniAyikla(String ham) {
  var metin = ham.trim();
  // Bazı okuyucular başa sembol kimliği ekler: "]d2", "]C1", "]Q3".
  if (metin.startsWith(']') && metin.length > 3) metin = metin.substring(3);
  if (metin.startsWith(gs)) metin = metin.substring(1);

  if (metin.startsWith('(')) return _parantezliCoz(metin);

  final alanlar = <String, String>{};
  var i = 0;
  while (i < metin.length) {
    if (metin[i] == gs) {
      i++;
      continue;
    }
    final etiket = _etiketBul(metin, i);
    if (etiket == null) return alanlar.isEmpty ? null : alanlar;
    i += etiket.length;

    final sabit = _sabitUzunluklar[etiket];
    if (sabit != null) {
      if (i + sabit > metin.length) return alanlar.isEmpty ? null : alanlar;
      final deger = metin.substring(i, i + sabit);
      if (!_rakamMi(deger)) return alanlar.isEmpty ? null : alanlar;
      alanlar[etiket] = deger;
      i += sabit;
    } else {
      var son = metin.indexOf(gs, i);
      if (son == -1) {
        // Ayırıcı yoksa (bazı okuyucular GS'yi düşürür) seri numarasının
        // ardından gelen "17YYAAGG" kalıbını arayarak alanı kesmeyi dene.
        son = _ayiricisizSonuBul(metin, i, etiket);
      }
      alanlar[etiket] = metin.substring(i, son);
      i = son;
    }
  }
  return alanlar.isEmpty ? null : alanlar;
}

String? _etiketBul(String metin, int i) {
  for (final uzunluk in [2, 3]) {
    if (i + uzunluk > metin.length) break;
    final aday = metin.substring(i, i + uzunluk);
    if (_sabitUzunluklar.containsKey(aday) ||
        _degiskenEtiketler.contains(aday)) {
      return aday;
    }
  }
  return null;
}

/// GS ayırıcısı olmayan metinlerde değişken alanın nerede bittiğini tahmin
/// eder. Seri numarasından (21) sonra genellikle "17" + geçerli bir tarih ve
/// ardından "10" gelir; bu kalıp bulunursa alan orada kesilir.
int _ayiricisizSonuBul(String metin, int baslangic, String etiket) {
  if (etiket == '21') {
    final kalip = RegExp(r'17(\d{2})(\d{2})(\d{2})10');
    for (final m in kalip.allMatches(metin, baslangic)) {
      if (m.start > baslangic &&
          tarihCoz(metin.substring(m.start + 2, m.start + 8)) != null) {
        return m.start;
      }
    }
  }
  return metin.length;
}

Map<String, String>? _parantezliCoz(String metin) {
  final alanlar = <String, String>{};
  for (final m in RegExp(r'\((\d{2,4})\)([^(]*)').allMatches(metin)) {
    alanlar[m.group(1)!] = m.group(2)!.replaceAll(gs, '').trim();
  }
  return alanlar.isEmpty ? null : alanlar;
}

bool _rakamMi(String s) => RegExp(r'^\d+$').hasMatch(s);

/// "YYAAGG" biçimindeki GS1 tarihini çözer. Gün "00" ise ayın son günüdür.
DateTime? tarihCoz(String yyaagg) {
  if (yyaagg.length != 6 || !_rakamMi(yyaagg)) return null;
  final yil = 2000 + int.parse(yyaagg.substring(0, 2));
  final ay = int.parse(yyaagg.substring(2, 4));
  final gun = int.parse(yyaagg.substring(4, 6));
  if (ay < 1 || ay > 12 || gun > 31) return null;
  // DateTime(yil, ay + 1, 0) → o ayın son günü.
  final sonGun = DateTime(yil, ay + 1, 0).day;
  if (gun > sonGun) return null;
  return DateTime(yil, ay, gun == 0 ? sonGun : gun);
}

/// Tarihi "Mart 2027" biçiminde Türkçe yazar.
String ayYilYaz(DateTime tarih) => '${_aylar[tarih.month - 1]} ${tarih.year}';

/// Okunan kod için sesli söylenecek Türkçe metni hazırlar.
String sesliMetinHazirla(String ham, {DateTime? bugun}) {
  final ilac = karekoduCoz(ham);
  if (ilac != null) {
    final skt = ilac.sonKullanma;
    if (skt == null) {
      return 'İlaç karekodu okundu. Son kullanma tarihi bulunamadı.';
    }
    final simdi = bugun ?? DateTime.now();
    final bugunTarih = DateTime(simdi.year, simdi.month, simdi.day);
    final metin = 'Son kullanma tarihi ${ayYilYaz(skt)}.';
    if (skt.isBefore(bugunTarih)) {
      return 'Dikkat! Bu ilacın son kullanma tarihi geçmiş. $metin';
    }
    return metin;
  }

  final temiz = ham.replaceAll(gs, ' ').trim();
  if (temiz.isEmpty) return 'Kod okundu ama içi boş.';
  // Sadece rakamdan oluşan barkodları tek tek okut ki anlaşılır olsun.
  if (_rakamMi(temiz)) return 'Barkod okundu: ${temiz.split('').join(' ')}';
  return 'Kod okundu: $temiz';
}
