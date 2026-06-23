import 'package:flutter/material.dart';

class PulseAvatar extends StatefulWidget {
  final bool isActive;
  final String label;
  const PulseAvatar({super.key, required this.isActive, required this.label});

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar> with TickerProviderStateMixin {
  late AnimationController _c1, _c2;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    if (widget.isActive) _start();
  }

  void _start() {
    _c1.repeat();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _c2.repeat();
    });
  }

  void _stop() { _c1.stop(); _c2.stop(); }

  @override
  void didUpdateWidget(PulseAvatar old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
    if (!widget.isActive && old.isActive) _stop();
  }

  @override
  void dispose() { _c1.dispose(); _c2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150, height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c2,
            builder: (_, __) => Transform.scale(
              scale: 0.95 + (_c2.value * 0.27),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(widget.isActive ? (1 - _c2.value) * 0.18 : 0),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c1,
            builder: (_, __) => Transform.scale(
              scale: 0.95 + (_c1.value * 0.17),
              child: Container(
                width: 106, height: 106,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(widget.isActive ? (1 - _c1.value) * 0.28 : 0),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 2),
                ),
                child: Center(
                  child: Text(widget.label,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ),
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: widget.isActive ? const Color(0xFF4ADE80) : const Color(0xFF666666),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF111111), width: 2.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
