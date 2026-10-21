import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/karekod.dart';

void main() {
  final bugun = DateTime(2026, 10, 21);

  test('GS ayırıcılı ilaç karekodundan son kullanma tarihini okur', () {
    const ham =
        '0108699504090128'
        '21ABC123XYZ$gs'
        '17270331'
        '10L2401';
    final ilac = karekoduCoz(ham)!;
    expect(ilac.gtin, '08699504090128');
    expect(ilac.seriNo, 'ABC123XYZ');
    expect(ilac.sonKullanma, DateTime(2027, 3, 31));
    expect(ilac.partiNo, 'L2401');
    expect(
      sesliMetinHazirla(ham, bugun: bugun),
      'Son kullanma tarihi Mart 2027.',
    );
  });

  test('GS ayırıcısı olmasa da tarihi bulur', () {
    const ham =
        '01086995040901282112345678901717270300'
        '10ABC';
    expect(karekoduCoz(ham)!.sonKullanma, DateTime(2027, 3, 31));
  });

  test('Sembol kimliği ve parantezli biçim desteklenir', () {
    expect(
      karekoduCoz(']d20108699504090128172511001012')!.sonKullanma,
      DateTime(2025, 11, 30),
    );
    expect(
      karekoduCoz('(01)08699504090128(17)280115(10)A1')!.sonKullanma,
      DateTime(2028, 1, 15),
    );
  });

  test('Tarihi geçmiş ilaç için uyarı verir', () {
    const ham = '0108699504090128172501311012';
    expect(
      sesliMetinHazirla(ham, bugun: bugun),
      startsWith('Dikkat! Bu ilacın son kullanma tarihi geçmiş.'),
    );
  });

  test('Normal barkod rakamları tek tek okunur', () {
    expect(
      sesliMetinHazirla('8690000', bugun: bugun),
      'Barkod okundu: 8 6 9 0 0 0 0',
    );
    expect(sesliMetinHazirla('merhaba', bugun: bugun), 'Kod okundu: merhaba');
  });
}
