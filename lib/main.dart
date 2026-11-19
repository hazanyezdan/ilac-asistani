import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import 'ajanda.dart';
import 'ayarlar.dart';
import 'bip.dart';
import 'cihaz.dart';
import 'hatirlatma_servisi.dart';
import 'ilac_veritabani.dart';
import 'karekod.dart';
import 'komutlar.dart';
import 'saat_ayristir.dart';
import 'ses.dart';
import 'turkce.dart';
import 'zamanlama.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IlacAsistaniApp());
}

class IlacAsistaniApp extends StatelessWidget {
  const IlacAsistaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İlaç Asistanı',
      debugShowCheckedModeBanner: false,
      // Az gören kullanıcılar için yüksek kontrastlı koyu tema.
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.yellow,
          onPrimary: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const TaramaEkrani(),
    );
  }
}

/// Son okunan ilaç: hatırlatma kurarken kullanılır.
typedef OkunanIlac = ({String gtin, String? ad});

class TaramaEkrani extends StatefulWidget {
  const TaramaEkrani({super.key});

  @override
  State<TaramaEkrani> createState() => _TaramaEkraniState();
}

class _TaramaEkraniState extends State<TaramaEkrani>
    with WidgetsBindingObserver {
  /// Aynı kod bu süre içinde tekrar okunursa yeniden söylenmez.
  static const _tekrarBeklemeSuresi = Duration(seconds: 5);

  static const _mikrofonAyarAnlatimi =
      'Sesli komutları kullanmak için telefonun Ayarlar, Uygulamalar, '
      'İlaç Asistanı, İzinler bölümünden mikrofonu açabilirsiniz.';
  static const _kameraAyarAnlatimi =
      'Telefonun Ayarlar, Uygulamalar, İlaç Asistanı, İzinler bölümünden '
      'kamerayı açabilirsiniz.';
  static const _yardimMetni =
      'Şunları söyleyebilirsiniz: tekrar söyle. Feneri aç. Feneri kapat. '
      'Ajandamı oku. Dokuzdaki hatırlatmayı sil. Aldım. Ertele. Sus. '
      'Bip sesini kapat. Bip sesini aç. '
      'Bir ilaç okuttuktan sonra, her gün saat dokuzda hatırlat da '
      'diyebilirsiniz.';

  static const _ekranOkuyucuAnlatimi =
      'TalkBack açık. Ben de TalkBack üzerinden konuşacağım. TalkBack '
      'açıkken ekranın her yerine iki kez dokunmak çalışmaz. Sesli komut '
      'vermek için ekranın üst yarısındaki kamera alanına ya da Sesli komut '
      'ver düğmesine dokunun, sonra iki kez dokunun.';
  static const _turkceSesAnlatimi =
      'Telefonunuzda Türkçe ses paketi yüklü değil. Yüklemek için telefonun '
      'Ayarlar bölümünde Metin okuma, sonra Google, sonra Ses verilerini '
      'yükle, sonra Türkçe seçeneğine gidin. Ekrandaki Ses ayarlarını aç '
      'düğmesi sizi oraya götürür.';

  // Kamera, izin verildikten sonra elle başlatılır.
  final MobileScannerController _kamera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    autoStart: false,
  );
  final SesServisi _ses = SesServisi();
  final AjandaDeposu _depo = AjandaDeposu();
  late final HatirlatmaServisi _servis = HatirlatmaServisi(depo: _depo);
  final AyarDeposu _ayarlar = AyarDeposu();

  // Bip ile yönlendirme ve "kod bulunamadı" ipucu.
  bool _bipAcik = true;
  Duration? _bipAraligi;
  DateTime _sonAlgilama = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _bipZamanlayici;
  final AramaIpucu _aramaIpucu = AramaIpucu();
  Timer? _ipucuZamanlayici;

  bool _onPlanda = true;

  /// TalkBack açık mı? Ekrandaki açıklamalar buna göre değişir.
  bool _ekranOkuyucuAcik = false;

  IlacVeritabani _ilaclar = IlacVeritabani({});
  Ajanda _ajanda = Ajanda();

  String _durum = 'İlacın karekodunu kameraya tutun.';
  String? _sonKod;
  DateTime _sonOkumaZamani = DateTime.fromMillisecondsSinceEpoch(0);
  OkunanIlac? _sonOkunanIlac;

  /// Bildirime dokunularak açılan hatırlatmanın numarası ("aldım" için).
  int? _sonBildirimId;

  /// Bir soru-cevap sürerken kamera yeni kodları yok sayar.
  bool _mesgul = true;
  bool _kameraIzniVar = false;
  bool _mikrofonVar = false;
  bool _izinUyarisiSoylendi = false;

  /// Açılıştaki izin soruları bitti mi? İzin pencereleri de uygulamayı
  /// "geri dönmüş" gibi gösterdiği için o sırada yeniden kontrol yapılmaz.
  bool _acilisBitti = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_baslat());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bipleriDurdur();
    _ipucuZamanlayici?.cancel();
    unawaited(_ses.sustur());
    unawaited(_kamera.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    _onPlanda = durum == AppLifecycleState.resumed;
    if (!_onPlanda) _bipleriDurdur();
    if (durum != AppLifecycleState.resumed || !_acilisBitti) return;
    // Kullanıcı ses ayarlarından Türkçe sesi yüklemiş olabilir.
    unawaited(() async {
      await _ses.turkceSesiDenetle();
      if (mounted) setState(() {});
    }());
    // Kullanıcı ayarlardan izin vermiş ya da bildirim düğmesine basmış olabilir.
    // Tam zamanlı alarm izni yeni verildiyse bildirimler tam saate göre
    // yeniden kurulur.
    unawaited(() async {
      await _ajandayiTazele();
      await _servis.hepsiniYenidenKur(_ajanda);
    }());
    if (!_kameraIzniVar) {
      unawaited(() async {
        if (await Permission.camera.isGranted) await _kamerayiAc();
      }());
    }
    if (!_mikrofonVar) {
      unawaited(() async {
        if (await Permission.microphone.isGranted) {
          _mikrofonVar = await _ses.dinlemeyiHazirla();
        }
      }());
    }
  }

  /// TalkBack açılıp kapanınca konuşma yolu değişir; kullanıcıya anlatılır.
  @override
  void didChangeAccessibilityFeatures() {
    final acik = _ses.ekranOkuyucuAcik;
    if (acik == _ekranOkuyucuAcik) return;
    setState(() => _ekranOkuyucuAcik = acik);
    if (!_acilisBitti) return;
    unawaited(
      _mesgulken(
        () => _konus(
          acik
              ? _ekranOkuyucuAnlatimi
              : 'TalkBack kapandı. Artık ekranın herhangi bir yerine iki kez '
                    'dokunarak sesli komut verebilirsiniz.',
        ),
      ),
    );
  }

  /// "Tekrar denemek için ..." gibi cümlelerde dinlemenin nasıl başlatılacağı.
  String get _dinlemeTarifi => _ekranOkuyucuAcik
      ? 'Sesli komut ver düğmesine iki kez dokunun'
      : 'ekrana iki kez dokunun';

  // ---------------------------------------------------------------------
  // Açılış ve izinler
  // ---------------------------------------------------------------------

  Future<void> _baslat() async {
    await _ses.hazirla();
    _ekranOkuyucuAcik = _ses.ekranOkuyucuAcik;
    _bipAcik = await _ayarlar.bipAcikMi();
    _ilaclar = await IlacVeritabani.yukle();
    _ajanda = await _depo.yukle();
    try {
      await _servis.baslat(bildirimeDokunuldu: _bildirimYaniti);
      await _servis.hepsiniYenidenKur(_ajanda);
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
    if (mounted) setState(() {});

    if (!_ses.turkceSesHazir) {
      await _ses.soyle(_turkceSesAnlatimi, kesilebilir: false);
    }
    await _mikrofonIzniniAl();
    await _kameraIzniniAl();

    final acilis = await _servis.acilisBildirimi();
    _mesgul = false;
    _acilisBitti = true;
    _aramaIpucu.sifirla(DateTime.now());
    _ipucuZamanlayici = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _ipucuKontrol(),
    );
    if (acilis != null) {
      await _bildirimYaniti(acilis);
    } else {
      final sesliKomut = !_mikrofonVar
          ? ''
          : _ekranOkuyucuAcik
          ? _ekranOkuyucuAnlatimi
          : 'Sesli komut vermek için ekrana iki kez dokunun.';
      await _konus(
        'İlaç Asistanı hazır. İlacın karekodunu kameraya tutun. $sesliKomut',
      );
    }
  }

  Future<void> _mikrofonIzniniAl() async {
    var durum = await Permission.microphone.status;
    if (!durum.isGranted && !durum.isPermanentlyDenied) {
      await _ses.soyle(
        'Merhaba, ben İlaç Asistanı. Sizinle sesli konuşabilmem için mikrofon '
        'izni gerekiyor. Şimdi ekranda bir izin penceresi açılacak. '
        'Uygulamayı kullanırken izin ver düğmesine dokunun.',
        kesilebilir: false,
      );
      durum = await Permission.microphone.request();
    }
    if (!durum.isGranted) {
      await _ses.soyle(
        'Mikrofon izni verilmedi. $_mikrofonAyarAnlatimi',
        kesilebilir: false,
      );
      return;
    }
    _mikrofonVar = await _ses.dinlemeyiHazirla();
    if (!_mikrofonVar) {
      await _ses.soyle(
        'Bu telefonda konuşma tanıma hizmeti bulunamadı. Google uygulamasının '
        'yüklü ve güncel olduğundan emin olun.',
        kesilebilir: false,
      );
    }
  }

  Future<void> _kameraIzniniAl() async {
    var durum = await Permission.camera.status;
    if (durum.isGranted) {
      await _kamerayiAc();
      return;
    }
    if (_mikrofonVar) {
      final cevap = await _evetHayirSor(
        'İlaç kutularını okuyabilmem için kamera izni gerekiyor. Kameraya izin '
        'vermek istiyor musunuz? Evet ya da hayır deyin.',
      );
      if (cevap.yanit != Yanit.evet) {
        await _konus(
          'Tamam, kamera kapalı kalacak ve karekod okuyamayacağım. Fikrinizi '
          'değiştirirseniz $_dinlemeTarifi ve kamera izni deyin.',
        );
        return;
      }
    }
    if (durum.isPermanentlyDenied) {
      await _ses.soyle(
        'Kamera izni daha önce reddedilmiş. Şimdi telefon ayarlarını açıyorum. '
        'İzinler bölümünden kamerayı açın, sonra geri tuşuna basın.',
        kesilebilir: false,
      );
      await openAppSettings();
      return;
    }
    await _ses.soyle(
      'Şimdi ekranda kamera izni penceresi açılacak. Uygulamayı kullanırken '
      'izin ver düğmesine dokunun.',
      kesilebilir: false,
    );
    durum = await Permission.camera.request();
    if (durum.isGranted) {
      await _kamerayiAc();
      await _konus('Teşekkürler, kamera açıldı.');
    } else {
      await _konus('Kamera izni verilmedi. $_kameraAyarAnlatimi');
    }
  }

  Future<void> _kamerayiAc() async {
    if (_kameraIzniVar) return;
    try {
      await _kamera.start();
      if (mounted) setState(() => _kameraIzniVar = true);
    } catch (e) {
      debugPrint('Kamera açılamadı: $e');
    }
  }

  /// Hatırlatma kurmadan önce bildirim ve tam zamanlı alarm izinlerini
  /// sesli açıklayarak ister. Tam zamanlı izin yoksa uyarı metni döner.
  Future<String> _bildirimIzinleriniAl() async {
    if (!await _servis.bildirimIzniVarMi()) {
      await _ses.soyle(
        'Hatırlatmaları gösterebilmem için bildirim izni gerekiyor. Şimdi '
        'açılacak pencerede izin ver düğmesine dokunun.',
        kesilebilir: false,
      );
      await _servis.bildirimIzniIste();
      if (!await _servis.bildirimIzniVarMi()) {
        return ' Ancak bildirim izni verilmediği için hatırlatma gelmeyecek. '
            'Telefonun Ayarlar, Uygulamalar, İlaç Asistanı, Bildirimler '
            'bölümünden izni açabilirsiniz.';
      }
    }
    if (!await _servis.tamZamanliIzinVarMi()) {
      await _ses.soyle(
        'Hatırlatmanın tam saatinde gelmesi için alarmlar ve hatırlatıcılar '
        'izni gerekiyor. Şimdi bir ayar ekranı açılacak. Oradaki izin ver '
        'anahtarını açın, sonra geri tuşuna basın.',
        kesilebilir: false,
      );
      await _servis.tamZamanliIzinIste();
      if (!await _servis.tamZamanliIzinVarMi()) {
        return ' Tam saat izni olmadığı için hatırlatma birkaç dakika '
            'gecikebilir.';
      }
    }
    return '';
  }

  // ---------------------------------------------------------------------
  // Konuşma yardımcıları
  // ---------------------------------------------------------------------

  /// Metni ekrana yazar ve söyler. Kullanıcı araya girerse komutunu işler.
  Future<void> _konus(String metin) async {
    if (mounted) setState(() => _durum = metin);
    final arayaGiren = await _ses.soyle(metin);
    if (arayaGiren != null) await _komutIsle(arayaGiren);
  }

  /// Soruyu sorar ve cevabı dinler. Kullanıcı soru bitmeden konuşursa
  /// o söz cevap sayılır.
  Future<String?> _sorVeDinle(String soru) async {
    if (mounted) setState(() => _durum = soru);
    final arayaGiren = await _ses.soyle(soru);
    if (arayaGiren != null) return arayaGiren;
    if (!_mikrofonVar) return null;
    return _ses.dinle();
  }

  /// Evet/hayır sorusu. Anlaşılmazsa bir kez daha sorar.
  Future<({Yanit yanit, String metin})> _evetHayirSor(String soru) async {
    var metin = '';
    for (var deneme = 0; deneme < 2; deneme++) {
      metin =
          await _sorVeDinle(
            deneme == 0 ? soru : 'Anlayamadım. Lütfen evet ya da hayır deyin.',
          ) ??
          '';
      final yanit = yanitiAnla(metin);
      if (yanit != Yanit.belirsiz) return (yanit: yanit, metin: metin);
      // Cevapta saat varsa (ör. "akşam dokuzda") bu da bir cevaptır.
      if (saatiAyikla(metin) != null) {
        return (yanit: Yanit.belirsiz, metin: metin);
      }
    }
    return (yanit: Yanit.belirsiz, metin: metin);
  }

  /// Onay alır: mikrofon varsa sesle, yoksa ekranda bir pencereyle.
  Future<bool> _onayAl(String soru) async {
    if (_mikrofonVar) return (await _evetHayirSor(soru)).yanit == Yanit.evet;
    if (!mounted) return false;
    unawaited(_ses.soyle(soru, kesilebilir: false));
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(soru, style: const TextStyle(fontSize: 24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır', style: TextStyle(fontSize: 24)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
    await _ses.sustur();
    return sonuc ?? false;
  }

  /// Bir soru-cevap akışını, kameranın araya girmesini engelleyerek çalıştırır.
  Future<void> _mesgulken(Future<void> Function() is_) async {
    final onceki = _mesgul;
    _mesgul = true;
    try {
      await is_();
    } finally {
      _mesgul = onceki;
    }
  }

  // ---------------------------------------------------------------------
  // Karekod okuma
  // ---------------------------------------------------------------------

  Future<void> _titret() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 300);
    }
  }

  Future<void> _kodOkundu(BarcodeCapture yakalama) async {
    if (yakalama.barcodes.isEmpty) return;
    final simdi = DateTime.now();
    _aramaIpucu.sifirla(simdi);
    final okunanlar = yakalama.barcodes
        .where((b) => (b.rawValue ?? '').isNotEmpty)
        .toList();
    if (okunanlar.isEmpty) {
      // Kod görüldü ama çözülemedi: bip sesleriyle yönlendir.
      _yonlendir(yakalama.barcodes.first, yakalama.size, simdi);
      return;
    }
    _bipleriDurdur();

    if (_mesgul || _ses.konusuyor || _ses.dinliyor.value) return;
    final ham = okunanlar.first.rawValue!;
    if (ham == _sonKod &&
        simdi.difference(_sonOkumaZamani) < _tekrarBeklemeSuresi) {
      return;
    }
    _sonKod = ham;
    _sonOkumaZamani = simdi;

    final ilac = karekoduCoz(ham);
    final barkod = ilac?.gtin ?? rakamliBarkod(ham);
    final ad = _ilaclar.ad(barkod);
    if (barkod != null && (ilac != null || ad != null)) {
      _sonOkunanIlac = (gtin: barkod, ad: ad);
    }

    final metin = sesliMetinHazirla(
      ham,
      ilacAdi: ad == null ? null : konusmaIcinAd(ad),
    );
    unawaited(_titret());
    await _mesgulken(() async {
      if (mounted) setState(() => _durum = metin);
      final arayaGiren = await _ses.soyle(metin);
      if (arayaGiren != null) {
        await _komutIsle(arayaGiren);
        return;
      }
      // Geçerli bir ilaç karekodu okunduysa hatırlatma teklif et.
      final skt = ilac?.sonKullanma;
      final gecerli = skt == null || !tarihiGecmisMi(skt);
      if (ilac?.gtin != null && gecerli && _mikrofonVar) {
        await _hatirlatmaAkisi(sor: true);
      }
    });
  }

  // ---------------------------------------------------------------------
  // Bip ile yönlendirme ve "kod bulunamadı" ipucu
  // ---------------------------------------------------------------------

  bool get _bosta =>
      _onPlanda && !_mesgul && !_ses.konusuyor && !_ses.dinliyor.value;

  void _yonlendir(Barcode kod, Size goruntu, DateTime simdi) {
    _bipAraligi =
        bipAraligi(kod.corners, goruntu) ?? const Duration(milliseconds: 600);
    _sonAlgilama = simdi;
    if (_bipZamanlayici == null) _bipCal();
  }

  /// Kod görülmeye devam ettiği sürece, hesaplanan aralıkla bip çalar.
  /// Konuşurken ya da dinlerken çalmaz (mikrofon bip sesini duymasın).
  void _bipCal() {
    final aralik = _bipAraligi;
    final guncel =
        DateTime.now().difference(_sonAlgilama) <
        const Duration(milliseconds: 800);
    if (!_bipAcik || aralik == null || !guncel || !_bosta) {
      _bipZamanlayici = null;
      return;
    }
    unawaited(Cihaz.bip());
    _bipZamanlayici = Timer(aralik, _bipCal);
  }

  void _bipleriDurdur() {
    _bipZamanlayici?.cancel();
    _bipZamanlayici = null;
    _bipAraligi = null;
  }

  Future<void> _bipAyarla(bool acik) async {
    await _ayarlar.bipAyarla(acik);
    if (!acik) _bipleriDurdur();
    if (mounted) setState(() => _bipAcik = acik);
    await _konus(
      acik
          ? 'Bip sesi açıldı. Kod görünüp okunamadığında bip sesleriyle '
                'yönlendireceğim.'
          : 'Bip sesi kapatıldı. Açmak için bip sesini aç deyin.',
    );
  }

  /// Saniyede bir çalışır: 15 saniye boyunca kod bulunamazsa ipucu verir.
  void _ipucuKontrol() {
    final simdi = DateTime.now();
    if (!_kameraIzniVar || !_bosta) {
      _aramaIpucu.mesgulOldu(simdi);
      return;
    }
    if (_aramaIpucu.ipucuVerilsinMi(simdi)) {
      unawaited(_mesgulken(() => _konus(AramaIpucu.metin)));
    }
  }

  // ---------------------------------------------------------------------
  // Hatırlatma kurma
  // ---------------------------------------------------------------------

  Future<void> _hatirlatmaAkisi({bool sor = false, SaatBilgisi? saat}) async {
    final ilac = _sonOkunanIlac;
    if (ilac == null) {
      await _konus(
        'Önce ilacın karekodunu kameraya tutun, sonra hatırlatma kurabilirim.',
      );
      return;
    }

    if (sor) {
      final cevap = await _evetHayirSor(
        'Bu ilaç için hatırlatma kurmak ister misiniz?',
      );
      // "Evet, her gün dokuzda" gibi cevaplarda saati de al.
      saat ??= saatiAyikla(cevap.metin);
      if (cevap.yanit == Yanit.hayir ||
          (cevap.yanit == Yanit.belirsiz && saat == null)) {
        await _konus('Tamam, hatırlatma kurmadım.');
        return;
      }
    }

    if (saat == null) {
      for (var deneme = 0; deneme < 2 && saat == null; deneme++) {
        final cevap = await _sorVeDinle(
          deneme == 0
              ? 'Her gün saat kaçta hatırlatayım? Örneğin her gün sabah '
                    'dokuzda diyebilirsiniz.'
              : 'Anlayamadım, saati tekrar söyler misiniz?',
        );
        if (cevap != null && yanitiAnla(cevap) == Yanit.hayir) {
          await _konus('Tamam, hatırlatma kurmadım.');
          return;
        }
        saat = cevap == null ? null : saatiAyikla(cevap);
      }
      if (saat == null) {
        await _konus(
          'Saati anlayamadım, hatırlatma kurmadım. İsterseniz ilacı kameraya '
          'tekrar tutabilirsiniz.',
        );
        return;
      }
    }

    // Onay: saat, sabah/akşam bilgisiyle açıkça söylenir.
    for (var deneme = 0; deneme < 2; deneme++) {
      final s = saat!;
      final adKismi = ilac.ad == null ? '' : '${konusmaIcinAd(ilac.ad!)} için ';
      final cevap = await _evetHayirSor(
        '${adKismi}her gün ${gununBolumu(s.saat)} '
        '${ekliSaatMetni(s.saat, s.dakika)} hatırlatma kurulacak. '
        'Onaylıyor musunuz?',
      );
      if (cevap.yanit == Yanit.evet) {
        await _hatirlatmaKaydet(ilac, s);
        return;
      }
      // "Hayır, akşam dokuzda" denirse yeni saati onaya sun.
      final yeniSaat = saatiAyikla(cevap.metin);
      if (yeniSaat != null && yeniSaat != s) {
        saat = yeniSaat;
        continue;
      }
      await _konus(
        cevap.yanit == Yanit.hayir
            ? 'Hatırlatma iptal edildi.'
            : 'Onay alamadım, hatırlatma kurmadım.',
      );
      return;
    }
    await _konus('Hatırlatma kurmadım.');
  }

  Future<void> _hatirlatmaKaydet(OkunanIlac ilac, SaatBilgisi saat) async {
    final uyari = await _bildirimIzinleriniAl();
    final sonuc = _ajanda.ekle(
      saat: saat.saat,
      dakika: saat.dakika,
      gtin: ilac.gtin,
      ilacAdi: ilac.ad,
    );
    await _depo.kaydet(_ajanda);
    try {
      await _servis.kur(sonuc.hatirlatma);
    } catch (e) {
      debugPrint('Bildirim kurulamadı: $e');
    }
    if (mounted) setState(() {});
    final saatYazisi = ekliSaatMetni(saat.saat, saat.dakika);
    await _konus(
      sonuc.yeni
          ? 'Hatırlatma kuruldu. Her gün $saatYazisi size haber vereceğim.$uyari'
          : 'Bu ilaç için $saatYazisi zaten bir hatırlatma vardı.$uyari',
    );
  }

  // ---------------------------------------------------------------------
  // Ajanda, silme, aldım, ertele
  // ---------------------------------------------------------------------

  Future<void> _ajandayiTazele() async {
    final yeni = await _depo.yukle();
    if (mounted) setState(() => _ajanda = yeni);
  }

  Future<void> _silAkisi(SaatBilgisi? saat) async {
    await _ajandayiTazele();
    if (_ajanda.bosMu) {
      await _konus('Kurulu hatırlatmanız yok.');
      return;
    }
    List<Hatirlatma> eslesenler = saat == null
        ? (_ajanda.adet == 1 ? _ajanda.sirali : [])
        : _ajanda.saateGoreBul(saat);

    for (var deneme = 0; deneme < 2 && eslesenler.length != 1; deneme++) {
      final soru = eslesenler.length > 1
          ? 'Bu saatte birden fazla hatırlatma var. Sabah ya da akşam '
                'diyerek saati tekrar söyler misiniz?'
          : saat == null
          ? 'Hangi saatteki hatırlatmayı silmek istiyorsunuz? '
                '${_ajanda.okunacakMetin()}'
          : 'Saat ${saat.metin} için hatırlatma bulamadım. Hangi saattekini '
                'silmek istiyorsunuz?';
      final cevap = await _sorVeDinle(soru);
      final yeniSaat = cevap == null ? null : saatiAyikla(cevap);
      if (yeniSaat == null) break;
      saat = yeniSaat;
      eslesenler = _ajanda.saateGoreBul(yeniSaat);
    }
    if (eslesenler.length != 1) {
      await _konus('Silinecek hatırlatmayı bulamadım, hiçbir şey silmedim.');
      return;
    }
    await _silOnayla(eslesenler.single);
  }

  Future<void> _silOnayla(Hatirlatma h) async {
    final onay = await _onayAl(
      '${gununBolumu(h.saat)} ${h.saatYazisi} ${h.okunacakAd} hatırlatması '
      'silinsin mi?',
    );
    if (!onay) {
      await _konus('Tamam, silmedim.');
      return;
    }
    await _servis.iptal(h);
    _ajanda.sil(h.id);
    await _depo.kaydet(_ajanda);
    if (mounted) setState(() {});
    await _konus('Hatırlatma silindi.');
  }

  Future<void> _aldimSesle() async {
    await _ajandayiTazele();
    final id = _sonBildirimId ?? _ajanda.simdikiHatirlatma(DateTime.now())?.id;
    final h = await _servis.aldim(id);
    _sonBildirimId = null;
    await _ajandayiTazele();
    await _konus(
      h == null
          ? 'Kaydedildi. İlacınızı aldığınızı not ettim.'
          : 'Kaydedildi. ${h.okunacakAd} için bugünkü tekrar hatırlatmalarını '
                'iptal ettim.',
    );
  }

  Future<void> _erteleSesle() async {
    await _ajandayiTazele();
    final id = _sonBildirimId ?? _ajanda.simdikiHatirlatma(DateTime.now())?.id;
    final h = await _servis.ertele(id);
    await _ajandayiTazele();
    await _konus(
      h == null
          ? 'Ertelenecek bir hatırlatma bulamadım.'
          : 'Tamam, $ertelemeDakikasi dakika sonra tekrar hatırlatacağım.',
    );
  }

  /// Bildirime ya da bildirimdeki düğmeye dokunulunca (uygulama açıkken).
  Future<void> _bildirimYaniti(NotificationResponse yanit) async {
    final id = HatirlatmaServisi.yuktenId(yanit.payload);
    if (yanit.actionId != null) {
      final h = await _servis.eylemIsle(yanit.actionId, yanit.payload);
      await _ajandayiTazele();
      if (h != null) {
        await _konus(
          yanit.actionId == aldimEylemi
              ? 'Kaydedildi. İlacınızı aldığınızı not ettim.'
              : 'Tamam, $ertelemeDakikasi dakika sonra tekrar hatırlatacağım.',
        );
      }
      return;
    }
    await _ajandayiTazele();
    final h = id == null ? null : _ajanda.bul(id);
    if (h == null) return;
    _sonBildirimId = h.id;
    await _mesgulken(() async {
      final ad = h.ilacAdi == null ? '' : ' İlacınız: ${h.okunacakAd}.';
      final cevap = await _sorVeDinle(
        'Saat ${h.saatYazisi}. İlacınızı alma zamanı.$ad '
        '${_mikrofonVar ? 'Aldıysanız aldım, sonra hatırlatmamı isterseniz ertele deyin.' : ''}',
      );
      if (cevap != null) await _komutIsle(cevap);
    });
  }

  // ---------------------------------------------------------------------
  // Sesli komutlar
  // ---------------------------------------------------------------------

  /// Ekrana iki kez dokunulunca dinlemeye başlar.
  Future<void> _dinlemeyiBaslat() async {
    if (_mesgul) {
      // Bir soru soruluyorsa sadece sustur; soru akışı dinlemeye geçer.
      await _ses.sustur();
      return;
    }
    if (!_mikrofonVar) {
      await _mesgulken(_mikrofonIzniniAl);
      return;
    }
    await _mesgulken(() async {
      unawaited(Vibration.vibrate(duration: 100));
      if (mounted) setState(() => _durum = 'Dinliyorum...');
      final cevap = await _ses.dinle();
      if (cevap == null) {
        await _konus('Bir şey duyamadım. Tekrar denemek için $_dinlemeTarifi.');
      } else {
        await _komutIsle(cevap);
      }
    });
  }

  Future<void> _komutIsle(String metin) async {
    final komut = komutuTani(metin);
    switch (komut.tur) {
      case KomutTuru.tekrar:
        await _tekrarSoyle();
      case KomutTuru.fenerAc:
        await _fener(acilsin: true);
      case KomutTuru.fenerKapat:
        await _fener(acilsin: false);
      case KomutTuru.ajandaOku:
        await _ajandayiTazele();
        await _konus(_ajanda.okunacakMetin());
      case KomutTuru.hatirlatmaKur:
        await _hatirlatmaAkisi(saat: komut.saat);
      case KomutTuru.hatirlatmaSil:
        await _silAkisi(komut.saat);
      case KomutTuru.aldim:
        await _aldimSesle();
      case KomutTuru.ertele:
        await _erteleSesle();
      case KomutTuru.kameraIzni:
        if (_kameraIzniVar) {
          await _konus('Kamera zaten açık.');
        } else {
          await _kameraIzniniAl();
        }
      case KomutTuru.yardim:
        await _konus(_yardimMetni);
      case KomutTuru.sus:
        await _ses.sustur();
      case KomutTuru.bipAc:
        await _bipAyarla(true);
      case KomutTuru.bipKapat:
        await _bipAyarla(false);
      case KomutTuru.bilinmiyor:
        await _konus(
          'Anlayamadım. Neler yapabileceğimi duymak için yardım deyin.',
        );
    }
  }

  Future<void> _tekrarSoyle() => _konus(_durum);

  Future<void> _fener({bool? acilsin}) async {
    final durum = _kamera.value.torchState;
    if (!_kameraIzniVar || durum == TorchState.unavailable) {
      await _konus('Fener kullanılamıyor.');
      return;
    }
    final acik = durum == TorchState.on;
    if (acilsin == null || acilsin != acik) await _kamera.toggleTorch();
    final simdiAcik = acilsin ?? !acik;
    await _konus(simdiAcik ? 'Fener açıldı' : 'Fener kapandı');
  }

  // ---------------------------------------------------------------------
  // Ekran
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlaç Asistanı'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.yellow,
      ),
      // Ekranın herhangi bir yerine iki kez dokununca dinlemeye başlar.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _dinlemeyiBaslat,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _kameraAlani()),
              Expanded(flex: 3, child: _altBolum()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kameraAlani() {
    // TalkBack açıkken iki kez dokunma, odaktaki öğeye "dokun" demektir;
    // bu yüzden kamera alanına dokunma eylemi olarak dinlemeyi bağladık.
    return Semantics(
      label: _kameraIzniVar
          ? 'Kamera açık. İlacın karekodunu ya da barkodunu telefonun '
                'arkasına doğru tutun.'
          : 'Kamera kapalı. Kamera izni verilmedi.',
      hint:
          'Sesli komut vermek için iki kez dokunun. Ekranın başka yerine '
          'iki kez dokunmak TalkBack açıkken çalışmaz.',
      image: true,
      onTap: _dinlemeyiBaslat,
      child: ExcludeSemantics(
        child: _kameraIzniVar
            ? MobileScanner(
                controller: _kamera,
                onDetect: _kodOkundu,
                errorBuilder: _hataEkrani,
              )
            : const Center(
                child: Text(
                  'Kamera kapalı',
                  style: TextStyle(fontSize: 26, color: Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _altBolum() {
    final hatirlatmalar = _ajanda.sirali;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_ses.turkceSesHazir) _turkceSesUyarisi(),
        ValueListenableBuilder<bool>(
          valueListenable: _ses.dinliyor,
          builder: (context, dinliyor, _) => dinliyor
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '🎤 Dinliyorum...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, color: Colors.yellow),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Semantics(
          label: 'Son durum',
          child: Text(
            _durum,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _BuyukDugme(
          yazi: 'Sesli komut ver',
          ipucu: 'Dinlemeye başlar. Örneğin ajandamı oku diyebilirsiniz.',
          simge: Icons.mic,
          onPressed: _dinlemeyiBaslat,
        ),
        const SizedBox(height: 8),
        _BuyukDugme(
          yazi: 'Tekrar söyle',
          ipucu: 'Son okunan bilgiyi yeniden sesli söyler',
          simge: Icons.volume_up,
          onPressed: _tekrarSoyle,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _kamera,
          builder: (context, durum, _) {
            final acik = durum.torchState == TorchState.on;
            return _BuyukDugme(
              yazi: acik ? 'Feneri kapat' : 'Feneri aç',
              ipucu:
                  'Karanlıkta okumayı kolaylaştırmak için '
                  'telefonun ışığını açar veya kapatır',
              simge: acik ? Icons.flashlight_off : Icons.flashlight_on,
              onPressed:
                  !_kameraIzniVar || durum.torchState == TorchState.unavailable
                  ? null
                  : () => _fener(acilsin: !acik),
            );
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _bipAcik,
          onChanged: (acik) => _mesgulken(() => _bipAyarla(acik)),
          activeThumbColor: Colors.yellow,
          title: const Text(
            'Bip sesiyle yönlendirme',
            style: TextStyle(fontSize: 24, color: Colors.white),
          ),
          subtitle: const Text(
            'Kod görünüp okunamadığında bip çalar; kod yaklaştıkça hızlanır.',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            'Hatırlatmalarım (${hatirlatmalar.length})',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.yellow,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (hatirlatmalar.isEmpty)
          const Text(
            'Kurulu hatırlatma yok. Bir ilacın karekodunu okutunca '
            'hatırlatma kurmak isteyip istemediğinizi soracağım.',
            style: TextStyle(fontSize: 22, color: Colors.white),
          ),
        for (final h in hatirlatmalar) _hatirlatmaSatiri(h),
      ],
    );
  }

  /// Telefonda Türkçe ses yoksa en üstte duran büyük uyarı.
  Widget _turkceSesUyarisi() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.yellow, width: 4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Türkçe ses yüklü değil',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.yellow,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Uygulamanın Türkçe konuşabilmesi için telefona Türkçe ses '
            'yükleyin:\nAyarlar > Metin okuma > Google > Ses verilerini '
            'yükle > Türkçe',
            style: TextStyle(fontSize: 24, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _BuyukDugme(
            yazi: 'Ses ayarlarını aç',
            ipucu: 'Telefonun metin okuma ayarlarını açar',
            simge: Icons.settings_voice,
            onPressed: () async {
              if (!await Cihaz.sesAyarlariniAc()) {
                await _konus(
                  'Ayarlar açılamadı. Telefonun Ayarlar bölümünden Metin '
                  'okuma seçeneğini bulun.',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _hatirlatmaSatiri(Hatirlatma h) {
    final ad = h.ilacAdi ?? 'İlaç';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                'Her gün ${gununBolumu(h.saat)} saat ${h.saatYazisi}, '
                '${h.okunacakAd}',
            child: ExcludeSemantics(
              child: Text(
                '${h.saatYazisi}  $ad',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Saat ${h.saatYazisi} hatırlatmasını sil',
            button: true,
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: () => _mesgulken(() => _silOnayla(h)),
              icon: const Icon(Icons.delete, size: 32),
              label: const Text('Sil', style: TextStyle(fontSize: 24)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: Colors.yellow,
                side: const BorderSide(color: Colors.yellow, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hataEkrani(BuildContext context, MobileScannerException hata) {
    final metin = hata.errorCode == MobileScannerErrorCode.permissionDenied
        ? 'Kamera izni verilmedi. Uygulamayı kullanmak için ayarlardan '
              'kamera iznini açın.'
        : 'Kamera açılamadı.';
    if (!_izinUyarisiSoylendi) {
      _izinUyarisiSoylendi = true;
      unawaited(_ses.soyle(metin, kesilebilir: false));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          metin,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }
}

/// TalkBack ile rahat bulunabilen, büyük ve yüksek kontrastlı düğme.
class _BuyukDugme extends StatelessWidget {
  const _BuyukDugme({
    required this.yazi,
    required this.ipucu,
    required this.simge,
    required this.onPressed,
  });

  final String yazi;
  final String ipucu;
  final IconData simge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: ipucu,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(simge, size: 36),
        label: Text(yazi),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(72),
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
