import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/main/tabs/home_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/insights_tab.dart'; // Earnings
import 'package:guidewire_gig_ins/features/main/tabs/risk_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/ai_engine_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/profile_tab.dart';

class MainShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShell({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavTap(int index) => setState(() => _currentIndex = index);

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isVisible) setState(() => _isVisible = false);
      } else if (notification.direction == ScrollDirection.forward) {
        if (!_isVisible) setState(() => _isVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeTab(),
      const InsightsTab(), // Serves as Earnings Tab
      const RiskTab(),
      const AIEngineTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isVisible ? Offset.zero : const Offset(0, 1.0),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
          backgroundColor: AppTheme.surfaceColor,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
            BottomNavigationBarItem(icon: Icon(Icons.security_rounded), label: 'Risk'),
            BottomNavigationBarItem(icon: Icon(Icons.hub_rounded), label: 'AI Engine'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
