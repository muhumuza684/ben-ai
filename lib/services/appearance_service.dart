import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceService {
  static String background = 'midnight';

  static const options = <String, String>{
    'midnight': 'Midnight',
    'forest': 'Forest glow',
    'ocean': 'Deep ocean',
    'plum': 'Soft plum',
  };

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    background = prefs.getString('conversation_background') ?? 'midnight';
  }

  static Future<void> setBackground(String value) async {
    background = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversation_background', value);
  }

  static Color get color {
    switch (background) {
      case 'forest': return const Color(0xFF0B1B16);
      case 'ocean': return const Color(0xFF0B1422);
      case 'plum': return const Color(0xFF1A101D);
      default: return const Color(0xFF0F0F0F);
    }
  }
}
