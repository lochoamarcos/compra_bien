import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';

class LottieCartFAB extends StatefulWidget {
  const LottieCartFAB({super.key});

  @override
  State<LottieCartFAB> createState() => _LottieCartFABState();
}

class _LottieCartFABState extends State<LottieCartFAB> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _lastTotalItems = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset(); // Snap Lottie back to frame 0
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
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        // Unique items count (different products)
        final uniqueItemsCount = cart.items.length;
        
        // Trigger animation if a new product is added and we are not already animating
        if (uniqueItemsCount > _lastTotalItems) {
          if (!_controller.isAnimating) {
            _controller.forward(from: 0);
          }
        }
        _lastTotalItems = uniqueItemsCount;

        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            borderRadius: BorderRadius.circular(34),
            child: Container(
              width: 64, // Bigger button
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00ACC1), // Solid Primary UI Color
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1, // Border-like effect
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF00838F).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Lottie cart centered
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      double targetOffsetX = _controller.isAnimating 
                          ? (4.0 * (1.0 - (_controller.value * 2.5))).clamp(-10.0, 4.0)
                          : 4.0;
                      
                      // Ensure it centers firmly as animation progresses
                      if (_controller.value > 0.4) targetOffsetX = 0;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.translationValues(targetOffsetX, 0, 0),
                        child: SizedBox(
                          width: 52, // Animation remains same size
                          height: 52,
                          child: Lottie.asset(
                            'assets/animations/CartAnim.json',
                            controller: _controller,
                            animate: false,
                            onLoaded: (composition) => _controller.duration = composition.duration,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  if (uniqueItemsCount > 0)
                    Positioned(
                      right: 8, // Refined for larger circle
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$uniqueItemsCount',
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
