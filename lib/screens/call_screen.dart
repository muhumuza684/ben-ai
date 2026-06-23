import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/reminder.dart';
import '../services/groq_service.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/wave_bars.dart';
import '../widgets/pulse_avatar.dart';

enum CallState { idle, listening, thinking, benSpeaking, ended }

class CallScreen extends StatefulWidget {
  final String userName;
  final Reminder? incomingReminder;

  const CallScreen({super.key, required this.userName, this.incomingReminder});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallState _state = CallState.idle;
  bool _muted = false;
  bool _speakerOn = true;
  String _partialText = '';
  String _statusText = 'Tap mic to talk';
  List<Message> _messages = [];
  Reminder? _pendingReminder;
  Timer? _callTimer;
  int _callSeconds = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await SpeechService.init();
    final msgs = await DatabaseService.getRecentMessages(limit: 10);
    setState(() => _messages = msgs);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (widget.incomingReminder != null) {
      _benSpeak("Yo ${widget.userName}! Just reminding you — ${widget.incomingReminder!.task}. Don't sleep on it!");
    } else {
      _benSpeak("Yo ${widget.userName}! You called. What's good?");
    }
  }

  String get _timerLabel {
    final m = _callSeconds ~/ 60;
    final s = _callSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _benSpeak(String text) {
    _addMessage(Message(role: 'assistant', content: text));
    setState(() {
      _state = CallState.benSpeaking;
      _statusText = 'Ben is talking...';
    });
    SpeechService.speak(text, onDone: () {
      if (mounted) setState(() {
        _state = CallState.idle;
        _statusText = 'Tap mic to talk';
      });
    });
  }

  Future<void> _startListening() async {
    if (_muted || _state == CallState.ended) return;
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
          setState(() { _state = CallState.idle; _statusText = 'Tap mic to talk'; });
          return;
        }
        _handleUserMessage(text);
      },
    );
  }

  Future<void> _stopListening() async {
    await SpeechService.stopListening();
  }

  Future<void> _handleUserMessage(String text) async {
    setState(() {
      _state = CallState.thinking;
      _statusText = 'Ben is thinking...';
      _partialText = '';
    });
    _addMessage(Message(role: 'user', content: text));

    try {
      final summary = await DatabaseService.getConversationSummary();

      final results = await Future.wait([
        GroqService.detectReminder(userMessage: text, conversationSummary: summary),
        GroqService.chat(
          history: _messages.take(_messages.length - 1).toList(),
          userMessage: text,
          userName: widget.userName,
          conversationSummary: summary,
        ),
      ]);

      final reminder = results[0] as Reminder?;
      final benResponse = results[1] as BenResponse;

      if (reminder != null) {
        final id = await DatabaseService.saveReminder(reminder);
        final saved = Reminder(
          id: id,
          task: reminder.task,
          scheduledAt: reminder.scheduledAt,
          lastConversationSummary: summary,
        );
        await NotificationService.scheduleReminderCall(saved);
        if (mounted) {
          setState(() => _pendingReminder = saved);
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _pendingReminder = null);
          });
        }
      }

      _benSpeak(benResponse.text);
    } catch (e) {
      _benSpeak("Sorry, lost you for a sec. Say that again?");
    }
  }

  void _addMessage(Message msg) {
    setState(() => _messages.add(msg));
    DatabaseService.saveMessage(msg);
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
      body: Stack(
        children: [
          // Faded B background
          Positioned.fill(
            child: Center(
              child: Text('B', style: TextStyle(
                fontSize: 280,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.04),
              )),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _statusBar(),
                Expanded(child: _center()),
                _transcript(),
                if (_pendingReminder != null) _reminderToast(),
                _controls(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    final now = DateTime.now();
    final t = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          const Row(children: [
            Icon(Icons.wifi, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Icon(Icons.battery_5_bar, color: Colors.white, size: 16),
          ]),
        ],
      ),
    );
  }

  Widget _center() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('ben · ai friend', style: TextStyle(
          fontSize: 11, color: Colors.white.withOpacity(0.35), letterSpacing: 1.2)),
        const SizedBox(height: 24),

        PulseAvatar(
          isActive: _state == CallState.benSpeaking || _state == CallState.listening,
          label: 'B',
        ),

        const SizedBox(height: 18),
        const Text('Ben', style: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(_statusText, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
        const SizedBox(height: 4),
        Text(_state == CallState.ended ? '—' : _timerLabel,
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.25))),
        const SizedBox(height: 22),

        WaveBars(active: _state == CallState.benSpeaking),

        if (_partialText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
            child: Text(_partialText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.55), fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _transcript() {
    final recent = _messages.length > 6 ? _messages.sublist(_messages.length - 6) : _messages;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxHeight: 148),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        reverse: true,
        itemCount: recent.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final msg = recent[recent.length - 1 - i];
          final isBen = msg.role == 'assistant';
          return Align(
            alignment: isBen ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 240),
              decoration: BoxDecoration(
                color: isBen ? Colors.white.withOpacity(0.1) : const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isBen ? 4 : 14),
                  bottomRight: Radius.circular(isBen ? 14 : 4),
                ),
              ),
              child: Text(msg.content,
                style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
            ),
          );
        },
      ),
    );
  }

  Widget _reminderToast() {
    final h = _pendingReminder!.scheduledAt.hour;
    final m = _pendingReminder!.scheduledAt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'pm' : 'am';
    final hour = h > 12 ? h - 12 : h;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80).withOpacity(0.12),
        border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reminder set — Ben calls you at $hour:$m $period',
              style: const TextStyle(fontSize: 12, color: Color(0xFFBBF7D0), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // Label row
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('mute', style: TextStyle(fontSize: 10, color: Color(0x55FFFFFF))),
                Text('end', style: TextStyle(fontSize: 10, color: Color(0x55FFFFFF))),
                Text('speaker', style: TextStyle(fontSize: 10, color: Color(0x55FFFFFF))),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mute
              _iconBtn(
                icon: _muted ? Icons.mic_off : Icons.mic,
                bg: _muted ? const Color(0xFF3A1A1A) : Colors.white.withOpacity(0.1),
                iconColor: _muted ? const Color(0xFFF87171) : Colors.white,
                size: 54,
                onTap: () => setState(() => _muted = !_muted),
              ),

              // Mic (hold to talk)
              GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp: (_) => _stopListening(),
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: _state == CallState.ended
                        ? const Color(0xFF333333)
                        : _state == CallState.listening
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Color(0xFF0A1F13), size: 28),
                ),
              ),

              // Speaker
              _iconBtn(
                icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                bg: _speakerOn ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.1),
                iconColor: Colors.white,
                size: 54,
                onTap: () => setState(() => _speakerOn = !_speakerOn),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // End call
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: _state == CallState.ended ? const Color(0xFF333333) : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    SpeechService.dispose();
    super.dispose();
  }
}
