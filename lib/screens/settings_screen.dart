import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  final List<Contact> contacts;
  const SettingsScreen({super.key, required this.contacts});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<Contact> _contacts;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.contacts);
  }

  void _editContact(Contact contact) {
    final nameCtrl = TextEditingController(text: contact.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Color(int.parse(contact.avatarColor.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(contact.initials,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit friend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                    Text(contact.specialty, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Name', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Enter name',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            Text('Specialty (read only)', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(contact.specialty,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final newName = nameCtrl.text.trim();
                  if (newName.isEmpty) return;
                  contact.name = newName;
                  await DatabaseService.updateContact(contact);
                  setState(() {
                    final idx = _contacts.indexWhere((c) => c.id == contact.id);
                    if (idx >= 0) _contacts[idx] = contact;
                  });
                  if (mounted) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Save',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0A1F13))),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _accentColor(int id) {
    switch (id) {
      case 1: return const Color(0xFF4ADE80);
      case 2: return const Color(0xFF60A5FA);
      case 3: return const Color(0xFFF472B6);
      case 4: return const Color(0xFFFB923C);
      default: return const Color(0xFF4ADE80);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your friends', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white)),
                      Text('Tap to customize name & voice', style: TextStyle(fontSize: 12, color: Color(0x66FFFFFF))),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _contacts.length,
                itemBuilder: (_, i) {
                  final c = _contacts[i];
                  final accent = _accentColor(c.id);
                  Color avatarColor;
                  try {
                    avatarColor = Color(int.parse(c.avatarColor.replaceFirst('#', '0xFF')));
                  } catch (_) {
                    avatarColor = const Color(0xFF1C1C1C);
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                          child: Center(child: Text(c.initials,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(c.specialty,
                                  style: TextStyle(fontSize: 11, color: accent.withOpacity(0.8))),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _editContact(c),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Built by BrytMa Tech Uganda',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2))),
            ),
          ],
        ),
      ),
    );
  }
}
