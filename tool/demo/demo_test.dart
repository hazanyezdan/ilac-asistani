// DEMO VİDEOSU İÇİN EKRAN GÖRÜNTÜSÜ ÜRETİCİ (simülasyon).
//
// Uygulamanın gerçek ekranını (IlacAsistaniApp) Flutter test ortamında
// çalıştırır. Telefona ait eklentiler (kamera, mikrofon, metin okuma, izinler,
// bildirimler, titreşim) taklit edilir; senaryo adım adım oynatılır ve her
// konuşmada/cevapta ekranın görüntüsü alınır. Çıktı: kareler + kareler.json
//
// Çalıştırma: flutter test tool/demo/demo_test.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Çıktı klasörü: DEMO_CIKTI ortam değişkeni.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_asistani/main.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String cikti =
    Platform.environment['DEMO_CIKTI'] ?? '${Directory.systemTemp.path}/demo';

const _dpr = 2.625;
const _mantiksalBoyut = Size(412, 915);

/// Videoda kullanılacak gerçek TİTCK kayıtlarından küçük bir alt küme
/// (test ortamında 1 MB'lık dosyayı yüklemek gerekmesin diye).
const _ilacListesi =
    '8699546130238\tCORASPIN 100 MG 30 ENTERIK KAPLI TABLET\n'
    '8699546130153\tCORASPIN 300 MG 30 ENTERIK KAPLI TABLET\n'
    '8699536090115\tMAJEZIK 100 MG 15 FILM TABLET\n'
    '8699560010370\tPAROL 500 MG 20 TABLET\n';

String karekod(String gtin, String skt, String seri) =>
    '01${gtin}21$seri\u001d17${skt}10L24A';

/// Bir kare: ekran görüntüsü ve altyazı bilgisi.
class Kare {
  Kare(this.tur, this.metin, this.ekler);
  final String tur; // sahne | uygulama | kullanici | bip | bilgi
  final String metin;
  final Map<String, Object?> ekler;
  String? dosya;
  Map<String, Object?> json() => {
    'tur': tur,
    'metin': metin,
    'dosya': dosya,
    ...ekler,
  };
}

class Demo {
  Demo(this.t);
  final WidgetTester t;
  final List<Kare> kareler = [];
  int _sayac = 0;

  // Taklit edilen telefon durumu.
  final Map<int, int> izinler = {}; // izin no → durum (0 yok, 1 var)
  Completer<Object?>? bekleyenKonusma;
  String? bekleyenKonusmaMetni;
  Completer<Object?>? bekleyenIzin;
  bool dinliyor = false;
  bool dinlemeArayaGirme = false;
  int bipSayisi = 0;
  String kamera = 'bos'; // kamerada ne var (videoda çizilir)
  Map<String, Object?>? kameraKutusu;
  String? sahne;
  bool turkceSesVar = true;
  String ocrMetni = '';
  MockStreamHandlerEventSink? tarayiciOlaylari;

  static const stt = MethodChannel('plugin.csdcorp.com/speech_to_text');

  void gunluk(String s) {
    if (Platform.environment['DEMO_GUNLUK'] != null) {
      // ignore: avoid_print
      print(
        '[${t.binding.clock.now().toIso8601String().substring(11, 23)}] '
        '${sahne ?? ''} :: $s',
      );
    }
  }

  void kur() {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (c) async {
      gunluk('tts ${c.method} ${c.arguments}');
      switch (c.method) {
        case 'speak':
          bekleyenKonusmaMetni = c.arguments as String;
          if (dinliyor) dinlemeArayaGirme = true;
          bekleyenKonusma = Completer();
          return bekleyenKonusma!.future;
        case 'isLanguageAvailable':
        case 'isLanguageInstalled':
          return turkceSesVar;
      }
      return 1;
    });
    m.setMockMethodCallHandler(stt, (c) async {
      gunluk('stt ${c.method}');
      switch (c.method) {
        case 'listen':
          dinliyor = true;
          dinlemeArayaGirme = bekleyenKonusma != null;
          return true;
        case 'stop':
        case 'cancel':
          dinliyor = false;
          return null;
      }
      return true;
    });
    m.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (c) async {
        switch (c.method) {
          case 'checkPermissionStatus':
            return izinler[c.arguments as int] ?? 0;
          case 'requestPermissions':
            final istenen = (c.arguments as List).cast<int>();
            bekleyenIzin = Completer();
            await bekleyenIzin!.future;
            for (final i in istenen) {
              izinler[i] = 1;
            }
            return {for (final i in istenen) i: 1};
        }
        return false;
      },
    );
    m.setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
      (c) async {
        gunluk('tarayici ${c.method}');
        switch (c.method) {
          case 'state':
            return 1;
          case 'request':
            return true;
          case 'start':
            return {
              'textureId': 1,
              'cameraDirection': 1,
              'numberOfCameras': 1,
              'currentTorchState': 0,
              'size': {'width': 1080.0, 'height': 1920.0},
              'handlesCropAndRotation': true,
              'naturalDeviceOrientation': 'PORTRAIT_UP',
              'sensorOrientation': 90,
            };
          case 'toggleTorch':
            tarayiciOlaylari?.success({'name': 'torchState', 'data': 1});
            return null;
        }
        return null;
      },
    );
    m.setMockStreamHandler(
      const EventChannel('dev.steenbakker.mobile_scanner/scanner/event'),
      MockStreamHandler.inline(
        onListen: (_, sink) {
          tarayiciOlaylari = sink;
        },
      ),
    );
    m.setMockStreamHandler(
      const EventChannel(
        'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
      ),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    m.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (c) async {
        switch (c.method) {
          case 'initialize':
          case 'areNotificationsEnabled':
          case 'canScheduleExactNotifications':
            return true;
          case 'pendingNotificationRequests':
            return <Object?>[];
        }
        return null;
      },
    );
    // Kutu yazısını okumak için fotoğraf (camera) ve yazı tanıma (ML Kit).
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (c) async {
        gunluk('foto ${c.method}');
        switch (c.method) {
          case 'availableCameras':
            return [
              {'name': '0', 'lensFacing': 'back', 'sensorOrientation': 90},
            ];
          case 'create':
            return {'cameraId': 0};
          case 'initialize':
            Timer.run(() {
              m.handlePlatformMessage(
                'flutter.io/cameraPlugin/camera0',
                const StandardMethodCodec().encodeMethodCall(
                  const MethodCall('initialized', {
                    'previewWidth': 1920.0,
                    'previewHeight': 1080.0,
                    'exposureMode': 'auto',
                    'exposurePointSupported': false,
                    'focusMode': 'auto',
                    'focusPointSupported': false,
                  }),
                ),
                (_) {},
              );
            });
            return null;
          case 'takePicture':
            return '$cikti/kutu_foto.jpg';
        }
        return null;
      },
    );
    m.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_text_recognizer'),
      (c) async {
        gunluk('mlkit ${c.method}');
        if (c.method == 'vision#startTextRecognizer') {
          return {'text': ocrMetni, 'blocks': <Object?>[]};
        }
        return null;
      },
    );
    m.setMockMethodCallHandler(const MethodChannel('vibration'), (c) async {
      if (c.method == 'hasVibrator') return true;
      return null;
    });
    m.setMockMethodCallHandler(const MethodChannel('ilac_asistani/cihaz'), (
      c,
    ) async {
      if (c.method == 'bip') bipSayisi++;
      return true;
    });
    // İlaç listesi: gerçek listeden küçük bir alt küme.
    m.setMockMessageHandler('flutter/assets', (mesaj) async {
      final anahtar = utf8.decode(mesaj!.buffer.asUint8List());
      if (anahtar == 'assets/ilaclar.tsv') {
        return ByteData.sublistView(utf8.encode(_ilacListesi));
      }
      final dosya = File('build/unit_test_assets/$anahtar');
      if (!dosya.existsSync()) return null;
      return ByteData.sublistView(dosya.readAsBytesSync());
    });
  }

  Future<void> kareAl(
    String tur,
    String metin, {
    Map<String, Object?> ekler = const {},
  }) async {
    final kare = Kare(tur, metin, {
      'sahne': sahne,
      'kamera': kamera,
      'kameraKutusu': kameraKutusu,
      ...ekler,
    });
    if (tur != 'sahne') {
      await t.pump(const Duration(milliseconds: 16));
      kare.ekler['yazilar'] = _yenidenCizilecekYazilar();
      kare.ekler['kameraAcik'] = find
          .byType(MobileScanner)
          .evaluate()
          .isNotEmpty;
      kare.ekler['fenerAcik'] = find.text('Feneri kapat').evaluate().isNotEmpty;
      final dosya = '$cikti/kare_${(_sayac++).toString().padLeft(3, '0')}.png';
      final katman = t.binding.renderViews.first.debugLayer! as OffsetLayer;
      await t.runAsync(() async {
        // Kök katman zaten cihaz pikseline ölçekli; fiziksel boyutla al.
        final resim = await katman.toImage(
          Offset.zero & (_mantiksalBoyut * _dpr),
        );
        final veri = await resim.toByteData(format: ui.ImageByteFormat.png);
        File(dosya).writeAsBytesSync(veri!.buffer.asUint8List());
      });
      kare.dosya = dosya;
    }
    kareler.add(kare);
  }

  /// Test ortamı, yazı tipi belirtilmemiş metinleri kutu olarak çizer ve
  /// emoji çizemez. Bu metinlerin konumu, içeriği ve biçimi uygulamanın kendi
  /// çizim ağacından alınır; video hazırlanırken aynı yere Roboto ile yazılır.
  List<Map<String, Object?>> _yenidenCizilecekYazilar() {
    final liste = find.byType(ListView);
    final kirp = liste.evaluate().isEmpty ? null : t.getRect(liste.first);
    final sonuc = <Map<String, Object?>>[];
    for (final e in find.byType(RichText).evaluate()) {
      final ro = e.renderObject;
      if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
      final metin = ro.text.toPlainText();
      final stil = ro.text.style;
      if (stil?.fontFamily != null && !metin.contains('🎤')) continue;
      final ust = ro.localToGlobal(Offset.zero);
      sonuc.add({
        'x': ust.dx * _dpr,
        'y': ust.dy * _dpr,
        'w': ro.size.width * _dpr,
        'h': ro.size.height * _dpr,
        'metin': metin,
        'boyut': (stil?.fontSize ?? 14) * _dpr,
        'kalin': (stil?.fontWeight ?? FontWeight.w400).value >= 600,
        'renk': (stil?.color ?? Colors.black).toARGB32(),
        'kirp': kirp == null
            ? null
            : [
                kirp.left * _dpr,
                kirp.top * _dpr,
                kirp.right * _dpr,
                kirp.bottom * _dpr,
              ],
      });
    }
    return sonuc;
  }

  void yeniSahne(String baslik) {
    sahne = baslik;
    kareler.add(Kare('sahne', baslik, {}));
  }

  /// Uygulamayı çalıştırır: konuşursa görüntü alır, dinlerse sıradaki
  /// cevabı verir. Bir süre hiçbir şey olmazsa döner.
  Future<void> calis(List<String> cevaplar, {int sessizlikSiniri = 12}) async {
    var sessiz = 0;
    for (var adim = 0; adim < 2000; adim++) {
      await t.pump(const Duration(milliseconds: 50));
      if (bekleyenKonusma != null) {
        await kareAl('uygulama', bekleyenKonusmaMetni!);
        final c = bekleyenKonusma!;
        bekleyenKonusma = null;
        c.complete(1);
        sessiz = 0;
        continue;
      }
      if (bekleyenIzin != null) {
        final izin = izinler.length; // ilk istenen mikrofon, sonra kamera
        await kareAl(
          'kullanici',
          '(Android izin penceresinde “Uygulamayı kullanırken”e dokunur)',
          ekler: {'izinPenceresi': izin == 0 ? 'mikrofon' : 'kamera'},
        );
        final c = bekleyenIzin!;
        bekleyenIzin = null;
        c.complete(true);
        sessiz = 0;
        continue;
      }
      if (dinliyor && !dinlemeArayaGirme) {
        if (cevaplar.isEmpty) return;
        final cevap = cevaplar.removeAt(0);
        if (cevap.isEmpty) {
          await kareAl('kullanici', '(cevap vermez, kutuyu kameraya tutar)');
          await _sessizBitir();
        } else {
          await kareAl('kullanici', cevap);
          await _sonucGonder(cevap);
        }
        sessiz = 0;
        continue;
      }
      if (++sessiz >= sessizlikSiniri && cevaplar.isEmpty) return;
    }
    throw StateError(
      'Senaryo tamamlanamadı: sahne=$sahne dinliyor=$dinliyor '
      'arayaGirme=$dinlemeArayaGirme son=${kareler.isEmpty ? '' : kareler.last.metin}',
    );
  }

  Future<void> _sessizBitir() async {
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      stt.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('notifyStatus', 'doneNoResult'),
      ),
      (_) {},
    );
  }

  Future<void> _sonucGonder(String cevap) async {
    final m = t.binding.defaultBinaryMessenger;
    Future<void> gonder(String yontem, Object arg) => m.handlePlatformMessage(
      stt.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(yontem, arg)),
      (_) {},
    );
    await gonder(
      'textRecognition',
      jsonEncode({
        'alternates': [
          {'recognizedWords': cevap, 'confidence': 0.95},
        ],
        'resultType': 2,
      }),
    );
    await gonder('notifyStatus', 'done');
  }

  /// Kameranın önüne kod getirir (mobile_scanner olay kanalından).
  Future<void> kodGoster(
    String? deger, {
    required String kutu,
    List<double> konum = const [400, 800, 680, 1080],
  }) async {
    kamera = kutu;
    tarayiciOlaylari!.success({
      'name': 'barcode',
      'data': [
        {
          'rawValue': deger,
          'format': 16,
          'corners': [
            {'x': konum[0], 'y': konum[1]},
            {'x': konum[2], 'y': konum[1]},
            {'x': konum[2], 'y': konum[3]},
            {'x': konum[0], 'y': konum[3]},
          ],
        },
      ],
      'image': {'width': 1080.0, 'height': 1920.0},
    });
  }

  Future<void> bildirimeDokun(String yuk) async {
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      'dexterous.com/flutter/local_notifications',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', {
          'notificationId': 10,
          'payload': yuk,
          'notificationResponseType': 0,
        }),
      ),
      (_) {},
    );
  }

  Future<void> sesliKomutDugmesi() async {
    final dugme = find.text('Sesli komut ver');
    // Liste aşağı kaymış olabilir; düğme görünene kadar yukarı kaydır.
    await t.dragUntilVisible(
      dugme,
      find.byType(ListView),
      const Offset(0, 300),
    );
    await t.pump();
    await t.tap(dugme);
  }

  void kaydet(String ad) {
    File('$cikti/$ad.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'kameraAlani': _kameraAlani,
        'kareler': kareler.map((k) => k.json()).toList(),
      }),
    );
  }

  Map<String, double>? _kameraAlani;
  void kameraAlaniniBul() {
    final r = t.getRect(find.byType(MobileScanner));
    _kameraAlani = {
      'x': r.left * _dpr,
      'y': r.top * _dpr,
      'w': r.width * _dpr,
      'h': r.height * _dpr,
    };
  }
}

Future<void> yaziTipleriniYukle() async {
  const klasor = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final ad in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    roboto.addFont(
      Future.value(
        ByteData.sublistView(File('$klasor/$ad.ttf').readAsBytesSync()),
      ),
    );
  }
  await roboto.load();
  // Yazı tipi belirtmeyen metinler (ör. düğmeler) test ortamının varsayılan
  // (FlutterTest) ailesine düşer; onu da Roboto ile değiştir. Emoji için Noto Color Emoji.
  final varsayilan = FontLoader('FlutterTest');
  for (final ad in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    varsayilan.addFont(
      Future.value(
        ByteData.sublistView(File('$klasor/$ad.ttf').readAsBytesSync()),
      ),
    );
  }
  await varsayilan.load();
  const emoji = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
  if (File(emoji).existsSync()) {
    final e = FontLoader('Noto Color Emoji')
      ..addFont(
        Future.value(ByteData.sublistView(File(emoji).readAsBytesSync())),
      );
    await e.load();
  }
  final simgeler = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('$klasor/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await simgeler.load();
}

var hatirlatmaSaati = '09:00';
var hatirlatmaSozu = 'sabah dokuzda';

void main() {
  setUpAll(() async {
    Directory(cikti).createSync(recursive: true);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    await yaziTipleriniYukle();
  });

  testWidgets('demo senaryosu', (t) async {
    t.view.physicalSize = _mantiksalBoyut * _dpr;
    t.view.devicePixelRatio = _dpr;
    SharedPreferences.setMockInitialValues({});
    final d = Demo(t)..kur();

    // 1) Açılış ve sesli izinler
    d.yeniSahne('1. Açılış: izinler sesle anlatılır');
    await t.pumpWidget(const IlacAsistaniApp());
    await d.calis(['evet']);
    d.kameraAlaniniBul();

    // 2) Kod bulmaya yardım: bip
    d.yeniSahne('2. Kod görünüp okunamazsa bip sesleri');
    await d.kodGoster(
      null,
      kutu: 'coraspin_uzak',
      konum: const [60, 120, 200, 260],
    );
    await t.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    await d.kareAl(
      'bip',
      'Kod köşede ve uzakta: bipler yavaş',
      ekler: {'bipAraligi': 950},
    );
    await d.kodGoster(
      null,
      kutu: 'coraspin_yakin',
      konum: const [300, 700, 780, 1220],
    );
    await t.pump(const Duration(milliseconds: 300));
    await d.kareAl(
      'bip',
      'Kod ortada ve yakında: bipler hızlı',
      ekler: {'bipAraligi': 200},
    );

    // 3) Karekod okuma + hatırlatma kurma
    d.yeniSahne('3. Karekod okunur, ilacın adı söylenir, hatırlatma kurulur');
    await d.kodGoster(
      karekod('08699546130238', '270331', 'SN1'),
      kutu: 'coraspin_yakin',
    );
    // Uygulama "şu an civarı" hatırlatmalarda doğru ilaç kontrolü yaptığı
    // için, demo saati şu andan en az 3 saat uzak seçilir.
    const secenekler = {
      'her gün sabah dokuzda': 9,
      'her gün akşam dokuzda': 21,
      'her gün öğlen on ikide': 12,
      'her gün gece on birde': 23,
    };
    final simdi = DateTime.now().hour;
    final secilen = secenekler.entries.firstWhere((e) {
      final fark = (e.value - simdi).abs();
      return fark >= 3 && fark <= 21;
    });
    hatirlatmaSaati = '${secilen.value.toString().padLeft(2, '0')}:00';
    hatirlatmaSozu = secilen.key.replaceFirst('her gün ', '');
    await d.calis(['evet, ${secilen.key}', 'evet']);
    d.kamera = 'bos';

    // 4) Son kullanma tarihi yaklaşan ilaç
    d.yeniSahne('4. Son kullanma tarihi yaklaşan ilaç');
    final yakin = DateTime.now().add(const Duration(days: 19));
    final sktYakin =
        '${(yakin.year % 100).toString().padLeft(2, '0')}'
        '${yakin.month.toString().padLeft(2, '0')}'
        '${yakin.day.toString().padLeft(2, '0')}';
    await d.kodGoster(
      karekod('08699536090115', sktYakin, 'SN2'),
      kutu: 'majezik',
    );
    await d.calis(['hayır']);
    d.kamera = 'bos';

    // 5) Listede olmayan ilaç
    d.yeniSahne('5. İlaç listede yoksa');
    await d.kodGoster(
      karekod('08680000009999', '280630', 'SN3'),
      kutu: 'bilinmeyen',
    );
    await d.calis(['hayır']);
    d.kamera = 'bos';

    // 6) Sesli komutlar
    d.yeniSahne('6. Sesli komut: ajandamı oku');
    await d.sesliKomutDugmesi();
    await d.calis(['ajandamı oku']);
    d.yeniSahne('7. Sesli komut: feneri aç');
    await d.sesliKomutDugmesi();
    await d.calis(['feneri aç']);

    // 7) Bildirim ve doğru ilaç kontrolü
    d.yeniSahne('8. Hatırlatma saati: bildirime dokunulur');
    await d.kareAl(
      'bilgi',
      'Saat $hatirlatmaSaati olunca telefona bildirim gelir',
      ekler: {'bildirim': true, 'bildirimSaati': hatirlatmaSaati},
    );
    await d.bildirimeDokun('{"id":1}');
    await d.calis(['']);
    d.yeniSahne('9. Hatırlatma saatinde yanlış kutu okutulursa');
    await d.kodGoster(
      karekod('08699536090115', sktYakin, 'SN4'),
      kutu: 'majezik',
    );
    await d.calis([]);
    d.kamera = 'bos';
    d.yeniSahne('10. Doğru kutu okutulursa');
    await d.kodGoster(
      karekod('08699546130238', '270331', 'SN5'),
      kutu: 'coraspin_yakin',
    );
    await d.calis([]);
    d.kamera = 'bos';
    d.yeniSahne('11. Sesli komut: aldım');
    await d.sesliKomutDugmesi();
    await d.calis(['aldım']);

    // 8) Aldım mı?
    d.yeniSahne('12. "Bugün ilacımı aldım mı?"');
    await d.sesliKomutDugmesi();
    await d.calis(['bugün ilacımı aldım mı']);

    // 10) Kod bulunamazsa ipucu
    // Uygulama bu süreleri gerçek saatle ölçer; gerçekten beklenir.
    Future<void> konusanaKadarBekle() async {
      for (var i = 0; i < 45 && d.bekleyenKonusma == null; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await t.pump(const Duration(seconds: 1));
      }
    }

    d.yeniSahne('13. Karekod 10 saniye okunamazsa: kutunun yazısından tahmin');
    d.kamera = 'coraspin_on';
    d.ocrMetni =
        'CORASPIN®\n100 mg\n30 Enterik Kaplı Tablet\n'
        'Asetilsalisilik asit\nAğızdan kullanılır.';
    await d.kareAl(
      'bilgi',
      'Kutunun karekod olmayan ön yüzü kameraya tutulur; 10 saniye kod okunamaz',
    );
    await konusanaKadarBekle();
    await d.calis([]);
    d.ocrMetni = '';
    d.kamera = 'bos';

    d.yeniSahne('14. 15 saniye kod bulunamazsa ipucu');
    await konusanaKadarBekle();
    await d.calis([]);

    // 11) Bip kapatma ve silme
    d.yeniSahne('15. Sesli komut: bip sesini kapat');
    await d.sesliKomutDugmesi();
    await d.calis(['bip sesini kapat']);
    d.yeniSahne('16. Sesli komut: hatırlatmayı sil');
    await d.sesliKomutDugmesi();
    await d.calis(['${hatirlatmaSozu}ki hatırlatmayı sil', 'evet']);

    // 12) Türkçe ses yoksa: ses kaldırılıp uygulamaya geri dönülür; uygulama
    // dönüşte sesi yeniden denetler ve uyarıyı gösterir.
    d.yeniSahne('17. Telefonda Türkçe ses yüklü değilse');
    d.turkceSesVar = false;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(milliseconds: 200));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await d.calis([]);
    await t.dragUntilVisible(
      find.text('Türkçe ses yüklü değil'),
      find.byType(ListView),
      const Offset(0, 300),
    );
    await t.pump();
    await d.kareAl(
      'bilgi',
      'Ekranın en üstünde büyük uyarı ve “Ses ayarlarını aç” düğmesi çıkar. '
          'Açılışta uygulama şunu da söyler: “Telefonunuzda Türkçe ses paketi '
          'yüklü değil. Yüklemek için telefonun Ayarlar bölümünde Metin '
          'okuma, sonra Google, sonra Ses verilerini yükle, sonra Türkçe '
          'seçeneğine gidin.”',
    );

    d.kaydet('kareler');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(minutes: 2));
  });
}
