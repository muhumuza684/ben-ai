import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import 'call_screen.dart';

class IncomingScreen extends StatefulWidget {
  final Contact contact;
  const IncomingScreen({super.key, required this.contact});

  @override
  State<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends State<IncomingScreen>
    with TickerProviderStateMixin {
  late AnimationController _ring1, _ring2;
  Timer? _missedTimer;

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _ring2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ring2.repeat();
    });

    // Auto dismiss after 30 seconds if not answered
    _missedTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _accept() async {
    _missedTimer?.cancel();
    await DatabaseService.updateLastCalled(widget.contact.id);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(contact: widget.contact, isIncoming: true),
      ),
    );
  }

  void _decline() {
    _missedTimer?.cancel();
    Navigator.pop(context);
  }

  Color get _accentColor {
    switch (widget.contact.id) {
      case 1: return const Color(0xFF4ADE80);
      case 2: return const Color(0xFF60A5FA);
      case 3: return const Color(0xFFF472B6);
      case 4: return const Color(0xFFFB923C);
      default: return const Color(0xFF4ADE80);
    }
  }

  Color get _avatarColor {
    try {
      return Color(int.parse(widget.contact.avatarColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1C1C1C);
    }
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _missedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          // Faded background letter
          Positioned.fill(
            child: Center(
              child: Text(
                widget.contact.initials,
                style: TextStyle(
                  fontSize: 280,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Incoming tag
                Text('INCOMING CALL',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                    letterSpacing: 2,
                  )),
                const SizedBox(height: 40),

                // Pulsing avatar
                SizedBox(
                  width: 160, height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(_ring2, 150),
                      _ring(_ring1, 124),
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(color: _avatarColor, shape: BoxShape.circle),
                        child: Center(
                          child: Text(widget.contact.initials,
                            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w500, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(widget.contact.name,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('AI Friend · Calling...',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.45))),
                const SizedBox(height: 12),

                // Specialty badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(widget.contact.specialty,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                ),

                const Spacer(),

                // Accept / Decline buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _decline,
                            child: Container(
                              width: 64, height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Decline',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                        ],
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _accept,
                            child: Container(
                              width: 64, height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call, color: Colors.white, size: 26),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Accept',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(AnimationController ctrl, double size) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Transform.scale(
        scale: 0.9 + (ctrl.value * 0.12),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity((1 - ctrl.value) * 0.2),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
