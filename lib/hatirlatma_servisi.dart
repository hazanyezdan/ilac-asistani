/// Günlük ilaç bildirimlerini kuran, iptal eden ve bildirim düğmelerini
/// ("Aldım", "Ertele") işleyen kod.
library;

import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzveri;
import 'package:timezone/timezone.dart' as tz;

import 'ajanda.dart';
import 'zamanlama.dart';

const String aldimEylemi = 'aldim';
const String erteleEylemi = 'ertele';

/// Her hatırlatma için bildirim numaraları: id*10 + tür.
const int _anaBildirim = 0;
const int _ertelemeBildirimi = 5;
int _bildirimNo(Hatirlatma h, int tur) => h.id * 10 + tur;

/// Bildirim düğmesine uygulama kapalıyken basılınca Android bu fonksiyonu
/// ayrı bir arka plan sürecinde çalıştırır.
@pragma('vm:entry-point')
Future<void> bildirimArkaPlanYaniti(NotificationResponse yanit) async {
  DartPluginRegistrant.ensureInitialized();
  HatirlatmaServisi.saatDilimiHazirla();
  final servis = HatirlatmaServisi();
  await servis.baslat();
  await servis.eylemIsle(yanit.actionId, yanit.payload);
}

class HatirlatmaServisi {
  HatirlatmaServisi({AjandaDeposu? depo}) : depo = depo ?? AjandaDeposu();

  final AjandaDeposu depo;
  final FlutterLocalNotificationsPlugin _eklenti =
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _eklenti
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static bool _saatDilimiHazir = false;

  /// Bildirim saatleri Türkiye saatine göre hesaplanır.
  static void saatDilimiHazirla() {
    if (_saatDilimiHazir) return;
    tzveri.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    _saatDilimiHazir = true;
  }

  static tz.TZDateTime get _simdi => tz.TZDateTime.now(tz.local);

  /// [bildirimeDokunuldu]: uygulama açıkken bildirime ya da düğmesine
  /// basılınca çağrılır.
  Future<void> baslat({
    void Function(NotificationResponse)? bildirimeDokunuldu,
  }) async {
    saatDilimiHazirla();
    await _eklenti.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_bildirim'),
      ),
      onDidReceiveNotificationResponse: bildirimeDokunuldu,
      onDidReceiveBackgroundNotificationResponse: bildirimArkaPlanYaniti,
    );
  }

  /// Uygulama bir bildirime dokunularak açıldıysa o bildirimin bilgisi.
  Future<NotificationResponse?> acilisBildirimi() async {
    final ayrinti = await _eklenti.getNotificationAppLaunchDetails();
    if (ayrinti == null || !ayrinti.didNotificationLaunchApp) return null;
    return ayrinti.notificationResponse;
  }

  // ---- İzinler ----

  Future<bool> bildirimIzniVarMi() async =>
      await _android?.areNotificationsEnabled() ?? false;

  /// Android 13+ bildirim izni penceresini açar.
  Future<bool> bildirimIzniIste() async =>
      await _android?.requestNotificationsPermission() ?? false;

  Future<bool> tamZamanliIzinVarMi() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  /// Android 12+ "Alarmlar ve hatırlatıcılar" ayar ekranını açar.
  Future<bool> tamZamanliIzinIste() async =>
      await _android?.requestExactAlarmsPermission() ?? false;

  // ---- Kurma / iptal ----

  Future<AndroidScheduleMode> _zamanlamaKipi() async =>
      await tamZamanliIzinVarMi()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  NotificationDetails _ayrinti() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'ilac_hatirlatma',
      'İlaç hatırlatmaları',
      channelDescription: 'Her gün ilaç alma zamanını hatırlatır.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      icon: 'ic_bildirim',
      enableVibration: true,
      playSound: true,
      actions: [
        AndroidNotificationAction(aldimEylemi, 'Aldım'),
        AndroidNotificationAction(erteleEylemi, 'Ertele (10 dakika)'),
      ],
    ),
  );

  static String _yuk(Hatirlatma h) => jsonEncode({'id': h.id});

  /// Bildirimden gelen yükten hatırlatma numarasını okur.
  static int? yuktenId(String? yuk) {
    if (yuk == null || yuk.isEmpty) return null;
    try {
      return (jsonDecode(yuk) as Map<String, dynamic>)['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  static String bildirimMetni(Hatirlatma h) {
    final ad = h.ilacAdi == null ? '' : ' (${h.ilacAdi})';
    return 'Saat ${h.saatYazisi}. İlacınızı alma zamanı.$ad';
  }

  /// Hatırlatmanın günlük bildirimini ve "aldım denmezse" tekrarlarını kurar.
  Future<void> kur(Hatirlatma h) async {
    final simdi = _simdi;
    final kip = await _zamanlamaKipi();
    final alindi = bugunYapildiMi(h.sonAlim, h, simdi);
    final ertelendi = bugunYapildiMi(h.sonErteleme, h, simdi);

    await _eklenti.zonedSchedule(
      id: _bildirimNo(h, _anaBildirim),
      title: 'İlaç zamanı',
      body: bildirimMetni(h),
      scheduledDate: sonrakiZaman(simdi, h.saat, h.dakika, bugunuAtla: alindi),
      notificationDetails: _ayrinti(),
      androidScheduleMode: kip,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _yuk(h),
    );
    for (var i = 0; i < tekrarDakikalari.length; i++) {
      final ek = tekrarDakikalari[i];
      await _eklenti.zonedSchedule(
        id: _bildirimNo(h, i + 1),
        title: 'İlacınızı aldınız mı?',
        body: '${bildirimMetni(h)} Aldıysanız "Aldım" düğmesine basın.',
        scheduledDate: sonrakiZaman(
          simdi,
          h.saat,
          h.dakika,
          ekDakika: ek,
          bugunuAtla: alindi || ertelendi,
        ),
        notificationDetails: _ayrinti(),
        androidScheduleMode: kip,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _yuk(h),
      );
    }
  }

  Future<void> iptal(Hatirlatma h) async {
    for (final tur in [
      _anaBildirim,
      for (var i = 1; i <= tekrarDakikalari.length; i++) i,
      _ertelemeBildirimi,
    ]) {
      await _eklenti.cancel(id: _bildirimNo(h, tur));
    }
  }

  /// Uygulama açılışında ajandadaki tüm hatırlatmaları yeniden kurar,
  /// ajandada olmayan eski bildirimleri temizler.
  Future<void> hepsiniYenidenKur(Ajanda ajanda) async {
    try {
      final bekleyenler = await _eklenti.pendingNotificationRequests();
      for (final b in bekleyenler) {
        if (ajanda.bul(b.id ~/ 10) == null) await _eklenti.cancel(id: b.id);
      }
      for (final h in ajanda.sirali) {
        await kur(h);
      }
    } catch (e) {
      debugPrint('Hatırlatmalar yeniden kurulamadı: $e');
    }
  }

  // ---- Aldım / Ertele ----

  /// "Aldım": kaydeder, bugünün bekleyen tekrarlarını iptal eder.
  Future<Hatirlatma?> aldim(int? hatirlatmaId) async {
    final simdi = DateTime.now();
    await depo.alimKaydet(simdi, hatirlatmaId: hatirlatmaId);
    if (hatirlatmaId == null) return null;
    final ajanda = await depo.yukle();
    final h = ajanda.bul(hatirlatmaId)?.kopyala(sonAlim: simdi);
    if (h == null) return null;
    ajanda.guncelle(h);
    await depo.kaydet(ajanda);
    await _eklenti.cancel(id: _bildirimNo(h, _ertelemeBildirimi));
    // Tekrarlar bugünü atlayacak şekilde yeniden kurulur.
    await kur(h);
    return h;
  }

  /// "Ertele": 10 dakika sonra yeniden hatırlatır; bugünün diğer
  /// tekrarlarını iptal eder ki bildirimler üst üste binmesin.
  Future<Hatirlatma?> ertele(int? hatirlatmaId) async {
    if (hatirlatmaId == null) return null;
    final ajanda = await depo.yukle();
    final simdi = DateTime.now();
    final h = ajanda.bul(hatirlatmaId)?.kopyala(sonErteleme: simdi);
    if (h == null) return null;
    ajanda.guncelle(h);
    await depo.kaydet(ajanda);
    await kur(h);
    await _eklenti.zonedSchedule(
      id: _bildirimNo(h, _ertelemeBildirimi),
      title: 'Ertelenen ilaç hatırlatması',
      body: bildirimMetni(h),
      scheduledDate: _simdi.add(const Duration(minutes: ertelemeDakikasi)),
      notificationDetails: _ayrinti(),
      androidScheduleMode: await _zamanlamaKipi(),
      payload: _yuk(h),
    );
    return h;
  }

  /// Bildirimdeki düğmeye basılınca çağrılır.
  Future<Hatirlatma?> eylemIsle(String? eylem, String? yuk) async {
    final id = yuktenId(yuk);
    switch (eylem) {
      case aldimEylemi:
        return aldim(id);
      case erteleEylemi:
        return ertele(id);
    }
    return null;
  }
}
