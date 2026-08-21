import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/contact.dart';
import '../services/database_service.dart';

class AddContactScreen extends StatefulWidget {
  final VoidCallback? onAdded;
  const AddContactScreen({super.key, this.onAdded});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  int _selectedPersonality = 0;
  int _selectedColor = 0;
  String _languageCode = 'en-US';
  String _voiceStyle = 'Warm companion';
  String? _photoPath;

  final _personalities = const [
    {'name': 'General friend', 'desc': 'Casual, warm, talks about anything', 'color': Color(0xFF4ADE80)},
    {'name': 'Motivator', 'desc': 'Hype, goals, accountability', 'color': Color(0xFF60A5FA)},
    {'name': 'Listener', 'desc': 'Empathetic, supportive, caring', 'color': Color(0xFFF472B6)},
    {'name': 'Fun and sassy', 'desc': 'Jokes, gossip, entertainment', 'color': Color(0xFFFB923C)},
  ];

  static const _languages = <String, String>{
    'en-US': 'English', 'fr-FR': 'Français', 'es-ES': 'Español',
    'zh-CN': '中文', 'de-DE': 'Deutsch', 'sw-KE': 'Kiswahili',
  };

  static const _voices = [
    'Warm companion', 'Bright and playful', 'Calm and deep', 'Soft storyteller',
    'Energetic friend', 'Gentle listener', 'Confident guide', 'Cheerful comedian',
    'Low and soothing', 'Clear professional', 'Soulful and expressive', 'Melodic and light',
  ];

  final _avatarColors = const ['#1e3a2e', '#1e2a3a', '#3a1e2e', '#3a2a1e', '#2a1e3a', '#1e3a3a', '#3a1e1e', '#2a3a1e'];

  String _buildPrompt(String name, int i, String details) {
    final type = _personalities[i]['name'];
    return 'You are $name, a $type AI companion. ${_personalities[i]['desc']}. ${details.trim()} Talk naturally, remember context, give practical solutions, keep spoken replies concise, and never use bullet points on a call. Be transparent that you are an AI when directly asked.';
  }

  Future<void> _choosePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked != null && mounted) setState(() => _photoPath = picked.path);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your friend a name first')));
      return;
    }
    final existing = await DatabaseService.getContacts();
    final newId = existing.isEmpty ? 1 : existing.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
    final contact = Contact(
      id: newId,
      name: name,
      specialty: _personalities[_selectedPersonality]['name'] as String,
      gender: 'neutral',
      avatarColor: _avatarColors[_selectedColor],
      photoPath: _photoPath,
      languageCode: _languageCode,
      voiceStyle: _voiceStyle.toLowerCase().replaceAll(' ', '_'),
      systemPrompt: _buildPrompt(name, _selectedPersonality, _detailsCtrl.text),
    );
    await DatabaseService.addContact(contact);
    widget.onAdded?.call();
    if (mounted) Navigator.pop(context);
  }

  Color get _selectedAvatar => Color(int.parse(_avatarColors[_selectedColor].replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    final initial = _nameCtrl.text.isEmpty ? '?' : _nameCtrl.text[0].toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 19)),
            const SizedBox(width: 4),
            const Text('Create a friend', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          const SizedBox(height: 20),
          Center(child: GestureDetector(onTap: _choosePhoto, child: Stack(children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: _selectedAvatar,
              backgroundImage: _photoPath == null ? null : FileImage(File(_photoPath!)),
              child: _photoPath == null ? Text(initial, style: const TextStyle(fontSize: 34, color: Colors.white)) : null,
            ),
            Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle), child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF08150D), size: 17))),
          ]))),
          const SizedBox(height: 8),
          Center(child: Text('Add a profile photo', style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 12))),
          const SizedBox(height: 22),
          _label('Name'),
          _field(_nameCtrl, 'What should Ben call them?', onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          _label('About this friend'),
          _field(_detailsCtrl, 'Interests, memories, or how they help you', maxLines: 3),
          const SizedBox(height: 16),
          _label('Conversation language'),
          _dropdown<String>(_languageCode, _languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), (v) => setState(() => _languageCode = v!)),
          const SizedBox(height: 16),
          _label('Voice character'),
          _dropdown<String>(_voiceStyle, _voices.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), (v) => setState(() => _voiceStyle = v!)),
          const SizedBox(height: 20),
          _label('Personality'),
          ...List.generate(_personalities.length, (i) {
            final p = _personalities[i];
            final selected = _selectedPersonality == i;
            final color = p['color'] as Color;
            return GestureDetector(onTap: () => setState(() => _selectedPersonality = i), child: Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: selected ? color.withOpacity(0.10) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? color : Colors.white.withOpacity(0.08))),
              child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text(p['desc'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12))])), if (selected) Icon(Icons.check_circle, color: color, size: 18)]),
            ));
          }),
          const SizedBox(height: 16),
          _label('Avatar color'),
          Wrap(spacing: 10, children: List.generate(_avatarColors.length, (i) { final color = Color(int.parse(_avatarColors[i].replaceFirst('#', '0xFF'))); return GestureDetector(onTap: () => setState(() => _selectedColor = i), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: _selectedColor == i ? Border.all(color: Colors.white, width: 2) : null))); })),
          const SizedBox(height: 26),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), foregroundColor: const Color(0xFF0A1F13), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Create friend', style: TextStyle(fontWeight: FontWeight.w700)))),
        ]),
      )),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)));

  Widget _field(TextEditingController controller, String hint, {int maxLines = 1, ValueChanged<String>? onChanged}) => TextField(controller: controller, onChanged: onChanged, maxLines: maxLines, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)), filled: true, fillColor: Colors.white.withOpacity(0.07), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(15)));

  Widget _dropdown<T>(T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => DropdownButtonFormField<T>(value: value, items: items, onChanged: onChanged, dropdownColor: const Color(0xFF252525), style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(filled: true, fillColor: Colors.white.withOpacity(0.07), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3)));

  @override
  void dispose() { _nameCtrl.dispose(); _detailsCtrl.dispose(); super.dispose(); }
}
