/// Kullanıcı ayarlarının telefonda saklanması (shared_preferences).
library;

import 'package:shared_preferences/shared_preferences.dart';

class AyarDeposu {
  static const _bipAnahtari = 'bip_acik';

  /// Bip sesiyle yönlendirme açık mı? Varsayılan: açık.
  Future<bool> bipAcikMi() async =>
      (await SharedPreferences.getInstance()).getBool(_bipAnahtari) ?? true;

  Future<void> bipAyarla(bool acik) async =>
      (await SharedPreferences.getInstance()).setBool(_bipAnahtari, acik);
}
