import 'package:flutter/material.dart';

/// Animated dots widget that cycles through ".", "..", "..."
/// Used to indicate loading state for enriching markets
class LoadingDots extends StatefulWidget {
  final Color? color;
  final double fontSize;
  
  const LoadingDots({
    Key? key,
    this.color,
    this.fontSize = 12,
  }) : super(key: key);

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.color ?? Colors.grey;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final dotsCount = _animation.value;
        String dots = '.' * dotsCount;
        if (dots.isEmpty) dots = ' '; // Show space to maintain height
        
        return Text(
          dots,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: textColor,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
