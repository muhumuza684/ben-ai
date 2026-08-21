import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/chat_message.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/groq_service.dart';
import '../services/web_search_service.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../services/appearance_service.dart';
import 'outgoing_screen.dart';

class ChatScreen extends StatefulWidget {
  final Contact contact;
  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Set<String> _playingPaths = {};

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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final msgs = await DatabaseService.getChatMessages(_c.id);
    await DatabaseService.markAllRead(_c.id);
    if (mounted) setState(() => _messages = msgs);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();

    final userMsg = ChatMessage(contactId: _c.id, type: 'text', text: text, isMe: true);
    final id = await DatabaseService.saveChatMessage(userMsg);
    setState(() => _messages.add(ChatMessage(id: id, contactId: _c.id, type: 'text', text: text, isMe: true)));
    _scrollToBottom();
    await _getTextReply(text);
  }

  Future<void> _getTextReply(String userText) async {
    setState(() => _isTyping = true);
    _scrollToBottom();
    try {
      final normalized = userText.trim();
      if (normalized.toLowerCase().startsWith('search ') || normalized.toLowerCase().startsWith('/search ')) {
        final query = normalized.replaceFirst(RegExp(r'^/?search\s+', caseSensitive: false), '');
        final results = await WebSearchService.search(query);
        final text = results.isEmpty ? 'I could not find a clear result for "$query".' : results.take(3).map((r) => '${r.title}: ${r.snippet}').join('\n\n');
        final aiMsg = ChatMessage(contactId: _c.id, type: 'text', text: text, isMe: false);
        final id = await DatabaseService.saveChatMessage(aiMsg);
        if (mounted) setState(() { _isTyping = false; _messages.add(ChatMessage(id: id, contactId: _c.id, type: 'text', text: text, isMe: false)); });
        _scrollToBottom();
        return;
      }
      final summary = await DatabaseService.getConversationSummary(_c.id);
      final history = _messages
          .where((m) => m.type == 'text')
          .map((m) => Message(role: m.isMe ? 'user' : 'assistant', content: m.text ?? ''))
          .toList();
      final response = await GroqService.chat(
        contact: _c, history: history,
        userMessage: userText, userName: 'Friend',
        conversationSummary: summary,
      );
      final aiMsg = ChatMessage(contactId: _c.id, type: 'text', text: response.text, isMe: false);
      final id = await DatabaseService.saveChatMessage(aiMsg);
      if (mounted) setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(id: id, contactId: _c.id, type: 'text', text: response.text, isMe: false));
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _startRecording() async {
    final path = await AudioService.startRecording();
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission needed')));
      return;
    }
    setState(() { _isRecording = true; _recordSeconds = 0; });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await AudioService.stopRecording();
    if (mounted) setState(() => _isRecording = false);
    if (path == null || _recordSeconds < 1) return;

    final duration = _recordSeconds;
    final userMsg = ChatMessage(
      contactId: _c.id, type: 'voice',
      audioPath: path, audioDuration: duration, isMe: true,
    );
    final id = await DatabaseService.saveChatMessage(userMsg);
    setState(() => _messages.add(ChatMessage(
      id: id, contactId: _c.id, type: 'voice',
      audioPath: path, audioDuration: duration, isMe: true)));
    _scrollToBottom();
    await _getVoiceReply();
  }

  Future<void> _getVoiceReply() async {
    setState(() => _isTyping = true);
    try {
      final summary = await DatabaseService.getConversationSummary(_c.id);
      final response = await GroqService.chat(
        contact: _c, history: [],
        userMessage: '[User sent a voice note. Reply naturally as if you heard them speak.]',
        userName: 'Friend', conversationSummary: summary,
      );

      // Save AI reply as TTS voice note file
      final ttsPath = await AudioService.saveAiVoiceNote(response.text);
      final duration = (response.text.split(' ').length / 2.5).round();

      final aiMsg = ChatMessage(
        contactId: _c.id, type: 'voice',
        audioPath: ttsPath, audioDuration: duration,
        isMe: false, text: response.text,
      );
      final id = await DatabaseService.saveChatMessage(aiMsg);
      if (mounted) setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: id, contactId: _c.id, type: 'voice',
          audioPath: ttsPath, audioDuration: duration,
          isMe: false, text: response.text));
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _playVoice(ChatMessage msg) async {
    if (msg.isMe && msg.audioPath != null) {
      // Play real recorded audio
      setState(() => _playingPaths.add(msg.audioPath!));
      await AudioService.playFile(msg.audioPath!, onComplete: () {
        if (mounted) setState(() => _playingPaths.remove(msg.audioPath));
      });
    } else if (!msg.isMe) {
      // Play AI voice note via TTS
      if (msg.audioPath != null) setState(() => _playingPaths.add(msg.audioPath!));
      final text = msg.text ?? await AudioService.readAiVoiceNote(msg.audioPath ?? '');
      if (text != null) {
        await SpeechService.init();
        await SpeechService.speak(text, onDone: () {
          if (mounted && msg.audioPath != null) setState(() => _playingPaths.remove(msg.audioPath));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppearanceService.color,
      body: SafeArea(child: Column(children: [
        _header(),
        Expanded(child: _messageList()),
        if (_isTyping) _typingIndicator(),
        _inputBar(),
      ])),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.5), size: 20)),
        const SizedBox(width: 10),
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: _avatarBg, shape: BoxShape.circle),
          child: Center(child: Text(_c.initials,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
          Row(children: [
            Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
            Text('online', style: TextStyle(fontSize: 11, color: _accent)),
          ]),
        ])),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OutgoingScreen(contact: _c))),
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.phone_outlined, color: Colors.white.withOpacity(0.6), size: 17))),
      ]),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(ChatMessage msg) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (msg.type == 'text')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              constraints: const BoxConstraints(maxWidth: 240),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1D4ED8) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18))),
              child: Text(msg.text ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.45)))
          else
            _voiceBubble(msg),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(msg.timeLabel,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.25))),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 13, color: _accent),
              ],
            ]),
        ]),
    );
  }

  Widget _voiceBubble(ChatMessage msg) {
    final isMe = msg.isMe;
    final isPlaying = msg.audioPath != null && _playingPaths.contains(msg.audioPath);
    return GestureDetector(
      onTap: () => _playVoice(msg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1D4ED8) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              color: isPlaying ? _accent : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: isPlaying ? const Color(0xFF0A1F13) : Colors.white,
              size: 17)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: List.generate(18, (i) => Container(
              width: 2, height: (4 + (i % 6) * 2.5).toDouble(),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isPlaying
                    ? _accent.withOpacity(0.8)
                    : Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2))))),
            const SizedBox(height: 4),
            Text('${msg.audioDuration ?? 0}s',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
          ]),
        ])),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(color: _avatarBg, shape: BoxShape.circle),
          child: Center(child: Text(_c.initials,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4))),
          child: Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => _TypingDot(delay: i * 200)))),
      ]),
    );
  }

  Widget _inputBar() {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
        child: Row(children: [
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text('Recording... ${_recordSeconds}s',
            style: const TextStyle(fontSize: 14, color: Colors.white)),
          const Spacer(),
          GestureDetector(onTap: _stopRecording,
            child: Container(width: 42, height: 42,
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
              child: const Icon(Icons.stop, color: Colors.white, size: 20))),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Message ${_c.name}...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
              isDense: true, border: InputBorder.none),
            onSubmitted: (_) => _sendText()))),
        const SizedBox(width: 8),
        ValueListenableBuilder(valueListenable: _textCtrl, builder: (_, val, __) {
          if (val.text.isNotEmpty) {
            return GestureDetector(onTap: _sendText,
              child: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Color(0xFF0A1F13), size: 19)));
          }
          return GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(width: 42, height: 42,
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Color(0xFF0A1F13), size: 20)));
        }),
      ]),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _anim, builder: (_, __) =>
      Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3 + _anim.value * 0.5),
          shape: BoxShape.circle)));
  }
}
