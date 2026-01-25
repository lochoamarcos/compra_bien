import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Version 1: SVG Asset
class BrandIconSvg extends StatelessWidget {
  final double size;
  const BrandIconSvg({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icon_v1.svg',
      width: size,
      height: size,
    );
  }
}

// Version 2: CustomPainter
class BrandIconPainter extends StatelessWidget {
  final double size;
  const BrandIconPainter({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _IconPainter(),
    );
  }
}

class _IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.green[400]!
      ..style = PaintingStyle.fill;

    // Cart Body
    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.35);
    path.lineTo(size.width * 0.75, size.height * 0.35);
    path.lineTo(size.width * 0.65, size.height * 0.75);
    path.lineTo(size.width * 0.35, size.height * 0.75);
    path.close();
    canvas.drawPath(path, paint);

    // Wheels
    final wheelPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.40, size.height * 0.85), size.width * 0.08, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.60, size.height * 0.85), size.width * 0.08, wheelPaint);
    
    // Handle
    canvas.drawLine(Offset(size.width * 0.25, size.height * 0.35), Offset(size.width * 0.15, size.height * 0.35), paint);

    // Money Stack (Simplified as Rects)
    final moneyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.25), width: size.width * 0.3, height: size.height * 0.15),
      Radius.circular(size.width * 0.02)
    );
    canvas.drawRRect(moneyRect, fillPaint);
    canvas.drawRRect(moneyRect, paint..strokeWidth = size.width * 0.03..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Version 3: Utils / Composition using standard icons
class BrandIconComposite extends StatelessWidget {
  final double size;
  const BrandIconComposite({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.shopping_cart_outlined, size: size, color: Colors.white),
        Positioned(
          top: -size * 0.2, // Move up
          right: 0,
          left: 0,
          child: Center(
            child: Icon(Icons.attach_money, size: size * 0.6, color: Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}
