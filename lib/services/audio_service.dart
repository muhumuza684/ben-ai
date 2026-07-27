import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentlyPlaying;

  static bool get isRecording => _isRecording;
  static bool get isPlaying => _isPlaying;
  static String? get currentlyPlaying => _currentlyPlaying;

  static Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  static Future<String?> startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return null;
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = path.join(dir.path, filename);
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: filePath,
      );
      _isRecording = true;
      return filePath;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      final filePath = await _recorder.stop();
      _isRecording = false;
      return filePath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  static Future<void> playAudio(String filePath, {Function()? onComplete}) async {
    try {
      if (_isPlaying) await stopAudio();
      _isPlaying = true;
      _currentlyPlaying = filePath;
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentlyPlaying = null;
        onComplete?.call();
      });
      await _player.play(DeviceFileSource(filePath));
    } catch (e) {
      _isPlaying = false;
    }
  }

  static Future<void> stopAudio() async {
    await _player.stop();
    _isPlaying = false;
    _currentlyPlaying = null;
  }

  static Future<String> saveTtsAsFile(String text) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'ai_vn_${DateTime.now().millisecondsSinceEpoch}.txt';
    final filePath = path.join(dir.path, filename);
    await File(filePath).writeAsString(text);
    return filePath;
  }

  static Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}