import 'package:flutter/material.dart';
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
  int _selectedPersonality = 0;
  int _selectedColor = 0;

  final List<Map<String, dynamic>> _personalities = [
    {'name': 'General friend', 'desc': 'Casual, warm, talks about anything', 'color': const Color(0xFF4ADE80)},
    {'name': 'Motivator', 'desc': 'Hype, goals, accountability', 'color': const Color(0xFF60A5FA)},
    {'name': 'Listener', 'desc': 'Empathetic, supportive, caring', 'color': const Color(0xFFF472B6)},
    {'name': 'Fun and sassy', 'desc': 'Jokes, gossip, entertainment', 'color': const Color(0xFFFB923C)},
  ];

  final List<String> _avatarColors = [
    '#1e3a2e', '#1e2a3a', '#3a1e2e', '#3a2a1e',
    '#2a1e3a', '#1e3a3a', '#3a1e1e', '#2a3a1e',
  ];

  String _buildPrompt(String name, int i) {
    switch (i) {
      case 0: return 'You are $name, a casual AI friend. Talk like a real friend — warm, funny, direct. Keep replies short. Never say you are an AI unless asked.';
      case 1: return 'You are $name, a motivational AI friend. Energetic and push people toward goals. Keep replies short. Never say you are an AI unless asked.';
      case 2: return 'You are $name, an empathetic AI friend. Listen deeply and make people feel heard. Keep replies short. Never say you are an AI unless asked.';
      case 3: return 'You are $name, a fun and sassy AI friend. Funny, playful, love gossip. Keep replies short. Never say you are an AI unless asked.';
      default: return 'You are $name, a friendly AI companion. Keep replies short and natural.';
    }
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
    final existing = await DatabaseService.getContacts();
    final newId = existing.isEmpty ? 5 : (existing.map((c) => c.id).reduce((a, b) => a > b ? a : b)) + 1;
    final contact = Contact(
      id: newId, name: name,
      specialty: _personalities[_selectedPersonality]['name'],
      gender: _selectedPersonality <= 1 ? 'male' : 'female',
      avatarColor: _avatarColors[_selectedColor],
      systemPrompt: _buildPrompt(name, _selectedPersonality),
    );
    await DatabaseService.addContact(contact);
    widget.onAdded?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Color(int.parse(_avatarColors[_selectedColor].replaceFirst('#', '0xFF')));
    final initial = _nameCtrl.text.isEmpty ? 'J' : _nameCtrl.text[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.5), size: 20)),
            const SizedBox(width: 12),
            const Text('New contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white)),
          ]),
          const SizedBox(height: 24),

          Center(child: Column(children: [
            Container(width: 76, height: 76,
              decoration: BoxDecoration(color: selectedColor, shape: BoxShape.circle),
              child: Center(child: Text(initial,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white)))),
            const SizedBox(height: 10),
            const Text('Choose avatar color', style: TextStyle(fontSize: 12, color: Color(0xFF4ADE80))),
          ])),
          const SizedBox(height: 14),

          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
            children: List.generate(_avatarColors.length, (i) {
              final col = Color(int.parse(_avatarColors[i].replaceFirst('#', '0xFF')));
              return GestureDetector(onTap: () => setState(() => _selectedColor = i),
                child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: col, shape: BoxShape.circle,
                    border: _selectedColor == i ? Border.all(color: Colors.white, width: 2) : null)));
            })),
          const SizedBox(height: 24),

          Text('Name', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 8),
          TextField(controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'Enter name',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
              filled: true, fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
          const SizedBox(height: 20),

          Text('Personality', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 8),
          ...List.generate(_personalities.length, (i) {
            final p = _personalities[i];
            final selected = _selectedPersonality == i;
            return GestureDetector(onTap: () => setState(() => _selectedPersonality = i),
              child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? (p['color'] as Color).withOpacity(0.08) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? p['color'] as Color : Colors.white.withOpacity(0.08))),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: p['color'] as Color, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(p['desc'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                  ])),
                  if (selected) Icon(Icons.check_circle, color: p['color'] as Color, size: 18),
                ])));
          }),
          const SizedBox(height: 24),

          GestureDetector(onTap: _save,
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFF4ADE80), borderRadius: BorderRadius.circular(14)),
              child: const Text('Add contact', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0A1F13))))),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }
}