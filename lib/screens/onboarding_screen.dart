
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/market_branding.dart';
import '../providers/product_provider.dart'; // Import provider for prefetching

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fetch promotions so home screen is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Provider.of<ProductProvider>(context, listen: false).prefetchPromotions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_onboarding', false);
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildSlide(
                title: 'Bienvenido a CompráBien',
                description: 'La herramienta definitiva para comparar precios de supermercados en Tandil y ahorrar en cada compra.',
                icon: Icons.shopping_cart_checkout,
                color: Colors.blue,
              ),
              _buildMarketSlide(),
              // Font Slide Removed (User Request)
              _buildSlide(
                title: 'Búsqueda Inteligente',
                description: 'Busca productos específicos y encuentra instantáneamente qué supermercado tiene el mejor precio.',
                icon: Icons.search,
                color: Colors.orange,
              ),
              _buildSlide(
                title: 'Ahorro Real',
                description: 'Analizamos tu carrito para decirte exactamente cuánto ahorras comprando en el lugar correcto.',
                icon: Icons.savings,
                color: Colors.green,
                isLast: true,
              ),
            ],
          ),
          
          // Theme Toggle (Top Left)
          // Theme Toggle Removed

          // Skip Button (Top Right)
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _finishOnboarding,
              child: Text(
                'Omitir',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54, 
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          
          // Indicators and Buttons (Bottom)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) => _buildIndicator(index)), // Reverted count to 4
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // BACK Button (Only if not first page)
                      if (_currentPage > 0)
                         TextButton(
                          onPressed: () {
                             _pageController.previousPage(
                               duration: const Duration(milliseconds: 300),
                               curve: Curves.easeInOut,
                             );
                          },
                          child: Text(
                            'Anterior',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        )
                      else
                         const SizedBox(width: 80), // Spacer to keep alignment if needed, or just shrink

                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < 3) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finishOnboarding();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(_currentPage == 3 ? 'Empezar' : 'Siguiente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: isActive ? 25 : 10,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildSlide({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: color),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSlide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The "Screenshot" mockup
          Container(
            height: 350,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fake App Content
                  Positioned.fill(
                    child: Container(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: Column(
                        children: [
                          Container(height: 60, color: Colors.blue.withOpacity(0.4)),
                          Expanded(
                            child: ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 5,
                              itemBuilder: (context, i) {
                                // User Request: "el div gris del medio, que sea mas alto"
                                // We make the 3rd item (index 2) taller to act as the "frame" for the chips
                                final isMiddle = i == 2;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  height: isMiddle ? 160.0 : 60.0, // Taller middle, shorter others
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Blurring Filter
                  Positioned.fill(
                    child: Container(
                      color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
                    ),
                  ),
                  
                  // Highlighted Market Chips Overlay
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10)],
                        ),
                        child: const Text(
                          'Tus Mercados',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 35),
                      // Tighter layout with adjusted grey background implication
                      // (The user asked for the "grey div" behind to be taller, but here we are just simulating chips floating.
                      // Perhaps they mean they visualise a container behind these chips? There isn't one explicitly.
                      // Or they mean the rows in the background app content? 
                      // User said: "atras de eso hay un div gris, ese quiero que sea mas alto, solo el div gris del medio, porque hay 3")
                      // Ah! In the fake app content, there are 3 visible rows perhaps? 
                      // Let's make the list items in the background variable height and make the middle one taller?
                      // Or maybe I misunderstood and they mean the container OF the chips?
                      // "aparecen 2 arriba y dos a bajo... restalos un poco que esten mas cerca [los chips]... atras de eso hay un div gris"
                      // It seems they want the chips to be grouped closer, and some background element to fit them better.
                      // Since I don't see a specific grey div *behind* the chips (just blur), I will assume they might mean the background 'fake row' that partially aligns with them?
                      // OR, they want me to ADD a grey div behind the chips? 
                      // "ese quiero que sea mas alto, solo el div gris del medio, porque hay 3" -> In the ListView.builder above, it creates 5 rows. 
                      // Maybe I should explicitly style the 'middle' row of the background content to be bigger?
                      // Let's try to make the background rows 2, 3 (middle), 4 visible. 
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMockChip(MarketStyle.monarca),
                          const SizedBox(width: 15),
                          _buildMockChip(MarketStyle.carrefour),
                        ],
                      ),
                      const SizedBox(height: 15), // Reduced gap from 25
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMockChip(MarketStyle.vea),
                          const SizedBox(width: 15),
                          _buildMockChip(MarketStyle.cooperativa),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Filtra por super',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Activa o desactiva los supermercados que te interesan para comparar precios personalizados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMockChip(MarketStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: style.primaryColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        style.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
