import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/points_provider.dart';
import '../config/colors.dart';
import 'home/home_screen.dart';
import 'catalog/catalog_screen.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';
import 'live/live_screen.dart';

/// الشاشة الرئيسية — 5 تبويبات مع الاحتفاظ بحالة كل شاشة
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: const [
            HomeScreen(),
            CatalogScreen(),
            LiveScreen(),
            CartScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Consumer2<CartProvider, PointsProvider>(
          builder: (context, cart, points, _) {
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
                onTap: (index) {
                  _pageController.jumpToPage(index);
                  setState(() => _currentIndex = index);
                },
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                backgroundColor: Colors.white,
                selectedLabelStyle: const TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 10,
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
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.live_tv_outlined),
                    activeIcon: Icon(Icons.live_tv),
                    label: 'المجتمع',
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
                  BottomNavigationBarItem(
                    icon: points.points > 0
                        ? Badge(
                            isLabelVisible: true,
                            label: Text(
                              '${points.points}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Icon(Icons.person_outline),
                          )
                        : const Icon(Icons.person_outline),
                    activeIcon: points.points > 0
                        ? Badge(
                            isLabelVisible: true,
                            label: Text(
                              '${points.points}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Icon(Icons.person),
                          )
                        : const Icon(Icons.person),
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
