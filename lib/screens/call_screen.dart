import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../models/reminder.dart';
import '../services/groq_service.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/wave_bars.dart';
import '../widgets/pulse_avatar.dart';

enum CallState { idle, listening, thinking, contactSpeaking, ended }

class CallScreen extends StatefulWidget {
  final Contact contact;
  final bool isIncoming;
  const CallScreen({super.key, required this.contact, this.isIncoming = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallState _state = CallState.idle;
  bool _muted = false;
  String _partialText = '';
  String _statusText = 'Ben is about to pick up...';
  List<Message> _messages = [];
  Reminder? _pendingReminder;
  Timer? _callTimer;
  int _callSeconds = 0;

  Contact get _c => widget.contact;

  Color get _accent {
    switch (_c.id) {
      case 1: return const Color(0xFF4ADE80);
      case 2: return const Color(0xFF60A5FA);
      case 3: return const Color(0xFFF472B6);
      case 4: return const Color(0xFFFB923C);
      default: return const Color(0xFFA78BFA);
    }
  }

  Color get _avatarBg {
    try { return Color(int.parse(_c.avatarColor.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF1C1C1C); }
  }

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    await SpeechService.init();
    final msgs = await DatabaseService.getRecentMessages(_c.id, limit: 10);
    setState(() => _messages = msgs);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
    await Future.delayed(const Duration(milliseconds: 800));
    final summary = await DatabaseService.getConversationSummary(_c.id);
    _contactSpeak(GroqService.buildGreeting(_c, 'Friend', summary));
  }

  String get _timerLabel {
    final m = _callSeconds ~/ 60;
    final s = _callSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _contactSpeak(String text) {
    _addMessage(Message(role: 'assistant', content: text));
    setState(() {
      _state = CallState.contactSpeaking;
      _statusText = '${_c.name} is talking...';
    });
    SpeechService.speak(text, onDone: () {
      if (mounted) {
        setState(() {
          _state = CallState.idle;
          _statusText = 'Tap mic to talk';
        });
      }
    });
  }

  Future<void> _startListening() async {
    if (_muted || _state == CallState.ended || _state == CallState.listening) return;
    await SpeechService.stopSpeaking();
    setState(() {
      _state = CallState.listening;
      _statusText = 'Listening...';
      _partialText = '';
    });
    await SpeechService.startListening(
      onPartial: (p) { if (mounted) setState(() => _partialText = p); },
      onResult: (text) {
        if (text.trim().isEmpty) {
          if (mounted) setState(() { _state = CallState.idle; _statusText = 'Tap mic to talk'; });
          return;
        }
        _handleUserMessage(text);
      },
    );
  }

  Future<void> _stopListening() async {
    if (_state == CallState.listening) await SpeechService.stopListening();
  }

  Future<void> _handleUserMessage(String text) async {
    setState(() {
      _state = CallState.thinking;
      _statusText = '${_c.name} is thinking...';
      _partialText = '';
    });
    _addMessage(Message(role: 'user', content: text));
    try {
      final summary = await DatabaseService.getConversationSummary(_c.id);
      final results = await Future.wait([
        GroqService.detectReminder(userMessage: text, conversationSummary: summary),
        GroqService.chat(contact: _c,
          history: _messages.take(_messages.length - 1).toList(),
          userMessage: text, userName: 'Friend', conversationSummary: summary),
      ]);
      final reminder = results[0] as Reminder?;
      final response = results[1] as BenResponse;
      if (reminder != null) {
        final id = await DatabaseService.saveReminder(reminder, _c.id);
        final saved = Reminder(id: id, task: reminder.task,
          scheduledAt: reminder.scheduledAt, lastConversationSummary: summary);
        await NotificationService.scheduleReminderCall(saved);
        if (mounted) {
          setState(() => _pendingReminder = saved);
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _pendingReminder = null);
          });
        }
      }
      _contactSpeak(response.text);
    } catch (e) {
      _contactSpeak("Sorry, lost you for a sec. Say that again?");
    }
  }

  void _addMessage(Message msg) {
    setState(() => _messages.add(msg));
    DatabaseService.saveMessage(msg, _c.id);
  }

  void _endCall() {
    _callTimer?.cancel();
    SpeechService.stopSpeaking();
    SpeechService.stopListening();
    setState(() { _state = CallState.ended; _statusText = 'Call ended'; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(children: [
        Positioned.fill(child: Center(child: Text(_c.initials,
          style: TextStyle(fontSize: 270, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.04))))),
        SafeArea(child: Column(children: [
          _statusBar(),
          Expanded(child: _center()),
          _transcript(),
          if (_pendingReminder != null) _reminderToast(),
          _controls(),
          const SizedBox(height: 28),
        ])),
      ]));
  }

  Widget _statusBar() {
    final now = DateTime.now();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${now.hour}:${now.minute.toString().padLeft(2,'0')}',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        const Row(children: [
          Icon(Icons.wifi, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Icon(Icons.battery_5_bar, color: Colors.white, size: 16),
        ]),
      ]));
  }

  Widget _center() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_c.specialty.toLowerCase(),
        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3), letterSpacing: 1.2)),
      const SizedBox(height: 20),
      PulseAvatar(
        isActive: _state == CallState.contactSpeaking || _state == CallState.listening,
        label: _c.initials, avatarColor: _avatarBg, accentColor: _accent),
      const SizedBox(height: 16),
      Text(_c.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.5)),
      const SizedBox(height: 5),
      Text(_statusText, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.45))),
      const SizedBox(height: 3),
      Text(_state == CallState.ended ? '—' : _timerLabel,
        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.22))),
      const SizedBox(height: 18),
      WaveBars(active: _state == CallState.contactSpeaking, accentColor: _accent),
      if (_partialText.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
          child: Text(_partialText, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic))),
    ]);
  }

  Widget _transcript() {
    final recent = _messages.length > 6 ? _messages.sublist(_messages.length - 6) : _messages;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: recent.isEmpty
          ? Center(child: Text('Conversation will appear here',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))))
          : ListView.separated(
              shrinkWrap: true, reverse: true, itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (_, i) {
                final msg = recent[recent.length - 1 - i];
                final isContact = msg.role == 'assistant';
                return Align(
                  alignment: isContact ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    constraints: const BoxConstraints(maxWidth: 230),
                    decoration: BoxDecoration(
                      color: isContact ? Colors.white.withOpacity(0.1) : const Color(0xFF1D4ED8),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isContact ? 4 : 14),
                        bottomRight: Radius.circular(isContact ? 14 : 4))),
                    child: Text(msg.content,
                      style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4))));
              }));
  }

  Widget _reminderToast() {
    final h = _pendingReminder!.scheduledAt.hour;
    final m = _pendingReminder!.scheduledAt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'pm' : 'am';
    final hour = h > 12 ? h - 12 : h;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        border: Border.all(color: _accent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text('Reminder set — ${_c.name} calls you at $hour:$m $period',
          style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4))),
      ]));
  }

  Widget _controls() {
    final isListening = _state == CallState.listening;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(children: [
        // Hint text
        Text(
          _state == CallState.idle ? 'Tap mic to speak' :
          _state == CallState.listening ? 'Listening... tap again to stop' :
          _state == CallState.thinking ? '${_c.name} is thinking...' :
          _state == CallState.contactSpeaking ? '${_c.name} is speaking...' : '',
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
        const SizedBox(height: 12),

        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Mute
          GestureDetector(onTap: () => setState(() => _muted = !_muted),
            child: Container(width: 52, height: 52,
              decoration: BoxDecoration(
                color: _muted ? const Color(0xFF3A1A1A) : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle),
              child: Icon(_muted ? Icons.mic_off : Icons.mic,
                color: _muted ? const Color(0xFFF87171) : Colors.white, size: 20))),

          // Main mic button — tap to start/stop
          GestureDetector(
            onTap: isListening ? _stopListening : _startListening,
            child: Container(width: 70, height: 70,
              decoration: BoxDecoration(
                color: _state == CallState.ended ? const Color(0xFF333333)
                    : isListening ? _accent.withOpacity(0.8) : _accent,
                shape: BoxShape.circle,
                boxShadow: isListening ? [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 16, spreadRadius: 2)] : null),
              child: Icon(
                isListening ? Icons.stop : Icons.mic,
                color: _state == CallState.ended ? Colors.white38 : const Color(0xFF0A1F13),
                size: 28))),

          // Speaker
          GestureDetector(onTap: () {},
            child: Container(width: 52, height: 52,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.volume_up, color: Colors.white, size: 20))),
        ]),
        const SizedBox(height: 18),

        // End call
        GestureDetector(onTap: _endCall,
          child: Container(width: 60, height: 60,
            decoration: BoxDecoration(
              color: _state == CallState.ended ? const Color(0xFF333333) : const Color(0xFFEF4444),
              shape: BoxShape.circle),
            child: const Icon(Icons.call_end, color: Colors.white, size: 26))),
      ]));
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    SpeechService.dispose();
    super.dispose();
  }
}
