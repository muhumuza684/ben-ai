import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  static FlutterSoundRecorder? _recorder;
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static String? _currentlyPlaying;
  static String? _currentRecordingPath;

  static bool get isRecording => _isRecording;
  static String? get currentlyPlaying => _currentlyPlaying;

  static Future<bool> requestPermissions() async {
    final mic = await Permission.microphone.request();
    return mic.isGranted;
  }

  static Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  static Future<String?> startRecording() async {
    try {
      final granted = await requestPermissions();
      if (!granted) return null;
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'vn_${DateTime.now().millisecondsSinceEpoch}.aac';
      final filePath = path.join(dir.path, filename);
      await _recorder!.startRecorder(toFile: filePath, codec: Codec.aacADTS);
      _isRecording = true;
      _currentRecordingPath = filePath;
      return filePath;
    } catch (e) {
      debugPrint('Recording error: $e');
      return null;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      await _recorder?.stopRecorder();
      await _recorder?.closeRecorder();
      _recorder = null;
      _isRecording = false;
      return _currentRecordingPath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  static Future<void> playFile(String filePath, {Function()? onComplete}) async {
    try {
      await _player.stop();
      _currentlyPlaying = filePath;
      _player.onPlayerComplete.listen((_) {
        _currentlyPlaying = null;
        onComplete?.call();
      });
      await _player.play(DeviceFileSource(filePath));
    } catch (e) {
      debugPrint('Playback error: $e');
      _currentlyPlaying = null;
    }
  }

  static Future<void> stopPlaying() async {
    await _player.stop();
    _currentlyPlaying = null;
  }

  static Future<String> saveAiVoiceNote(String text) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'ai_${DateTime.now().millisecondsSinceEpoch}.tts';
    final filePath = path.join(dir.path, filename);
    await File(filePath).writeAsString(text);
    return filePath;
  }

  static Future<String?> readAiVoiceNote(String filePath) async {
    try { return await File(filePath).readAsString(); }
    catch (_) { return null; }
  }

  static Future<void> dispose() async {
    await _recorder?.closeRecorder();
    await _player.dispose();
  }
}