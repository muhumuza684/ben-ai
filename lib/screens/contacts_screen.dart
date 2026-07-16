import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import 'outgoing_screen.dart';
import 'settings_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  int _tab = 0;

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
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(contacts: _contacts)),
            ).then((_) => _load()),
            child: Icon(Icons.settings_outlined, color: Colors.white.withOpacity(0.3), size: 22),
          ),
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
          Text('Search friends...', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _contactList() {
    if (_contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
    }
    return ListView.separated(
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => Divider(height: 0, color: Colors.white.withOpacity(0.06), indent: 16, endIndent: 16),
      itemBuilder: (_, i) => _contactTile(_contacts[i]),
    );
  }

  Widget _contactTile(Contact contact) {
    final accent = _accentColor(contact.id);
    return InkWell(
      onTap: () => _callContact(contact),
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
                  child: Center(
                    child: Text(contact.initials,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
                  ),
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
              onTap: () => _callContact(contact),
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
                if (i == 2) {
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
