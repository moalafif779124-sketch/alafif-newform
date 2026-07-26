import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/points_provider.dart';
import '../providers/navigation_provider.dart';
import '../config/colors.dart';
import 'home/home_screen.dart';
import 'catalog/catalog_screen.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';
import 'live/live_screen.dart';

/// الشاشة الرئيسية — تبويبات ديناميكية من Firestore
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final PageController _pageController;

  // خريطة id التبويب ← شاشته
  static const Map<String, Widget> _screenMap = {
    'home': HomeScreen(),
    'category': CatalogScreen(),
    'live': LiveScreen(),
    'cart': CartScreen(),
    'profile': ProfileScreen(),
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // تحميل إعدادات التنقل من Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().load();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// أيقونات كل تبويب
  static const Map<String, IconData> _iconMap = {
    'home': Icons.home,
    'category': Icons.grid_view,
    'live': Icons.live_tv,
    'cart': Icons.shopping_cart,
    'profile': Icons.person,
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Consumer<NavigationProvider>(
          builder: (context, nav, _) {
            final activeTabs = nav.tabs;
            // تصحيح المؤشر إذا كان خارج النطاق
            if (_currentIndex >= activeTabs.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _currentIndex = 0);
                _pageController.jumpToPage(0);
              });
            }
            return PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              children: activeTabs.map((tab) {
                return _screenMap[tab.id] ?? const SizedBox.shrink();
              }).toList(),
            );
          },
        ),
        bottomNavigationBar: Consumer3<NavigationProvider, CartProvider, PointsProvider>(
          builder: (context, nav, cart, points, _) {
            final activeTabs = nav.tabs;
            if (activeTabs.isEmpty) return const SizedBox.shrink();

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
                currentIndex: _currentIndex < activeTabs.length ? _currentIndex : 0,
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
                items: activeTabs.map((tab) {
                  final icon = _iconMap[tab.id] ?? Icons.tab;
                  final label = tab.labelAr.isNotEmpty ? tab.labelAr : _defaultLabel(tab.id);

                  // شارة مخصصة للسلة
                  if (tab.id == 'cart') {
                    return BottomNavigationBarItem(
                      icon: Badge(
                        isLabelVisible: cart.itemCount > 0,
                        label: Text('${cart.itemCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        child: Icon(icon),
                      ),
                      activeIcon: Badge(
                        isLabelVisible: cart.itemCount > 0,
                        label: Text('${cart.itemCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        child: Icon(icon),
                      ),
                      label: label,
                    );
                  }

                  // شارة النقاط للحساب
                  if (tab.id == 'profile') {
                    return BottomNavigationBarItem(
                      icon: points.points > 0
                          ? Badge(
                              isLabelVisible: true,
                              label: Text('${points.points}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              child: Icon(icon),
                            )
                          : Icon(icon),
                      activeIcon: points.points > 0
                          ? Badge(
                              isLabelVisible: true,
                              label: Text('${points.points}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              child: Icon(icon),
                            )
                          : Icon(icon),
                      label: label,
                    );
                  }

                  return BottomNavigationBarItem(
                    icon: Icon(icon),
                    activeIcon: Icon(icon),
                    label: label,
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  String _defaultLabel(String id) {
    const labels = {
      'home': 'الرئيسية',
      'category': 'الفئات',
      'live': 'المجتمع',
      'cart': 'السلة',
      'profile': 'حسابي',
    };
    return labels[id] ?? id;
  }
}
