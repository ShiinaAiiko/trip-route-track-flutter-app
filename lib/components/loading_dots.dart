import 'package:flutter/material.dart';

class LoadingDots extends StatefulWidget {
  final Brightness brightness;

  const LoadingDots({super.key, required this.brightness});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: -35).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    Future.delayed(const Duration(milliseconds: 0), () {
      if (mounted) {
        _isAnimating = true;
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BounceDot(
          color: Color(0xFFfeadbc),
          delay: Duration(milliseconds: 0),
        ),
        SizedBox(width: 16),
        _BounceDot(
          color: Color(0xFF09d1fe),
          delay: Duration(milliseconds: 200),
        ),
        SizedBox(width: 16),
        _BounceDot(
          color: Color(0xFF8552e4),
          delay: Duration(milliseconds: 400),
        ),
      ],
    );
  }
}

class _BounceDot extends StatefulWidget {
  final Color color;
  final Duration delay;

  const _BounceDot({
    required this.color,
    required this.delay,
  });

  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: -35).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _isAnimating = true;
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double offset = _isAnimating ? _animation.value : 0;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
