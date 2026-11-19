# İlaç Asistanı

Görme engelli kişiler için hazırlanmış, tamamen Türkçe bir Android uygulaması.

- Kamerayı ilaç kutusuna tutunca karekodu ya da barkodu okur, telefonu titretir
  ve **ilacın adını ve son kullanma tarihini sesli söyler**
  (“Coraspin 100 miligram. Son kullanma tarihi Mart 2027.”).
- Hatırlatma saatinde kutu okutulursa **doğru ilaç mı** diye kontrol eder.
- Karekod okunamazsa **kutunun yazısından** ilacı tahmin eder (“muhtemelen…”).
- Ardından **“Bu ilaç için hatırlatma kurmak ister misiniz?”** diye sorar ve
  cevabı **sesle** alır. Hiçbir düğme aramanız gerekmez.
- Her gün aynı saatte **bildirimle hatırlatır**; “Aldım” denmezse 10 ve 20
  dakika sonra tekrar hatırlatır.
- Uygulama konuşurken siz konuşmaya başlarsanız **susar ve sizi dinler**.
- **TalkBack açıksa** kendi sesiyle değil **TalkBack üzerinden** konuşur;
  iki ses üst üste binmez.
- Kod kamerada görünüp okunamadığında **park sensörü gibi bip** sesleriyle
  yönlendirir; 15 saniye kod bulunamazsa ipucu verir.
- Telefonda **Türkçe ses yoksa** bunu büyük yazıyla gösterir ve nasıl
  yükleneceğini anlatır.

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

4. Telefonda şunlar olmalı:
   - **Türkçe metin okuma sesi:** Ayarlar > Metin okuma > Google > Ses
     verilerini yükle > Türkçe. (Yoksa uygulama açılışta bunu büyük yazıyla
     gösterir; “Ses ayarlarını aç” düğmesi sizi oraya götürür.)
   - **Türkçe konuşma tanıma:** Google uygulaması yüklü ve güncel olmalı.
     İnternetsiz kullanmak için Google ayarlarından Türkçe çevrimdışı konuşma
     tanıma paketini indirebilirsiniz.

Kontroller için:

```bash
flutter analyze   # kodda hata/uyarı var mı bakar
flutter test      # saat ayrıştırma, komut, ajanda ve karekod testleri
```

## Uygulama nasıl kullanılır?

### İlk açılış: izinler sesle anlatılır

1. Uygulama kendini tanıtır ve **mikrofon iznini** neden istediğini söyler.
   Ekrandaki izin penceresinde “Uygulamayı kullanırken izin ver”e dokunun.
   (Android'in izin penceresi sesle cevaplanamaz; bu yüzden ne yapılacağı
   önceden sesle anlatılır. TalkBack bu pencereyi de okur.)
2. Mikrofon açıldıktan sonra **“Kameraya izin vermek istiyor musunuz?”** diye
   sorar. **“Evet”** derseniz kamera izin penceresi açılır; **“Hayır”** derseniz
   kamera kapalı kalır ve daha sonra “kamera izni” diyerek açabilirsiniz.
3. İzin verilmezse, ayarlardan nasıl açılacağı sesle anlatılır.

### İlaç okutma ve hatırlatma kurma

1. İlaç kutusunu telefonun arka kamerasına yavaşça yaklaştırın.
2. Kod okununca telefon **titrer** ve ilacın **adını** ve **son kullanma
   tarihini** söyler. Tarih geçmişse önce “Dikkat!” uyarısı gelir.
3. Uygulama **“Bu ilaç için hatırlatma kurmak ister misiniz?”** diye sorar ve
   mikrofonu kendiliğinden açar.
4. “Evet” deyin. Saati sorar: **“her gün sabah dokuzda”**, “akşam sekizde”,
   “saat dokuz buçukta”, “21:00” gibi söyleyebilirsiniz. Doğrudan
   “evet, akşam sekizde” de diyebilirsiniz.
5. Uygulama saati açıkça tekrar eder: **“Her gün sabah 09:00'da hatırlatma
   kurulacak. Onaylıyor musunuz?”** “Evet” derseniz kurar, “hayır” derseniz
   iptal eder. “Hayır, akşam dokuzda” derseniz yeni saati onaylatır.
6. Sabah/akşam söylemezseniz **sabah** kabul edilir ama onayda açıkça söylenir.
7. Saat anlaşılmazsa “Anlayamadım, saati tekrar söyler misiniz?” der; iki
   denemeden sonra vazgeçer.
8. İlk hatırlatmada **bildirim izni** (Android 13+) ve **alarmlar ve
   hatırlatıcılar izni** (Android 12+) neden gerektiği sesle anlatılarak
   istenir.

### Bildirim geldiğinde

- Bildirimde **“Aldım”** ve **“Ertele (10 dakika)”** düğmeleri vardır.
- “Aldım”a basılmazsa **10 ve 20 dakika sonra** tekrar hatırlatılır.
  “Aldım” denince o günün bekleyen tekrarları iptal edilir.
- “Ertele” 10 dakika sonra yeniden hatırlatır.
- Bildirime dokunursanız uygulama açılır ve **“Saat 09:00. İlacınızı alma
  zamanı.”** der, sonra “aldım” ya da “ertele” demenizi bekler.
- Telefon yeniden başlatılsa da hatırlatmalar yeniden kurulur.

### Sesli komutlar

**Ekranın herhangi bir yerine iki kez dokunun** (ya da “Sesli komut ver”
düğmesine basın) ve şunlardan birini söyleyin. TalkBack açıksa aşağıdaki
“TalkBack ile kullanım” bölümüne bakın.

| Söyleyin | Ne olur |
| --- | --- |
| “tekrar söyle” | Son söylenen bilgiyi yeniden söyler |
| “feneri aç” / “feneri kapat” | Telefonun ışığını açar / kapatır |
| “ajandamı oku” | Kurulu hatırlatmaları saat sırasıyla okur |
| “dokuzdaki hatırlatmayı sil” | Onay alarak o saatteki hatırlatmayı siler |
| “aldım” | İlacı aldığınızı kaydeder, bekleyen tekrarları iptal eder |
| “ertele” | Şu anki hatırlatmayı 10 dakika erteler |
| “her gün saat dokuzda hatırlat” | Son okutulan ilaç için hatırlatma kurar |
| “kamera izni” | Kamera iznini yeniden ister |
| “yardım” | Komutları sayar |
| “sus” | Uygulamayı susturur |
| “bip sesini kapat” / “bip sesini aç” | Bip ile yönlendirmeyi kapatır / açar (ayar kalıcıdır) |

**Sözünü kesme:** Uygulama uzun bir cümle söylerken konuşmaya başlarsanız
(örneğin “feneri aç”), uygulama susar ve söylediğinizi yapar.

### İlacın adı ve doğru ilaç kontrolü

- Karekoddaki ürün numarası (GTIN) uygulamanın içindeki ilaç listesiyle
  eşleştirilir ve ilacın **kısa adı** söylenir: “Coraspin 100 miligram. Son
  kullanma tarihi Mart 2027.” (Paket bilgisi, ör. “30 enterik kaplı tablet”,
  söylenmez.)
- Listede yoksa: “İlaç karekodu okundu ama ilacın adı listede yok.” ve son
  kullanma tarihi söylenir.
- Hatırlatmalar, bildirimler ve ajanda ilaç adıyla konuşur:
  “Saat 09:00. Coraspin 100 miligram alma zamanı.”
- **Hatırlatma saatinde** (saatin 1 saat öncesinden 2 saat sonrasına kadar ya
  da bildirime dokunduktan sonraki 2 saat içinde) bir kutu okutulursa:
  - doğru kutuysa **“Evet, doğru ilaç.”**
  - başka bir kutuysa **“Dikkat, bu hatırlatılan ilaç değil. Şu an
    hatırlatılan: Coraspin 100 miligram.”**

### Karekod okunamazsa: kutunun yazısından tahmin

- Kamera açıkken **10 saniye** boyunca hiçbir kod okunamazsa uygulama
  tarayıcıyı bir an durdurur, kutunun fotoğrafını çeker ve üzerindeki yazıyı
  **telefonun içinde, internetsiz** okur (`google_mlkit_text_recognition`).
- Okunan yazıyı ilaç listesindeki marka adlarıyla karşılaştırır; yazı tanıma
  hatalarına (ör. “0” yerine “O”, bir harf eksik) biraz tolerans gösterir.
  Kutuda doz yazıyorsa (“100 mg”) o dozdaki ürünü seçer.
- Bir eşleşme bulursa **mutlaka “muhtemelen” diyerek** söyler: “Karekod
  bulunamadı, kutunun yazısından okuyorum: muhtemelen Coraspin 100 miligram.
  Bu tahmin kesin değil, mümkünse karekodu okutun.”
- Emin olamazsa (hiç ya da iki farklı eşit aday) **hiçbir şey söylemez**.
- Bu tahmin ile hatırlatma kurulmaz ve doğru ilaç kontrolü yapılmaz; bunlar
  için karekod gerekir. Uygulama **hiçbir zaman doz önerisi ya da tıbbi
  tavsiye vermez**, yalnızca ürünün adını söyler.
- En fazla iki kez denenir (10. ve 30. saniyede); bir kod okununca sayaç
  baştan başlar.

### Bip sesiyle yönlendirme

- Kamera bir kod görüp henüz okuyamadığında kısa **bip** sesleri çalar.
  Kod **ekranın ortasına** ve **kameraya yaklaştıkça** bipler hızlanır
  (park sensörü gibi). Kod okununca bip durur.
- Uygulama konuşurken ya da sizi dinlerken bip çalmaz.
- **15 saniye** boyunca hiç kod bulunamazsa: “Kutuyu yavaşça çevirin,
  karekod genelde kutunun yan yüzündedir.” der. Kod hâlâ bulunamazsa 30
  saniye sonra bir kez daha söyler, sonra bir kod görene kadar susar.
- “bip sesini kapat” / “bip sesini aç” diyerek ya da ekrandaki **“Bip sesiyle
  yönlendirme”** anahtarıyla açıp kapatabilirsiniz.

### TalkBack ile kullanım

- **TalkBack açıksa** uygulama kendi sesini (flutter_tts) kullanmaz; her şeyi
  TalkBack'e duyurur. Böylece iki ses aynı anda konuşmaz. TalkBack açılıp
  kapanınca uygulama bunu fark eder ve sesli haber verir.
- TalkBack açıkken **“ekranın her yerine iki kez dokunma”** çalışmaz, çünkü
  TalkBack iki kez dokunmayı “seçili öğeye bas” olarak kullanır. Bunun yerine:
  - Ekranın üst yarısındaki **kamera alanına** dokunun, sonra iki kez dokunun,
  - ya da **“Sesli komut ver”** düğmesine dokunun, sonra iki kez dokunun.

  Uygulama bunu açılışta sesli olarak anlatır.
- TalkBack açıkken dinleme, TalkBack'in kendi sesi mikrofona karışmasın diye
  kısa bir beklemeden sonra başlar. Uygulamanın sözünü kesme özelliği
  TalkBack açıkken kapalıdır; TalkBack'i susturmak için ekrana dokunun.

### Ekran

- Siyah zemin, beyaz yazı, büyük sarı düğmeler.
- Altta **“Hatırlatmalarım”** listesi büyük yazıyla durur; her satırda
  “Sil” düğmesi vardır. TalkBack satırı “Her gün sabah saat 09:00, majezik…”
  diye okur.

## Kod ne yapıyor? (basitçe)

| Dosya | Ne işe yarar |
| --- | --- |
| `lib/main.dart` | Ekran ve konuşma akışları: izinler, karekod okuma, hatırlatma kurma, silme, aldım/ertele, sesli komutlar. |
| `lib/ses.dart` | Dinleme (`speech_to_text`, `tr_TR`), Türkçe ses kontrolü ve araya girince susma. Konuşmayı `Duyurucu` üzerinden yapar. |
| `lib/duyurucu.dart` | **Tek karar noktası:** TalkBack açıksa duyuruyu TalkBack'e (`SemanticsService`), kapalıysa `flutter_tts`'e verir. |
| `lib/bip.dart` | Bip aralığını kodun konumuna ve büyüklüğüne göre hesaplar; 15 saniye ipucu zamanlaması. |
| `lib/ayarlar.dart` | Bip açık/kapalı ayarını saklar. |
| `lib/cihaz.dart` + `MainActivity.kt` | Android'e özel: bip sesini çalar (`ToneGenerator`), ses ayarlarını açar. |
| `lib/saat_ayristir.dart` | Söylenen cümleden saati bulan saf Dart fonksiyonu (`saatiAyikla`). |
| `lib/komutlar.dart` | Cümleden komutu (“feneri aç”, “aldım”…) ve evet/hayır cevabını anlayan kod. |
| `lib/ajanda.dart` | Hatırlatma listesi: ekleme, silme, saate göre bulma, sesli okuma metni; `shared_preferences` ile kalıcı saklama. |
| `lib/hatirlatma_servisi.dart` | Günlük bildirimleri kurar (`flutter_local_notifications`, `timezone`, Europe/Istanbul), “Aldım/Ertele” düğmelerini işler. |
| `lib/zamanlama.dart` | Bildirimin ne zaman çalacağını hesaplayan saf Dart fonksiyonları. |
| `lib/ilac_veritabani.dart` | Barkoddan ilaç adını bulur; kısa ve sesli okunacak ad (“CORASPIN 100 MG 30 ENTERIK…” → “Coraspin 100 miligram”); marka indeksi. |
| `lib/yazi_eslestirme.dart` | Kutu yazısını (OCR metni) ilaç listesindeki markalarla eşleştiren saf Dart kodu. |
| `lib/yazi_okuyucu.dart` | Fotoğraf çekip yazıyı cihaz üzerinde okur (`camera`, `google_mlkit_text_recognition`). |
| `lib/karekod.dart` | İlaç karekodunu çözer, son kullanma tarihini Türkçe cümleye çevirir. |
| `lib/turkce.dart` | Türkçe küçük harf, kelimelere bölme, “09:00'da / 20:00'de” ekleri. |
| `assets/ilaclar.tsv` | ~18 bin ilacın barkodu ve adı (TİTCK listesinden). |
| `tool/ilac_listesi_guncelle.py` | İlaç listesini güncellemek için betik. |
| `test/` | Birim testleri. |

### Saat nasıl anlaşılıyor?

`saatiAyikla` cümleyi kelimelere böler, “dokuzda”, “on birde”, “9'da”,
“21:00” gibi sayıları bulur; “buçuk” (30 dakika), “çeyrek geçe/var” gibi
dakikaları ekler. “akşam”, “gece”, “öğlen” sözlerine göre saati 12 saat ileri
alır (“akşam sekizde” → 20:00, “gece on birde” → 23:00).

### Hatırlatma nasıl çalışıyor?

Her hatırlatma için Android'e üç günlük bildirim verilir: tam saatinde, 10
dakika sonra ve 20 dakika sonra. “Aldım” denince 10 ve 20 dakikalık
bildirimler o gün için iptal edilip ertesi günden başlayacak şekilde yeniden
kurulur. Hatırlatmada ilacı ayırt etmek için karekoddaki ürün numarası (GTIN)
saklanır.

### İlaç listesi: nereden geliyor, nasıl güncellenir?

**Uygulamadaki liste gerçektir.** `assets/ilaclar.tsv`, Türkiye İlaç ve Tıbbi
Cihaz Kurumu'nun (TİTCK) yayımladığı “SKRS e-Reçete İlaç ve Diğer Farmasötik
Ürünler Listesi”nin aktif ve pasif ürünlerinden üretildi (18.241 ürün).
Uydurma örnek kayıtlar **yalnızca testlerde** (`test/ilac_tanima_test.dart`)
vardır ve orada açıkça “gerçek değildir” diye işaretlenmiştir; uygulamanın
kullandığı listede uydurma kayıt yoktur.

Dosya biçimi: her satırda bir ilaç, **barkod ⇥ ilaç adı** (sekmeyle ayrılmış
CSV, yani TSV). Sekme kullanıldı çünkü ilaç adlarında virgül geçiyor.

```
8699546130238	CORASPIN 100 MG 30 ENTERIK KAPLI TABLET
```

Listeyi TİTCK'nin en yeni yayınıyla güncellemek için, adım adım:

1. Tarayıcıda <https://www.titck.gov.tr/dinamikmodul/43> sayfasını açın.
2. En üstteki (en yeni tarihli) **“SKRS E-Reçete İlaç ve Diğer Farmasötik
   Ürünler Listesi”** Excel (.xlsx) dosyasını indirin.
3. Bilgisayarda Python 3 kurulu olmalı. Excel okuyucuyu kurun:
   `pip install openpyxl`
4. Bu klasörde çalıştırın:
   `python3 tool/ilac_listesi_guncelle.py ~/Downloads/indirilen_dosya.xlsx`
   Betik “AKTİF ÜRÜNLER LİSTESİ” ve “PASİF ÜRÜNLER LİSTESİ” sayfalarındaki
   *İlaç Adı* ve *Barkod* sütunlarını alır ve `assets/ilaclar.tsv` dosyasını
   yeniden yazar (ekrana kaç ilaç yazıldığını söyler).
5. `flutter test` ile kontrol edin, sonra uygulamayı yeniden derleyin
   (`flutter run` ya da `flutter build apk`).

Listeye elle ilaç eklemek isterseniz `assets/ilaclar.tsv` dosyasının sonuna
aynı biçimde (barkod, sekme, ad) bir satır ekleyebilirsiniz; ancak bir sonraki
güncellemede betik dosyayı baştan yazar.

### Android ayarları (AndroidManifest.xml)

- `CAMERA`: kodu okumak için kamera.
- `VIBRATE`: kod okununca titreşim.
- `RECORD_AUDIO`: sesli komutlar için mikrofon.
- `POST_NOTIFICATIONS`: hatırlatma bildirimleri (Android 13+).
- `SCHEDULE_EXACT_ALARM`: hatırlatmanın tam saatinde gelmesi (Android 12+).
- `RECEIVE_BOOT_COMPLETED`: telefon yeniden başlayınca hatırlatmaları
  yeniden kurmak.
- `TTS_SERVICE` ve `RecognitionService` sorguları: Android 11+ telefonlarda
  metin okuma ve konuşma tanıma hizmetlerini bulabilmek.
- `flutter_local_notifications` alıcıları: zamanlanmış bildirimler, yeniden
  başlatma ve bildirim düğmeleri için.
