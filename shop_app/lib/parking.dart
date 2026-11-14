import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Vaga onde o visitante deixou o carro.
class ParkingSpot {
  const ParkingSpot({
    required this.latitude,
    required this.longitude,
    required this.savedAt,
    required this.fromGps,
    this.note = '',
  });

  final double latitude;
  final double longitude;
  final DateTime savedAt;

  /// Falso quando a vaga foi marcada sem GPS, na posição de demonstração.
  final bool fromGps;

  /// Anotação livre do visitante, como "G2, vaga B14".
  final String note;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'saved_at': savedAt.toIso8601String(),
        'from_gps': fromGps,
        'note': note,
      };

  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    return ParkingSpot(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      savedAt: DateTime.parse(json['saved_at'] as String),
      fromGps: json['from_gps'] as bool? ?? false,
      note: json['note'] as String? ?? '',
    );
  }
}

/// Guarda a vaga no próprio aparelho, para ela continuar lá se o app fechar.
abstract final class ParkingStorage {
  static const _key = 'parking_spot';

  static Future<ParkingSpot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);

      return raw == null
          ? null
          : ParkingSpot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(ParkingSpot spot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(spot.toJson()));
    } catch (_) {
      // Sem armazenamento, a vaga vale só enquanto a tela estiver aberta.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Nada a apagar.
    }
  }
}

/// Tempo de estacionamento por extenso: "agora há pouco", "há 25 min",
/// "há 1 h 20 min".
String parkedFor(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  if (minutes < 1) {
    return 'agora há pouco';
  }
  if (minutes < 60) {
    return 'há $minutes min';
  }

  final rest = minutes % 60;

  return rest == 0 ? 'há ${minutes ~/ 60} h' : 'há ${minutes ~/ 60} h $rest min';
}

/// Limite, em horas, da tarifa única do estacionamento do shopping.
const int parkingFlatRateHours = 3;
