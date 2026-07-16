import 'package:flutter/material.dart';

class WaveBars extends StatefulWidget {
  final bool active;
  final Color accentColor;
  const WaveBars({super.key, required this.active, this.accentColor = const Color(0xFF4ADE80)});

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<WaveBars> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(9, (i) => AnimationController(
      vsync: this, duration: Duration(milliseconds: 500 + (i * 70))));
    if (widget.active) _startAll();
  }

  void _startAll() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 55), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  void _stopAll() { for (final c in _controllers) c.animateTo(0); }

  @override
  void didUpdateWidget(WaveBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _startAll();
    if (!widget.active && old.active) _stopAll();
  }

  @override
  void dispose() { for (final c in _controllers) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(9, (i) => AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) {
            final h = widget.active ? 4.0 + (_controllers[i].value * 20) : 4.0;
            final o = widget.active ? 0.3 + (_controllers[i].value * 0.7) : 0.2;
            return Container(
              width: 3, height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(o),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        )),
      ),
    );
  }
}
