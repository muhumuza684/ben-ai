import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/chat_message.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';
import 'add_contact_screen.dart';
import '../screens/settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Contact> _contacts = [];
  Map<int, ChatMessage?> _lastMessages = {};
  Map<int, int> _unreadCounts = {};
  int _tab = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final contacts = await DatabaseService.getContacts();
    final Map<int, ChatMessage?> last = {};
    final Map<int, int> unread = {};
    for (final c in contacts) {
      last[c.id] = await DatabaseService.getLastChatMessage(c.id);
      unread[c.id] = await DatabaseService.getUnreadCount(c.id);
    }
    if (mounted) setState(() { _contacts = contacts; _lastMessages = last; _unreadCounts = unread; });
  }

  Color _accentColor(int id) {
    switch (id) {
      case 1: return const Color(0xFF4ADE80);
      case 2: return const Color(0xFF60A5FA);
      case 3: return const Color(0xFFF472B6);
      case 4: return const Color(0xFFFB923C);
      default: return const Color(0xFFA78BFA);
    }
  }

  Color _avatarColor(Contact c) {
    try { return Color(int.parse(c.avatarColor.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF1C1C1C); }
  }

  String _previewText(ChatMessage? msg) {
    if (msg == null) return 'Start a conversation';
    if (msg.type == 'voice') return 'Voice note · ${msg.audioDuration ?? 0}s';
    return msg.text ?? '';
  }

  String _timeLabel(ChatMessage? msg) {
    if (msg == null) return '';
    final diff = DateTime.now().difference(msg.timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'yst';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(child: Column(children: [
        _header(),
        _searchBar(),
        Expanded(child: _list()),
        _tabBar(),
      ])),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.5), size: 20)),
          const SizedBox(width: 10),
          const Text('Chats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
        ]),
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => AddContactScreen(onAdded: _load))),
          child: Container(width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Color(0xFF0A1F13), size: 20)),
        ),
      ]),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Icon(Icons.search, color: Colors.white.withOpacity(0.25), size: 16),
        const SizedBox(width: 8),
        Text('Search', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3))),
      ]),
    );
  }

  Widget _list() {
    if (_contacts.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.chat_bubble_outline, color: Colors.white.withOpacity(0.2), size: 48),
        const SizedBox(height: 12),
        Text('No contacts yet', style: TextStyle(color: Colors.white.withOpacity(0.4))),
      ]));
    }
    return ListView.separated(
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => Divider(height: 0, color: Colors.white.withOpacity(0.05), indent: 74),
      itemBuilder: (_, i) => _tile(_contacts[i]),
    );
  }

  Widget _tile(Contact contact) {
    final accent = _accentColor(contact.id);
    final lastMsg = _lastMessages[contact.id];
    final unread = _unreadCounts[contact.id] ?? 0;
    return InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(contact: contact))).then((_) => _load()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Stack(children: [
            Container(width: 50, height: 50,
              decoration: BoxDecoration(color: _avatarColor(contact), shape: BoxShape.circle),
              child: Center(child: Text(contact.initials,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)))),
            Positioned(bottom: 1, right: 1, child: Container(width: 12, height: 12,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F0F0F), width: 2)))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
            const SizedBox(height: 2),
            Row(children: [
              if (lastMsg?.type == 'voice') ...[
                Icon(Icons.mic, size: 12, color: Colors.white.withOpacity(0.35)),
                const SizedBox(width: 3),
              ],
              Expanded(child: Text(_previewText(lastMsg),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.38)),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_timeLabel(lastMsg), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
            const SizedBox(height: 4),
            if (unread > 0)
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF4ADE80), borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0A1F13)))),
          ]),
        ]),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = [(Icons.chat_bubble_outline, 'Chats'), (Icons.phone_outlined, 'Voice'), (Icons.settings_outlined, 'Settings')];
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Row(children: List.generate(tabs.length, (i) {
        final active = _tab == i;
        return Expanded(child: GestureDetector(
          onTap: () {
            setState(() => _tab = i);
            if (i == 2) Navigator.push(context,
              MaterialPageRoute(builder: (_) => SettingsScreen(contacts: _contacts))).then((_) => _load());
          },
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(tabs[i].$1, size: 22, color: active ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.3)),
              const SizedBox(height: 3),
              Text(tabs[i].$2, style: TextStyle(fontSize: 10,
                color: active ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.3))),
            ]))));
      })),
    );
  }
}