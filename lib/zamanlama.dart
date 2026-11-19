/// Bildirimlerin ne zaman çalacağını hesaplayan saf Dart kodu.
library;

import 'package:timezone/timezone.dart' as tz;

import 'ajanda.dart';

/// "Aldım" denmezse ana hatırlatmadan kaç dakika sonra tekrar hatırlatılır.
const List<int> tekrarDakikalari = [10, 20];

/// "Ertele" denince kaç dakika sonra tekrar hatırlatılır.
const int ertelemeDakikasi = 10;

/// Bugünkü hatırlatma zamanı (ek dakikasız).
tz.TZDateTime bugunkuZaman(tz.TZDateTime simdi, int saat, int dakika) =>
    tz.TZDateTime(
      simdi.location,
      simdi.year,
      simdi.month,
      simdi.day,
      saat,
      dakika,
    );

/// Bir sonraki çalma zamanı. Bugünkü zaman geçtiyse ya da [bugunuAtla]
/// doğruysa ertesi güne kayar.
tz.TZDateTime sonrakiZaman(
  tz.TZDateTime simdi,
  int saat,
  int dakika, {
  int ekDakika = 0,
  bool bugunuAtla = false,
}) {
  var zaman = bugunkuZaman(
    simdi,
    saat,
    dakika,
  ).add(Duration(minutes: ekDakika));
  if (bugunuAtla || !zaman.isAfter(simdi)) {
    zaman = zaman.add(const Duration(days: 1));
  }
  return zaman;
}

/// Verilen olay (aldım/ertele) bugünkü hatırlatma için mi yapılmış?
/// Hatırlatma saatinden en fazla 1 saat önce ya da sonrasında yapılan olay
/// bugünkü hatırlatmaya sayılır.
bool bugunYapildiMi(DateTime? olay, Hatirlatma h, tz.TZDateTime simdi) {
  if (olay == null) return false;
  final bugun = bugunkuZaman(simdi, h.saat, h.dakika);
  return olay.isAfter(bugun.subtract(const Duration(hours: 1)));
}
