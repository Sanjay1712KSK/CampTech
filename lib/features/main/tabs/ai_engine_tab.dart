import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class AIEngineTab extends StatefulWidget {
  const AIEngineTab({Key? key}) : super(key: key);
  @override
  State<AIEngineTab> createState() => _AIEngineTabState();
}

class _AIEngineTabState extends State<AIEngineTab> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Engine Showcase', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('How our real-time algorithms protect you', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 48),

              _EngineFlowCard(
                title: '1. Risk Assessment Engine',
                animDelay: 0.1,
                controller: _animController,
                flowItems: const [
                  _FlowStep(icon: Icons.cloud_outlined, label: 'Weather\nData'),
                  _FlowArrow(),
                  _FlowStep(icon: Icons.memory_rounded, label: 'ML\nRisk Model', isCore: true),
                  _FlowArrow(),
                  _FlowStep(icon: Icons.security_rounded, label: 'Live\nRisk Score', color: AppTheme.warningColor),
                ],
              ),
              const SizedBox(height: 32),

              _EngineFlowCard(
                title: '2. Dynamic Premium Engine',
                animDelay: 0.4,
                controller: _animController,
                flowItems: const [
                  _FlowStep(icon: Icons.insights_rounded, label: 'Baseline\nIncome'),
                  _FlowArrow(),
                  _FlowStep(icon: Icons.settings_suggest_rounded, label: 'Actuarial\nEngine', isCore: true),
                  _FlowArrow(),
                  _FlowStep(icon: Icons.account_balance_wallet_rounded, label: 'Adaptive\nPremium', color: AppTheme.primaryColor),
                ],
              ),
              const SizedBox(height: 32),

              _EngineFlowCard(
                title: '3. Auto-Claim Engine',
                animDelay: 0.7,
                controller: _animController,
                flowItems: const [
                  _FlowStep(icon: Icons.trending_down_rounded, label: 'Income\nLoss', color: AppTheme.errorColor),
                  _FlowArrow(),
                  _FlowStep(icon: Icons.smart_toy_rounded, label: 'Trigger\nEngine', isCore: true),
                  _FlowArrow(),
                  _FlowStep(icon: Icons.payments_rounded, label: 'Instant\nPayout', color: AppTheme.successColor),
                ],
              ),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngineFlowCard extends StatelessWidget {
  final String title;
  final double animDelay;
  final AnimationController controller;
  final List<Widget> flowItems;

  const _EngineFlowCard({
    required this.title,
    required this.animDelay,
    required this.controller,
    required this.flowItems,
  });

  @override
  Widget build(BuildContext context) {
    final fadeAnim = CurvedAnimation(parent: controller, curve: Interval(animDelay, 1.0, curve: Curves.easeOut));
    final slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(fadeAnim);

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: flowItems,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCore;
  final Color? color;

  const _FlowStep({required this.icon, required this.label, this.isCore = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isCore ? AppTheme.primaryColor : Colors.white);
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isCore ? 16 : 12),
          decoration: BoxDecoration(
            color: c.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: c.withOpacity(0.5), width: isCore ? 2 : 1),
            boxShadow: isCore ? [BoxShadow(color: c.withOpacity(0.3), blurRadius: 16)] : [],
          ),
          child: Icon(icon, color: c, size: isCore ? 28 : 22),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: isCore ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24.0),
      child: Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 20),
    );
  }
}
