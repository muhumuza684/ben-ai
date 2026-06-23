import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  static final _stt = SpeechToText();
  static final _tts = FlutterTts();
  static bool _sttReady = false;

  static Future<void> init() async {
    _sttReady = await _stt.initialize(onError: (e) => print('STT: $e'));

    await _tts.setLanguage('en-US');
    await _tts.setPitch(0.9);
    await _tts.setSpeechRate(0.50);
    await _tts.setVolume(1.0);

    // Try to pick a male voice
    final voices = await _tts.getVoices;
    if (voices != null) {
      final list = voices as List;
      final male = list.firstWhere(
        (v) =>
            v['name'].toString().toLowerCase().contains('male') &&
            v['locale'].toString().startsWith('en'),
        orElse: () => null,
      );
      if (male != null) {
        await _tts.setVoice({'name': male['name'], 'locale': male['locale']});
      }
    }
  }

  static bool get isAvailable => _sttReady;
  static bool get isListening => _stt.isListening;

  static Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartial,
    Function()? onDone,
  }) async {
    if (!_sttReady) return;
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onDone?.call();
        } else {
          onPartial?.call(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      partialResults: true,
      cancelOnError: false,
    );
  }

  static Future<void> stopListening() async => await _stt.stop();

  static Future<void> speak(
    String text, {
    Function()? onStart,
    Function()? onDone,
  }) async {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onDone?.call());
    await _tts.speak(text);
  }

  static Future<void> stopSpeaking() async => await _tts.stop();

  static Future<void> dispose() async {
    await _stt.cancel();
    await _tts.stop();
  }
}
