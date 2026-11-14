import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do visitante guardadas no aparelho.
abstract final class Settings {
  static const _offersKey = 'offers_on_the_way';

  /// Se a bússola deve avisar sobre promoções de lojas no caminho. Começa
  /// desligado: o aviso só aparece para quem escolher receber.
  static Future<bool> offersOnTheWay() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getBool(_offersKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setOffersOnTheWay(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_offersKey, enabled);
    } catch (_) {
      // Sem armazenamento, a escolha vale só enquanto a tela estiver aberta.
    }
  }
}
