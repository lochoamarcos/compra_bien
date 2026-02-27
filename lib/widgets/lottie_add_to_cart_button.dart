import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieAddToCartButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool isInCart;
  final int quantity;
  final double size;

  const LottieAddToCartButton({
    super.key,
    required this.onTap,
    this.onIncrement,
    this.onDecrement,
    this.isInCart = false,
    this.quantity = 0,
    this.size = 32,
  });

  @override
  State<LottieAddToCartButton> createState() => _LottieAddToCartButtonState();
}

class _LottieAddToCartButtonState extends State<LottieAddToCartButton> {
  // Logic to track internal state during animations
  late int _displayQuantity;
  bool _isTransitioning = false;
  bool _forceShowCounter = false;
  bool _forceShowAdd = false;

  @override
  void initState() {
    super.initState();
    _displayQuantity = widget.quantity;
  }

  @override
  void didUpdateWidget(LottieAddToCartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CRITICAL: Protect display quantity from parent's immediate "0" or "1" 
    // during the window where we are intentionally showing the opposite visually.
    if (!_isTransitioning) {
      _displayQuantity = widget.quantity;
    }
  }

  Future<void> _handleInitialAdd() async {
    if (_isTransitioning) return;
    
    setState(() {
      _isTransitioning = true;
      _forceShowAdd = true; // Still showing "+" button
      _forceShowCounter = false;
      _displayQuantity = 1; // Prepare it ALREADY in the ghost state
    });

    // 1. Fade OUT Add Button
    await Future.delayed(const Duration(milliseconds: 50)); 
    setState(() => _forceShowAdd = false);
    
    // Wait for fade-out to be 100% complete
    await Future.delayed(const Duration(milliseconds: 250));

    // 2. State swap while invisible
    widget.onTap(); 
    
    // Settle time while invisible to avoid frame-jump
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. Fade IN Counter
    setState(() {
      _forceShowCounter = true;
      _displayQuantity = 1; // Re-ensure it's 1
    });
    
    await Future.delayed(const Duration(milliseconds: 250));
    
    if (mounted) {
      setState(() {
        _isTransitioning = false;
        _forceShowCounter = false;
        _forceShowAdd = false;
      });
    }
  }

  Future<void> _handleLastRemove() async {
    if (_isTransitioning) return;

    setState(() {
      _isTransitioning = true;
      _forceShowCounter = true; // Still showing Counter
      _displayQuantity = 1;     // GHOST VALUE: Lock to '1' even if parent sends 0
    });

    // 1. Fade OUT Counter
    await Future.delayed(const Duration(milliseconds: 50));
    setState(() => _forceShowCounter = false);

    // Wait for the Counter to be 100% gone
    await Future.delayed(const Duration(milliseconds: 250));

    // 2. State swap while invisible
    if (widget.onDecrement != null) widget.onDecrement!();
    
    // Gap while invisible
    await Future.delayed(const Duration(milliseconds: 50));

    // 3. Fade IN Add Button
    setState(() {
      _forceShowAdd = true;
      _displayQuantity = 1; // Keep 1 in ghost state while invisible
    });

    await Future.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      setState(() {
        _isTransitioning = false;
        _forceShowCounter = false;
        _forceShowAdd = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If transitioning, we control visibility manually.
    // If not, we fall back to the widget's isInCart state.
    bool showAdd;
    bool showCounter;

    if (_isTransitioning) {
      showAdd = _forceShowAdd;
      showCounter = _forceShowCounter;
    } else {
      showAdd = !widget.isInCart;
      showCounter = widget.isInCart;
    }
    
    return GestureDetector(
      onTap: () {
         if (!widget.isInCart) _handleInitialAdd();
         else widget.onTap(); 
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.size,
          maxWidth: widget.size,
          minHeight: widget.size,
          maxHeight: (widget.isInCart || _isTransitioning) ? widget.size * 4.0 : widget.size, 
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // STAGE 1: Add Button
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: showAdd ? 1.0 : 0.0,
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !showAdd,
                child: _buildAddButton(),
              ),
            ),
            
            // STAGE 2: Counter
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: showCounter ? 1.0 : 0.0,
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !showCounter,
                child: _buildCounter(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Center(
      key: const ValueKey('add_button_ui'),
      child: Container(
         width: widget.size,
         height: widget.size,
         decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00ACC1), // Solid celeste
            boxShadow: [
               BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
               ),
            ],
         ),
         child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 20,
         ),
      ),
    );
  }

  Widget _buildCounter(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final iconSize = scaler.scale(widget.size * 0.44);
    final fontSize = scaler.scale(widget.size * 0.44);

    return Container(
      key: const ValueKey('counter_ui'),
      padding: const EdgeInsets.symmetric(vertical: 4), 
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(Icons.add, Colors.green, iconSize, widget.onIncrement),
            
            SizedBox(height: scaler.scale(3)), 
            
            // Fixed height and min-width container prevents the +/- buttons from "jumping" or joining
            // when the number changes or transitions.
            Container(
              height: fontSize * 1.5, // Increased slightly for better breathability
              constraints: BoxConstraints(minWidth: fontSize * 1.5),
              alignment: Alignment.center,
              child: Text(
                '$_displayQuantity',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  color: const Color(0xFF00ACC1),
                  height: 1.0,
                ),
              ),
            ),
            
            SizedBox(height: scaler.scale(4)), 
            
            _buildActionButton(Icons.remove, Colors.red, iconSize, () {
              if (widget.quantity <= 1) {
                _handleLastRemove();
              } else if (widget.onDecrement != null) {
                widget.onDecrement!();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, double size, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
           shape: BoxShape.circle,
           color: color.withOpacity(0.1),
        ),
        child: Icon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
