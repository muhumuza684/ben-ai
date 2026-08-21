import 'package:flutter/material.dart';
import '../models/call_log.dart';
import '../models/contact.dart';
import '../services/database_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<CallLog> _logs = const [];
  Map<int, Contact> _contacts = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await DatabaseService.getCallLogs();
    final contacts = await DatabaseService.getContacts();
    if (mounted) setState(() { _logs = logs; _contacts = {for (final c in contacts) c.id: c}; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text('Recents'), backgroundColor: Colors.transparent),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80)))
          : _logs.isEmpty
              ? const Center(child: Text('Your simulated calls will appear here.', style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final log = _logs[index];
                      final contact = _contacts[log.contactId];
                      final missed = log.status == 'missed';
                      return Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(15)),
                        child: Row(children: [
                          CircleAvatar(backgroundColor: _color(contact), child: Text(contact?.initials ?? '?', style: const TextStyle(color: Colors.white))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(contact?.name ?? 'AI Friend', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('${log.direction == 'incoming' ? 'Incoming' : 'Outgoing'} · ${log.status}', style: TextStyle(color: missed ? const Color(0xFFF87171) : Colors.white54, fontSize: 11)),
                          ])),
                          Text(_time(log.startedAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }

  String _time(DateTime time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  Color _color(Contact? contact) {
    if (contact == null) return const Color(0xFF4ADE80);
    try { return Color(int.parse(contact.avatarColor.replaceFirst('#', '0xFF'))); } catch (_) { return const Color(0xFF1C1C1C); }
  }
}
