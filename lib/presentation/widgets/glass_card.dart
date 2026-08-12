import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';

/// Glass surface card — from UI Kit.
/// Used for weather blocks, route summaries, etc.
class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsets? padding;
  final double? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? DesignTokens.cardSurface;

    return Container(
      padding: padding ?? const EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(
          borderRadius ?? DesignTokens.radiusLg,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
