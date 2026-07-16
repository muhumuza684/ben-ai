import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import 'call_screen.dart';

class OutgoingScreen extends StatefulWidget {
  final Contact contact;
  const OutgoingScreen({super.key, required this.contact});

  @override
  State<OutgoingScreen> createState() => _OutgoingScreenState();
}

class _OutgoingScreenState extends State<OutgoingScreen>
    with TickerProviderStateMixin {
  late AnimationController _ring1, _ring2, _ring3;
  Timer? _pickupTimer;
  int _dots = 0;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _ring2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _ring3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ring2.forward(from: 0.33);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _ring3.forward(from: 0.66);
    });

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });

    // Contact "picks up" after 2-4 seconds
    _pickupTimer = Timer(const Duration(seconds: 3), _pickUp);
  }

  void _pickUp() async {
    await DatabaseService.updateLastCalled(widget.contact.id);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(contact: widget.contact),
      ),
    );
  }

  void _cancel() {
    _pickupTimer?.cancel();
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
    _ring3.dispose();
    _pickupTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dots;
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
                  fontSize: 260,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Status bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_timeLabel(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      const Row(children: [
                        Icon(Icons.wifi, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Icon(Icons.battery_5_bar, color: Colors.white, size: 16),
                      ]),
                    ],
                  ),
                ),

                const Spacer(),

                // Tag
                Text('calling$dots',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35), letterSpacing: 1.2)),
                const SizedBox(height: 28),

                // Pulsing avatar
                SizedBox(
                  width: 180, height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(_ring3, 170),
                      _ring(_ring2, 140),
                      _ring(_ring1, 110),
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(color: _avatarColor, shape: BoxShape.circle),
                        child: Center(
                          child: Text(widget.contact.initials,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(widget.contact.name,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(widget.contact.specialty,
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),

                const Spacer(),

                // End call button
                Column(
                  children: [
                    GestureDetector(
                      onTap: _cancel,
                      child: Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Cancel',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
                  ],
                ),
                const SizedBox(height: 48),
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
        scale: 0.9 + (ctrl.value * 0.15),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _accentColor.withOpacity((1 - ctrl.value) * 0.25),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}
