# İlaç Asistanı

Görme engelli kişiler için hazırlanmış bir Android uygulaması. Telefonun
kamerasını ilaç kutusuna tutunca karekodu ya da barkodu okur, telefonu titretir
ve okuduğunu **Türkçe sesli** söyler. İlaç karekodunda son kullanma tarihini
bulup örneğin **“Son kullanma tarihi Mart 2027”** der.

## Nasıl çalıştırılır?

1. Bilgisayara [Flutter](https://docs.flutter.dev/get-started/install) ve
   Android Studio (Android SDK) kurun.
2. Android telefonda **Geliştirici seçenekleri** → **USB hata ayıklama**
   özelliğini açın ve telefonu USB kablosuyla bilgisayara bağlayın.
3. Bu klasörde bir terminal açıp şunları çalıştırın:

   ```bash
   flutter pub get      # gerekli paketleri indirir
   flutter run          # uygulamayı telefona kurar ve açar
   ```

   Telefona kurulabilir bir APK dosyası almak için:

   ```bash
   flutter build apk --release
   # dosya: build/app/outputs/flutter-apk/app-release.apk
   ```

4. Uygulama ilk açılışta **kamera izni** ister; “İzin ver” deyin.
5. Telefonda Türkçe metin okuma (TTS) sesi yüklü olmalıdır:
   **Ayarlar → Erişilebilirlik → Metin okuma çıktısı** bölümünden Türkçe sesi
   indirebilirsiniz.

Kontroller için:

```bash
flutter analyze   # kodda hata/uyarı var mı bakar
flutter test      # karekod çözme testlerini çalıştırır
```

## Uygulama nasıl kullanılır?

- Uygulama açılınca “İlaç Asistanı hazır” der ve kamera hemen taramaya başlar.
  Bir düğmeye basmanız gerekmez.
- İlaç kutusunu telefonun arka kamerasına yavaşça yaklaştırın.
- Kod okununca telefon kısa bir süre **titrer** ve bilgiyi **sesli söyler**.
- Son kullanma tarihi geçmişse önce **“Dikkat! Bu ilacın son kullanma tarihi
  geçmiş”** uyarısı gelir.
- Ekranın altında iki büyük düğme var:
  - **Tekrar söyle**: son okunan bilgiyi yeniden söyler.
  - **Feneri aç / kapat**: karanlıkta okumayı kolaylaştırır.
- Ekran **TalkBack** ile kullanılabilir: kamera alanı, durum yazısı ve
  düğmeler TalkBack tarafından açıklamalı okunur.

## Kod ne yapıyor? (basitçe)

| Dosya | Ne işe yarar |
| --- | --- |
| `lib/main.dart` | Uygulamanın ekranı. Kamerayı açar, okunan kodu alır, telefonu titretir, sesli söyler ve düğmeleri gösterir. |
| `lib/karekod.dart` | İlaç karekodunu çözen kısım. Son kullanma tarihini bulur ve Türkçe cümleye çevirir. |
| `test/karekod_test.dart` | Karekod çözmenin doğru çalıştığını kontrol eden testler. |
| `android/app/src/main/AndroidManifest.xml` | Android ayarları: kamera ve titreşim izinleri, metin okuma (TTS) motoruna erişim. |

### Adım adım ne oluyor?

1. **Kamera sürekli tarar.** `mobile_scanner` paketi kamerayı açar ve
   görüntüde bir karekod/barkod arar.
2. **Kod bulununca** (`_kodOkundu` fonksiyonu):
   - Aynı kod son 5 saniye içinde zaten söylendiyse tekrar söylemez
     (aynı kutu kamerada dururken sürekli konuşmasın diye).
   - `vibration` paketi ile telefonu titretir.
   - `flutter_tts` paketi ile metni Türkçe (`tr-TR`) sesli okur.
3. **Karekodu çözme** (`lib/karekod.dart`): İlaç karekodu sayılarla
   etiketlenmiş parçalardan oluşur:
   - `01` → ürün numarası (14 hane)
   - `21` → seri numarası
   - `17` → **son kullanma tarihi**, `YYAAGG` biçiminde (ör. `270331` =
     31 Mart 2027). Gün `00` ise ayın son günü sayılır.
   - `10` → parti numarası

   Kod bu parçaları ayırır, `17` etiketindeki tarihi alır ve
   “Son kullanma tarihi Mart 2027.” cümlesini hazırlar.
4. **İlaç karekodu değilse:** sadece rakamlardan oluşan barkodları rakam
   rakam (“8 6 9 …”) okur, diğer kodların içindeki yazıyı okur.

### Android ayarları (AndroidManifest.xml)

- `CAMERA` izni: kodu okumak için kamera.
- `VIBRATE` izni: kod okununca titreşim.
- `TTS_SERVICE` sorgusu: Android 11 ve sonrasında uygulamanın telefondaki
  metin okuma motorunu bulabilmesi için gerekli.
