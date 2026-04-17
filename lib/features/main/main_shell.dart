import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';
import 'package:guidewire_gig_ins/features/main/tabs/claims_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/home_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/insights_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/profile_tab.dart';
import 'package:guidewire_gig_ins/features/main/tabs/policy_tab.dart';

final GlobalKey<MainShellState> mainShellGlobalKey =
    GlobalKey<MainShellState>();

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTab(key: homeTabGlobalKey),
      const InsightsTab(),
      const PolicyTab(),
      const ClaimsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppTheme.surfaceColor,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart_rounded),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Insurance',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Claims',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> setCurrentIndex(int index) async {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> scrollHomeToSection(String section) async {
    await homeTabGlobalKey.currentState?.scrollToSection(section);
  }

  Future<void> runHomeRainScenario() async {
    await homeTabGlobalKey.currentState?.runAutomatedScenario('rain');
  }

  Future<void> refreshHomeData() async {
    await homeTabGlobalKey.currentState?.refreshForAutomation();
  }
}
