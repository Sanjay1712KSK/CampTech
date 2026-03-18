import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassCard({
    Key? key,
    required this.child,
    this.highlighted = false,
    this.onTap,
    this.padding = const EdgeInsets.all(20.0),
    this.borderRadius = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: padding,
            decoration: BoxDecoration(
              color: highlighted 
                  ? AppTheme.primaryColor 
                  : AppTheme.surfaceColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: highlighted 
                    ? AppTheme.primaryColor 
                    : Colors.white.withOpacity(0.05),
                width: 1.5,
              ),
              boxShadow: [
                if (highlighted)
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: highlighted ? Colors.black : Colors.white,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: highlighted ? Colors.black : Colors.white,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
