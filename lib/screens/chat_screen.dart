import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/chat_message.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/groq_service.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final msgs = await DatabaseService.getChatMessages(_c.id);
    await DatabaseService.markAllRead(_c.id);
    setState(() => _messages = msgs);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
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
    await _getAiReply(text);
  }

  Future<void> _getAiReply(String userText) async {
    setState(() => _isTyping = true);
    _scrollToBottom();
    try {
      final summary = await DatabaseService.getConversationSummary(_c.id);
      final history = _messages.where((m) => m.type == 'text')
        .map((m) => Message(role: m.isMe ? 'user' : 'assistant', content: m.text ?? '')).toList();
      final response = await GroqService.chat(contact: _c, history: history,
        userMessage: userText, userName: 'Friend', conversationSummary: summary);
      final aiMsg = ChatMessage(contactId: _c.id, type: 'text', text: response.text, isMe: false);
      final id = await DatabaseService.saveChatMessage(aiMsg);
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(id: id, contactId: _c.id, type: 'text', text: response.text, isMe: false));
      });
      _scrollToBottom();
    } catch (e) { setState(() => _isTyping = false); }
  }

  Future<void> _startRecording() async {
    final ok = await AudioService.hasPermission();
    if (!ok) return;
    await AudioService.startRecording();
    setState(() { _isRecording = true; _recordSeconds = 0; });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await AudioService.stopRecording();
    setState(() => _isRecording = false);
    if (path == null || _recordSeconds < 1) return;
    final duration = _recordSeconds;
    final userMsg = ChatMessage(contactId: _c.id, type: 'voice', audioPath: path, audioDuration: duration, isMe: true);
    final id = await DatabaseService.saveChatMessage(userMsg);
    setState(() => _messages.add(ChatMessage(id: id, contactId: _c.id, type: 'voice', audioPath: path, audioDuration: duration, isMe: true)));
    _scrollToBottom();
    await _getAiVoiceReply();
  }

  Future<void> _getAiVoiceReply() async {
    setState(() => _isTyping = true);
    try {
      final summary = await DatabaseService.getConversationSummary(_c.id);
      final response = await GroqService.chat(contact: _c, history: [],
        userMessage: '[User sent a voice note]', userName: 'Friend', conversationSummary: summary);
      final aiMsg = ChatMessage(contactId: _c.id, type: 'voice',
        audioDuration: (response.text.length / 15).round(), isMe: false, text: response.text);
      final id = await DatabaseService.saveChatMessage(aiMsg);
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(id: id, contactId: _c.id, type: 'voice',
          audioDuration: aiMsg.audioDuration, isMe: false, text: response.text));
      });
      _scrollToBottom();
    } catch (e) { setState(() => _isTyping = false); }
  }

  Future<void> _playVoice(ChatMessage msg) async {
    if (msg.isMe && msg.audioPath != null) {
      await AudioService.playAudio(msg.audioPath!);
    } else if (!msg.isMe && msg.text != null) {
      await SpeechService.init();
      await SpeechService.speak(msg.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.5), size: 20)),
        const SizedBox(width: 10),
        Container(width: 38, height: 38, decoration: BoxDecoration(color: _avatarBg, shape: BoxShape.circle),
          child: Center(child: Text(_c.initials, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
          Text('online', style: TextStyle(fontSize: 11, color: _accent)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (msg.type == 'text')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            constraints: const BoxConstraints(maxWidth: 230),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF1D4ED8) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16))),
            child: Text(msg.text ?? '', style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4)))
        else
          GestureDetector(onTap: () => _playVoice(msg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1D4ED8) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 16)),
                const SizedBox(width: 10),
                Row(children: List.generate(14, (i) => Container(width: 2.5,
                  height: (4 + (i % 5) * 3).toDouble(), margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(2))))),
                const SizedBox(width: 10),
                Text('${msg.audioDuration ?? 0}s', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
              ]))),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          Text(msg.timeLabel, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.25))),
          if (isMe) ...[const SizedBox(width: 4), Icon(Icons.done_all, size: 13, color: _accent)],
        ]),
      ]),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: _avatarBg, shape: BoxShape.circle),
          child: Center(child: Text(_c.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16),
              bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
            Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), shape: BoxShape.circle))))),
      ]),
    );
  }

  Widget _inputBar() {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text('Recording... $_recordSeconds s', style: const TextStyle(fontSize: 14, color: Colors.white)),
          const Spacer(),
          GestureDetector(onTap: _stopRecording,
            child: Container(width: 40, height: 40,
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
              child: const Icon(Icons.stop, color: Colors.white, size: 18))),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: TextField(controller: _textCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(hintText: 'Message ${_c.name}...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
              isDense: true, border: InputBorder.none),
            onSubmitted: (_) => _sendText()))),
        const SizedBox(width: 8),
        ValueListenableBuilder(valueListenable: _textCtrl, builder: (_, value, __) {
          if (value.text.isNotEmpty) {
            return GestureDetector(onTap: _sendText,
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Color(0xFF0A1F13), size: 18)));
          }
          return GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Color(0xFF0A1F13), size: 18)));
        }),
      ]),
    );
  }

  @override
  void dispose() { _textCtrl.dispose(); _scrollCtrl.dispose(); _recordTimer?.cancel(); super.dispose(); }
}