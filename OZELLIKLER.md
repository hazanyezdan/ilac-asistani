# İlaç Asistanı: tüm özellikler

Bu belge, uygulamanın **şu an yapabildiği her şeyi** anlatır. Uygulama görme
engelli kullanıcılar için yazılmış, yalnızca Android'de çalışan ve tamamen
Türkçe konuşan bir Flutter uygulamasıdır. Nasıl kurulup çalıştırılacağı
`README.md` dosyasındadır.

> Not: Uygulama şimdiye kadar otomatik testlerle (118 test) ve derlemeyle
> kontrol edildi; gerçek bir telefonda henüz denenmedi. Telefonda denenmesi
> gereken noktalar en sonda “Bilinen sınırlar” bölümünde.

---

## 1. Açılış ve izinler

| Ne olur | Ayrıntı |
| --- | --- |
| Kendini tanıtır | “Merhaba, ben İlaç Asistanı.” |
| Mikrofon iznini sesle anlatır | Neden gerektiğini ve açılacak pencerede hangi düğmeye dokunulacağını söyler, sonra Android izin penceresini açar. |
| Kamera iznini **sesle sorar** | “Kameraya izin vermek istiyor musunuz? Evet ya da hayır deyin.” “Evet” derseniz izin penceresini açar; “hayır” derseniz kamera kapalı kalır ve sonra “kamera izni” diyerek açabileceğinizi söyler. |
| İzin verilmezse yol gösterir | Telefonun Ayarlar > Uygulamalar > İlaç Asistanı > İzinler bölümünden nasıl açılacağını söyler. Kamera izni kalıcı olarak reddedilmişse ayarları kendisi açar. |
| Türkçe ses yoksa uyarır | Telefonda Türkçe metin okuma sesi yüklü değilse ekranın en üstünde büyük sarı çerçeveli bir uyarı çıkar ve yükleme yolu anlatılır: Ayarlar > Metin okuma > Google > Ses verilerini yükle > Türkçe. “Ses ayarlarını aç” düğmesi o ekranı açar. Ayarlardan geri dönünce yeniden kontrol eder. |
| Hazır olduğunu söyler | “İlaç Asistanı hazır. İlacın karekodunu kameraya tutun.” ve sesli komutun nasıl verileceği. |

Android'in kendi izin pencereleri sesle cevaplanamaz; bu yüzden uygulama ne
yapılacağını önceden sesle anlatır. TalkBack bu pencereleri de okur.

---

## 2. Karekod ve barkod okuma

- Kamera **sürekli tarar**; düğmeye basmak gerekmez.
- Kod okununca telefon **titrer** (0,3 saniye) ve bilgi **sesle söylenir**,
  ekranda da büyük yazıyla görünür.
- Aynı kod **5 saniye** içinde tekrar okunursa yeniden söylenmez (kutu
  kamerada dururken durmadan konuşmasın diye).
- Uygulama konuşurken ya da bir soru sorarken yeni kodlar beklemeye alınır.

### İlaç karekodu (GS1 DataMatrix)
Karekoddaki alanlar ayrıştırılır: `01` ürün numarası (GTIN), `21` seri
numarası, `17` son kullanma tarihi, `10` parti numarası.

| Durum | Söylenen |
| --- | --- |
| İlaç listede var | “**Coraspin 100 miligram.** Son kullanma tarihi Mart 2027.” |
| İlaç listede yok | “İlaç karekodu okundu ama ilacın adı listede yok. Son kullanma tarihi Mart 2027.” |
| Tarihi geçmiş | “… Dikkat! Bu ilacın son kullanma tarihi geçmiş. Son kullanma tarihi Ocak 2025.” |
| Karekodda tarih yok | “İlaç karekodu okundu. Son kullanma tarihi bulunamadı.” |

Karekod okumada şunlar da ele alınır:
- Tarihte gün “00” ise ayın son günü sayılır (GS1 kuralı).
- Alanlar arasındaki ayırıcı karakter eksikse de tarih bulunur.
- Başta `]d2` gibi okuyucu kodları varsa atlanır.
- Parantezli yazım (`(01)…(17)270331`) da okunur.
- Geçersiz tarihler (13. ay gibi) kabul edilmez.

### Diğer kodlar
- İlaç kutusundaki **normal barkod** listede varsa: “Majezik 100 miligram.
  Barkod okundu.”
- Listede olmayan, yalnızca rakamlı barkodlar rakam rakam okunur:
  “Barkod okundu: 8 6 9 9 …”
- İçinde yazı olan kodlar (QR gibi) içerikleriyle okunur: “Kod okundu: …”

---

## 3. İlacın adı

- Uygulamanın içinde Türkiye İlaç ve Tıbbi Cihaz Kurumu'nun (TİTCK) resmî
  **“SKRS e-Reçete İlaç ve Diğer Farmasötik Ürünler Listesi”**nden alınmış
  **18.241 ilaç** vardır (`assets/ilaclar.tsv`). İnternet gerekmez.
- Karekoddaki 14 haneli ürün numarası ile kutudaki 13 haneli barkod aynı ilaç
  olarak eşleşir.
- Ad **kısa ve anlaşılır** söylenir: “CORASPIN 100 MG 30 ENTERIK KAPLI TABLET”
  → “Coraspin 100 miligram”. Paket bilgisi atılır; “MG” → “miligram”,
  “ML” → “mililitre”, “%” → “yüzde”, “/” → “ve” olur.
- Liste, TİTCK'nin yeni yayınıyla `tool/ilac_listesi_guncelle.py` betiği
  kullanılarak güncellenebilir (adımlar README'de).

---

## 4. Karekod okunamazsa: kutunun yazısından tahmin

- Kamera açıkken **10 saniye** hiçbir kod okunamazsa uygulama tarayıcıyı bir
  an durdurur, kutunun **fotoğrafını çeker** ve üzerindeki yazıyı **telefonun
  içinde, internetsiz** okur (Google ML Kit yazı tanıma).
- Okunan yazı ilaç listesindeki marka adlarıyla karşılaştırılır:
  - Birden fazla kelimeli markalar (“Majezik Duo”) önce denenir.
  - Yazı tanımanın “O” yerine “0”, “I” yerine “1” okuması düzeltilir.
  - Uzun adlarda 1–2 harf hatasına izin verilir.
  - Kutuda doz yazıyorsa (“100 mg”) o dozdaki ürün seçilir.
  - “Sodyum klorür”, “laktoz” gibi genel kelimeler marka sayılmaz.
- Bulunursa **mutlaka “muhtemelen” denir**: “Karekod bulunamadı, kutunun
  yazısından okuyorum: muhtemelen Coraspin 100 miligram. Bu tahmin kesin değil,
  mümkünse karekodu okutun.”
- Emin olunamazsa (hiç aday yoksa ya da iki eşit aday varsa) **hiçbir şey
  söylenmez**.
- En fazla iki kez denenir (10. ve 30. saniye); bir kod okununca sayaç baştan
  başlar.
- Bu tahminle hatırlatma kurulmaz. Uygulama **hiçbir zaman doz önerisi ya da
  tıbbi tavsiye vermez**, yalnızca ürünün adını söyler.

---

## 5. Kod bulmaya yardım: bip ve ipucu

- **Bip ile yönlendirme (park sensörü gibi):** Kamera bir kod görüp henüz
  okuyamadığında kısa bip sesleri çalar. Kod ekranın **ortasına** ve
  **kameraya yaklaştıkça** bipler hızlanır (1 saniyeden 0,12 saniyeye). Kod
  okununca bip durur. Uygulama konuşurken ya da dinlerken bip çalmaz.
- **İpucu:** 15 saniye boyunca hiç kod bulunamazsa: “Kutuyu yavaşça çevirin,
  karekod genelde kutunun yan yüzündedir.” Kod hâlâ bulunamazsa 30 saniye
  sonra bir kez daha söyler, sonra bir kod görene kadar susar.
- Bip; “bip sesini kapat” / “bip sesini aç” diyerek ya da ekrandaki
  **“Bip sesiyle yönlendirme”** anahtarıyla açılıp kapatılır. Ayar telefonda
  saklanır.

---

## 6. Sesli komutlar

Dinlemeyi başlatmanın yolları:
- Ekranın **herhangi bir yerine iki kez dokunmak** (TalkBack kapalıyken),
- **“Sesli komut ver”** düğmesi,
- TalkBack açıkken kamera alanına ya da bu düğmeye odaklanıp iki kez dokunmak.

Dinleme başlarken telefon kısa titrer, ekranda “🎤 Dinliyorum…” yazar. En
fazla 8 saniye dinlenir; 3 saniye sessizlik olunca dinleme biter.

| Söyleyin | Ne olur |
| --- | --- |
| “tekrar söyle”, “bir daha söyle” | Son söylenen bilgiyi tekrarlar |
| “feneri aç” / “feneri kapat”, “ışığı yak” | Telefonun ışığını açar / kapatır |
| “ajandamı oku”, “hatırlatmalarımı söyle” | Hatırlatmaları saat sırasıyla okur |
| “dokuzdaki hatırlatmayı sil” | Onay alarak siler |
| “her gün saat dokuzda hatırlat” | Son okutulan ilaç için hatırlatma kurar |
| “aldım”, “ilacımı içtim” | Alındığını kaydeder, bekleyen tekrarları iptal eder |
| “ertele” | Şu anki hatırlatmayı 10 dakika erteler |
| “bip sesini kapat” / “bip sesini aç” | Bip yönlendirmesini kapatır / açar |
| “kamera izni” | Kamera iznini yeniden ister |
| “yardım” | Komutları sayar |
| “sus”, “dur”, “yeter” | Uygulamayı susturur |

Anlaşılmayan bir cümlede: “Anlayamadım. Neler yapabileceğimi duymak için
yardım deyin.”

### Evet / hayır cevapları
- **Evet:** evet, tamam, olur, onaylıyorum, isterim, istiyorum, peki, tabii…
- **Hayır:** hayır, istemiyorum, iptal, vazgeç, yok, onaylamıyorum, kalsın…
- “İstemiyorum” gibi cevaplar yanlışlıkla evet sayılmasın diye önce “hayır”a
  bakılır. Anlaşılmazsa bir kez daha sorulur.

### Sözünü kesme
Uygulama uzun bir cümle (6 kelime ve üstü) söylerken siz konuşmaya
başlarsanız uygulama **hemen susar** ve söylediğinizi işler. Mikrofon
uygulamanın kendi sesini de duyduğu için, o an söylenen cümledeki kelimeler
ayıklanır; geriye kalan sizin sözünüz sayılır. (TalkBack açıkken bu özellik
kapalıdır.)

---

## 7. Hatırlatma kurma

1. Geçerli bir ilaç karekodu okununca uygulama sorar: **“Bu ilaç için
   hatırlatma kurmak ister misiniz?”** ve mikrofonu kendiliğinden açar.
   (Tarihi geçmiş ilaçta ve şu an zaten hatırlatması bekleyen ilaçta sormaz.)
2. “Evet” derseniz saati sorar: “Her gün saat kaçta hatırlatayım?”
   “Evet, akşam sekizde” gibi tek seferde de söyleyebilirsiniz.
3. Saati onaylatır: **“Coraspin 100 miligram için her gün sabah 09:00'da
   hatırlatma kurulacak. Onaylıyor musunuz?”** “Hayır, akşam dokuzda”
   derseniz yeni saati onaylatır.
4. Saat iki denemede anlaşılmazsa vazgeçer: “Saati anlayamadım, hatırlatma
   kurmadım.”

### Anlaşılan saat söyleyişleri
| Söylenen | Saat |
| --- | --- |
| “her gün saat dokuzda hatırlat” | 09:00 |
| “her gün sabah 9'da” | 09:00 |
| “akşam sekizde” | 20:00 |
| “saat dokuz buçukta” | 09:30 |
| “öğlen on ikide” | 12:00 |
| “gece on birde” | 23:00 |
| “dokuzu çeyrek geçe” / “dokuza çeyrek var” | 09:15 / 08:45 |
| “saat yedi otuzda”, “21:00”, “8.30'da” | 07:30, 21:00, 08:30 |
| “öğleden sonra üçte”, “gece ikide” | 15:00, 02:00 |

Sabah/akşam söylenmezse **sabah** kabul edilir ama onayda açıkça söylenir.
Aynı ilaç için aynı saatte ikinci hatırlatma kurulmaz.

### İzinler (ilk hatırlatmada)
- **Bildirim izni** (Android 13 ve üstü): neden gerektiği anlatılır, pencere
  açılır.
- **Alarmlar ve hatırlatıcılar izni** (Android 12 ve üstü): ayar ekranı açılır,
  hangi anahtarın açılacağı söylenir. Verilmezse hatırlatma yine kurulur ama
  “birkaç dakika gecikebilir” denir. Uygulamaya geri dönünce hatırlatmalar tam
  saate göre yeniden kurulur.

---

## 8. Bildirimler

- Her hatırlatma için **her gün aynı saatte** bildirim gelir (Türkiye saati,
  Europe/Istanbul).
- Bildirim ilaç adıyla konuşur: **“Saat 09:00. Coraspin 100 miligram alma
  zamanı.”**
- Bildirimde iki düğme vardır: **“Aldım”** ve **“Ertele (10 dakika)”**.
  Uygulama kapalıyken de çalışırlar.
- **“Aldım” denmezse** 10 ve 20 dakika sonra tekrar hatırlatılır.
- **“Aldım”** denince o günün bekleyen tekrarları iptal edilir. Saatten en
  fazla 1 saat önce “aldım” denirse o günün bildirimi de gelmez.
- **“Ertele”** 10 dakika sonra yeniden hatırlatır; o günün diğer tekrarları
  üst üste binmesin diye iptal edilir.
- Bildirime dokununca uygulama açılır, hatırlatmayı söyler ve “Aldıysanız
  aldım, sonra hatırlatmamı isterseniz ertele deyin.” diyerek sizi dinler.
- **Telefon yeniden başlatılsa** da hatırlatmalar yeniden kurulur.

---

## 9. Doğru ilaç kontrolü

Hatırlatma saatinde (saatin 1 saat öncesinden 2 saat sonrasına kadar ya da
bildirime dokunduktan sonraki 2 saat içinde) bir kutu okutulursa:
- doğru kutuysa: **“Evet, doğru ilaç.”**
- başka bir kutuysa: **“Dikkat, bu hatırlatılan ilaç değil. Şu an
  hatırlatılan: Coraspin 100 miligram.”**

Karşılaştırma karekoddaki ürün numarasıyla (GTIN) yapılır.

---

## 10. Ajanda

- Hatırlatmalar telefonda kalıcı saklanır; uygulama kapanıp açılınca kaybolmaz.
- **“ajandamı oku”**: “2 hatırlatmanız var. sabah 09:00'da Coraspin 100
  miligram. akşam 20:00'de Majezik 100 miligram.”
- **Silme:** “dokuzdaki hatırlatmayı sil” → onay sorulur → silinir.
  - “Dokuzdaki” hem 09:00'ı hem 21:00'ı kapsar; ikisi de varsa “sabah ya da
    akşam diyerek tekrar söyler misiniz?” diye sorar.
  - Saat söylenmezse ve tek hatırlatma varsa onu siler; birden fazlaysa hangisi
    olduğunu sorar.
- **“aldım”** kayıtları da saklanır (en son 500 kayıt).
- Ekranın altındaki **“Hatırlatmalarım”** listesi büyük yazıyla durur; her
  satırda büyük bir **“Sil”** düğmesi vardır. TalkBack satırı “Her gün sabah
  saat 09:00, Coraspin 100 miligram” diye okur.

---

## 11. TalkBack ve erişilebilirlik

- **Ses çakışması yok:** TalkBack açıksa uygulama kendi sesini kullanmaz, her
  şeyi TalkBack üzerinden söyler. TalkBack kapalıysa kendi Türkçe sesiyle
  konuşur. Bu karar tek bir yerde (`lib/duyurucu.dart`) verilir.
- TalkBack açılıp kapanınca uygulama bunu fark eder ve sesle haber verir.
- TalkBack açıkken “ekranın her yerine iki kez dokunma” çalışmaz (TalkBack bu
  hareketi kendisi kullanır). Bunun yerine kamera alanı ya da “Sesli komut
  ver” düğmesi kullanılır; uygulama bunu açılışta sesle anlatır.
- TalkBack açıkken mikrofon, TalkBack'in sesi karışmasın diye kısa bir
  beklemeden sonra açılır.
- Ekran: siyah zemin, beyaz yazı, büyük (26 punto) metin, büyük sarı düğmeler
  (72 piksel yükseklik). Her düğmenin TalkBack için ne yaptığını anlatan bir
  açıklaması vardır.
- Kamera alanı TalkBack'te tek bir açıklama olarak okunur: “Kamera açık.
  İlacın karekodunu ya da barkodunu telefonun arkasına doğru tutun.”
- Mikrofon yoksa onaylar (ör. silme) ekranda büyük “Evet / Hayır” penceresiyle
  alınır.

---

## 12. Ekrandaki düğmeler

| Düğme | Ne yapar |
| --- | --- |
| Sesli komut ver | Dinlemeye başlar |
| Tekrar söyle | Son bilgiyi tekrar söyler |
| Feneri aç / Feneri kapat | Telefonun ışığını açar / kapatır |
| Bip sesiyle yönlendirme (anahtar) | Bip yönlendirmesini açar / kapatır |
| Ses ayarlarını aç | (Türkçe ses yoksa görünür) Metin okuma ayarlarını açar |
| Sil (her hatırlatmada) | Onay alarak o hatırlatmayı siler |

---

## 13. Gizlilik ve internet

- İlaç listesi, yazı tanıma, hatırlatmalar ve ajanda **telefonun içinde**
  çalışır; bu bilgiler hiçbir yere gönderilmez.
- Konuşma tanıma telefonun konuşma tanıma hizmetini (genelde Google) kullanır;
  telefonda çevrimdışı Türkçe paketi yoksa internet gerekebilir.

---

## Bilinen sınırlar (gerçek telefonda denenmeli)

- **Bip seyrek çalabilir:** Google'ın kod okuyucusu çoğu zaman yalnızca tam
  okuyabildiği kodları bildirir; “görüp okuyamadığı” kod durumu az oluşabilir.
- **TalkBack'in okuma süresi tahmin ediliyor:** TalkBack çok yavaş ayarlıysa
  mikrofon erken açılıp TalkBack'i duyabilir.
- **Sözünü kesme:** Mikrofon uygulamanın kendi sesini yanlış anlayabilir;
  konuşma tanıma her uzun cümlede “bip” sesi çıkarabilir.
- **Kutu yazısından okuma:** Kamera bir an kapanıp açılır; karanlık ya da
  bulanık kutuda okunamayabilir; tahmin her zaman kesin değildir.
- **Bildirim düğmeleri uygulama kapalıyken:** “Aldım” ve “Ertele” bu durumda
  arka planda çalışacak şekilde yazıldı; telefonda denenmeli.
- **“09:00'da” okunuşu:** Telefonun ses motorunun saati nasıl okuyacağı
  denenmeli.
- **Uygulama boyutu:** Yayın APK'sı yaklaşık 98 MB (yazı tanıma modeli dahil).
- Yalnızca Android içindir; iOS ayarları yapılmadı.
