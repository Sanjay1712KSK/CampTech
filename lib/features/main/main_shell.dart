import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/main/tabs/home_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/analytics_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/claims_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/policy_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/profile_tab.dart';

class MainShell extends StatefulWidget {
  final int userId;
  final bool isVerified;
  final String userName;

  const MainShell({
    Key? key,
    required this.userId,
    this.isVerified = false,
    this.userName = 'User',
  }) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0=Analytics, 1=Claims, 2=Home, 3=Policy, 4=Profile
  int _currentIndex = 2;

  void _onNavTap(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AnalyticsTab(),
      const ClaimsTab(),
      HomeTab(userId: widget.userId, isVerified: widget.isVerified, userName: widget.userName),
      const PolicyTab(),
      ProfileTab(userId: widget.userId, userName: widget.userName, isVerified: widget.isVerified),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onNavTap(2),
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(
          Icons.home_rounded,
          color: _currentIndex == 2 ? Colors.black : Colors.black54,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.surfaceColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics', index: 0, current: _currentIndex, onTap: _onNavTap),
              _NavItem(icon: Icons.receipt_long_rounded, label: 'Claims', index: 1, current: _currentIndex, onTap: _onNavTap),
              const SizedBox(width: 48), // FAB space
              _NavItem(icon: Icons.policy_rounded, label: 'Policy', index: 3, current: _currentIndex, onTap: _onNavTap),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 4, current: _currentIndex, onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? AppTheme.primaryColor : AppTheme.textSecondary, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
