import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../config/colors.dart';
import 'home/home_screen.dart';
import 'catalog/catalog_screen.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';

/// الشاشة الرئيسية للتطبيق مع شريط التنقل السفلي
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CatalogScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                backgroundColor: Colors.white,
                selectedLabelStyle: const TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 11,
                ),
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'الرئيسية',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_outlined),
                    activeIcon: Icon(Icons.grid_view),
                    label: 'الفئات',
                  ),
                  BottomNavigationBarItem(
                    icon: Badge(
                      isLabelVisible: cart.itemCount > 0,
                      label: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                    activeIcon: Badge(
                      isLabelVisible: cart.itemCount > 0,
                      label: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Icon(Icons.shopping_cart),
                    ),
                    label: 'السلة',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'حسابي',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
