import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/main/tabs/home_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/insights_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/claims_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/policy_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/profile_tab.dart';
import 'package:guidewire_gig_ins/l10n/app_localizations.dart';

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
  bool _isVisible = true;

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
      InsightsTab(userId: widget.userId),
      const ClaimsTab(),
      HomeTab(userId: widget.userId, isVerified: widget.isVerified, userName: widget.userName),
      const PolicyTab(),
      ProfileTab(userId: widget.userId, userName: widget.userName, isVerified: widget.isVerified),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isVisible ? Offset.zero : const Offset(0, 1.5),
        child: FloatingActionButton(
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isVisible ? Offset.zero : const Offset(0, 1.0),
        child: BottomAppBar(
          color: AppTheme.surfaceColor,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.lightbulb_rounded, label: AppLocalizations.of(context)?.insights ?? 'Insights', index: 0, current: _currentIndex, onTap: _onNavTap),
                _NavItem(icon: Icons.receipt_long_rounded, label: AppLocalizations.of(context)?.claims ?? 'Claims', index: 1, current: _currentIndex, onTap: _onNavTap),
                const SizedBox(width: 48), // FAB space
                _NavItem(icon: Icons.policy_rounded, label: AppLocalizations.of(context)?.policy ?? 'Policy', index: 3, current: _currentIndex, onTap: _onNavTap),
                _NavItem(icon: Icons.person_rounded, label: AppLocalizations.of(context)?.profile ?? 'Profile', index: 4, current: _currentIndex, onTap: _onNavTap),
              ],
            ),
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
