import 'dart:io';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/simulated_call_service.dart';
import 'outgoing_screen.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'call_history_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  int _tab = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await DatabaseService.getContacts();
    setState(() => _contacts = contacts);
  }

  void _callContact(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingScreen(contact: contact),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _searchBar(),
            Expanded(child: _contactList()),
            _tabBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Friends',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.5)),
              Text('${_contacts.length} AI companions',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
            ],
          ),
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddContactScreen(onAdded: _load))).then((_) => _load()),
              child: Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.person_add_alt_1, color: Color(0xFF4ADE80), size: 19)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(contacts: _contacts))).then((_) => _load()),
              child: Icon(Icons.settings_outlined, color: Colors.white.withOpacity(0.3), size: 22),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white.withOpacity(0.25), size: 16),
          const SizedBox(width: 8),
          Expanded(child: TextField(onChanged: (value) => setState(() => _query = value), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Search friends...', hintStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3)), border: InputBorder.none, isDense: true))),
        ],
      ),
    );
  }

  Widget _contactList() {
    if (_contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
    }
    final visible = _contacts.where((c) => _query.trim().isEmpty || c.name.toLowerCase().contains(_query.toLowerCase()) || c.specialty.toLowerCase().contains(_query.toLowerCase())).toList();
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => Divider(height: 0, color: Colors.white.withOpacity(0.06), indent: 16, endIndent: 16),
      itemBuilder: (_, i) => _contactTile(visible[i]),
    );
  }

  Future<void> _scheduleCall(Contact contact) async {
    final today = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: today, lastDate: today.add(const Duration(days: 365)), initialDate: today, builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF4ADE80))), child: child!));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now(), builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF4ADE80))), child: child!));
    if (time == null || !mounted) return;
    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a future time for the call')));
      return;
    }
    final reminder = Reminder(contactId: contact.id, task: 'A scheduled check-in with ${contact.name}', scheduledAt: scheduledAt);
    final id = await DatabaseService.saveReminder(reminder, contact.id);
    final saved = Reminder(id: id, contactId: contact.id, task: reminder.task, scheduledAt: scheduledAt);
    SimulatedCallService.schedule(saved, contact);
    await NotificationService.scheduleReminderCall(saved);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${contact.name} will call at ${time.format(context)}')));
  }

  void _openContactActions(Contact contact) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(contact.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4), const Text('Choose how you want to connect', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: _actionCard(Icons.call_outlined, 'Call', () { Navigator.pop(context); _callContact(contact); })),
        const SizedBox(width: 8),
        Expanded(child: _actionCard(Icons.chat_bubble_outline, 'Chat', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(contact: contact))); })),
        const SizedBox(width: 8),
        Expanded(child: _actionCard(Icons.schedule_outlined, 'Schedule', () { Navigator.pop(context); _scheduleCall(contact); })),
      ]),
    ]))));
  }

  Widget _actionCard(IconData icon, String label, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))), child: Column(children: [Icon(icon, color: const Color(0xFF4ADE80), size: 26), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))])));

  Widget _contactTile(Contact contact) {
    final accent = _accentColor(contact.id);
    return InkWell(
      onTap: () => _openContactActions(contact),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: _parseColor(contact.avatarColor),
                    shape: BoxShape.circle,
                  ),
                  child: contact.photoPath != null ? ClipOval(child: Image.file(File(contact.photoPath!), fit: BoxFit.cover)) : Center(child: Text(contact.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white))),
                ),
                Positioned(
                  bottom: 1, right: 1,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F0F0F), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(contact.specialty,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                  const SizedBox(height: 2),
                  Text(contact.lastCalledLabel,
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.22))),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _openContactActions(contact),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Icon(Icons.call, color: accent, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = [
      (Icons.people_outline, 'Friends'),
      (Icons.access_time_outlined, 'Recents'),
      (Icons.settings_outlined, 'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _tab = i);
                if (i == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CallHistoryScreen()),
                  );
                } else if (i == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen(contacts: _contacts)),
                  ).then((_) => _load());
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabs[i].$1,
                      size: 22,
                      color: active ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 3),
                    Text(tabs[i].$2,
                      style: TextStyle(
                        fontSize: 10,
                        color: active ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.3),
                      )),
                  ],
                ),
              ),
            ),
          );
        }),
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

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1C1C1C);
    }
  }
}
