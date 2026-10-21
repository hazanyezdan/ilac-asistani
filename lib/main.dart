import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import 'karekod.dart';

void main() {
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

class TaramaEkrani extends StatefulWidget {
  const TaramaEkrani({super.key});

  @override
  State<TaramaEkrani> createState() => _TaramaEkraniState();
}

class _TaramaEkraniState extends State<TaramaEkrani> {
  /// Aynı kod bu süre içinde tekrar okunursa yeniden söylenmez.
  static const _tekrarBeklemeSuresi = Duration(seconds: 5);

  final MobileScannerController _kamera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final FlutterTts _tts = FlutterTts();

  String _durum = 'İlacın karekodunu kameraya tutun.';
  String? _sonKod;
  DateTime _sonOkumaZamani = DateTime.fromMillisecondsSinceEpoch(0);
  bool _konusuyor = false;
  bool _izinUyarisiSoylendi = false;

  @override
  void initState() {
    super.initState();
    unawaited(_sesiHazirla());
  }

  Future<void> _sesiHazirla() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    // speak() konuşma bitene kadar beklesin; böylece sözler üst üste binmez.
    await _tts.awaitSpeakCompletion(true);
    await _soyle('İlaç Asistanı hazır. $_durum');
  }

  Future<void> _soyle(String metin) async {
    _konusuyor = true;
    try {
      await _tts.stop();
      await _tts.speak(metin);
    } finally {
      _konusuyor = false;
    }
  }

  Future<void> _titret() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 300);
    }
  }

  Future<void> _kodOkundu(BarcodeCapture yakalama) async {
    if (_konusuyor || yakalama.barcodes.isEmpty) return;
    final ham = yakalama.barcodes.first.rawValue;
    if (ham == null || ham.isEmpty) return;

    final simdi = DateTime.now();
    if (ham == _sonKod &&
        simdi.difference(_sonOkumaZamani) < _tekrarBeklemeSuresi) {
      return;
    }
    _sonKod = ham;
    _sonOkumaZamani = simdi;

    final metin = sesliMetinHazirla(ham);
    setState(() => _durum = metin);
    unawaited(_titret());
    await _soyle(metin);
  }

  Future<void> _tekrarSoyle() async {
    await _soyle(_durum);
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    unawaited(_kamera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlaç Asistanı'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.yellow,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Kamera görüntüsü TalkBack için tek bir açıklama olarak okunur.
              child: Semantics(
                label:
                    'Kamera açık. İlacın karekodunu ya da barkodunu '
                    'telefonun arkasına doğru tutun.',
                image: true,
                child: ExcludeSemantics(
                  child: MobileScanner(
                    controller: _kamera,
                    onDetect: _kodOkundu,
                    errorBuilder: _hataEkrani,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _BuyukDugme(
                yazi: 'Tekrar söyle',
                ipucu: 'Son okunan bilgiyi yeniden sesli söyler',
                simge: Icons.volume_up,
                onPressed: _tekrarSoyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _kamera,
                builder: (context, durum, _) {
                  final acik = durum.torchState == TorchState.on;
                  return _BuyukDugme(
                    yazi: acik ? 'Feneri kapat' : 'Feneri aç',
                    ipucu:
                        'Karanlıkta okumayı kolaylaştırmak için '
                        'telefonun ışığını açar veya kapatır',
                    simge: acik ? Icons.flashlight_off : Icons.flashlight_on,
                    onPressed: durum.torchState == TorchState.unavailable
                        ? null
                        : () async {
                            await _kamera.toggleTorch();
                            await _soyle(
                              acik ? 'Fener kapandı' : 'Fener açıldı',
                            );
                          },
                  );
                },
              ),
            ),
          ],
        ),
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
      unawaited(_soyle(metin));
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
