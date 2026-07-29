import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static String? _currentlyPlaying;

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
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = path.join(dir.path, filename);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      _isRecording = true;
      return filePath;
    } catch (e) {
      debugPrint('Recording error: $e');
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

  /// Save TTS text as a marker file — used to identify AI voice note bubbles
  static Future<String> saveAiVoiceNote(String text) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'ai_${DateTime.now().millisecondsSinceEpoch}.tts';
    final filePath = path.join(dir.path, filename);
    await File(filePath).writeAsString(text);
    return filePath;
  }

  /// Read TTS text from AI voice note file
  static Future<String?> readAiVoiceNote(String filePath) async {
    try {
      return await File(filePath).readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
