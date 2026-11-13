import 'package:flutter_tts/flutter_tts.dart';

/// Fala as instruções da bússola em voz alta, para o visitante andar sem
/// olhar para a tela. Se o aparelho não tiver voz, as chamadas não fazem nada.
abstract final class Voice {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> say(String text) async {
    try {
      if (!_ready) {
        await _tts.setLanguage('pt-BR');
        await _tts.setSpeechRate(0.5);
        _ready = true;
      }

      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Sem motor de voz neste aparelho: a tela e a vibração continuam valendo.
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nada a interromper.
    }
  }
}
