import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  static final _stt = SpeechToText();
  static final _tts = FlutterTts();
  static bool _sttReady = false;
  static String _languageCode = 'en-US';

  static const supportedLanguages = <String, String>{
    'en-US': 'English',
    'fr-FR': 'Français',
    'es-ES': 'Español',
    'zh-CN': '中文',
    'de-DE': 'Deutsch',
    'sw-KE': 'Kiswahili',
  };

  static Future<void> init() async {
    _sttReady = await _stt.initialize(onError: (_) {});
    await _configureTts();
  }

  static Future<void> setLanguage(String languageCode) async {
    _languageCode = languageCode;
    await _tts.setLanguage(languageCode);
  }

  static String get languageCode => _languageCode;
  static bool get isAvailable => _sttReady;
  static bool get isListening => _stt.isListening;

  static Future<void> _configureTts({String voiceStyle = 'warm'}) async {
    await _tts.setLanguage(_languageCode);
    await _tts.setPitch(voiceStyle == 'bright' ? 1.08 : voiceStyle == 'deep' ? 0.78 : 0.92);
    await _tts.setSpeechRate(0.46);
    await _tts.setVolume(1.0);

    final voices = await _tts.getVoices;
    if (voices is List) {
      final matching = voices.where((v) {
        final locale = v['locale']?.toString() ?? '';
        return locale.toLowerCase().replaceAll('_', '-') == _languageCode.toLowerCase();
      }).toList();
      if (matching.isNotEmpty) {
        final selected = matching.firstWhere(
          (v) => v['name'].toString().toLowerCase().contains(voiceStyle),
          orElse: () => matching.first,
        );
        await _tts.setVoice({'name': selected['name'], 'locale': selected['locale']});
      }
    }
  }

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
        } else {
          onPartial?.call(result.recognizedWords);
        }
      },
      onSoundLevelChange: (_) {},
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 5),
      localeId: _languageCode.replaceAll('-', '_'),
      partialResults: true,
      cancelOnError: false,
    );
    // speech_to_text closes after the pauseFor silence window. Polling here
    // lets the call screen wait for the definitive notListening state.
    while (_stt.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    onDone?.call();
  }

  static Future<void> stopListening() async => await _stt.stop();

  static Future<void> speak(String text, {String voiceStyle = 'warm', Function()? onStart, Function()? onDone}) async {
    await _configureTts(voiceStyle: voiceStyle);
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
