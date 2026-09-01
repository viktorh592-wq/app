/// Frosted-glass button — true glassmorphism (BackdropFilter + blur) used
/// for the floating map controls (close / filter / zoom / locate). Matches
/// the screenshot the user provided: lavender translucency, soft drop
/// shadow, thin white inner border.
///
/// Two shapes are supported via [GlassButtonShape]:
///   • [circle] — square-on-its-side round icon button (zoom +/-, locate)
///   • [pill] — rounded-rect chip with optional icon + label (filter chips)
import 'dart:ui';

import 'package:flutter/material.dart';

enum GlassButtonShape { circle, pill }

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onTap,
    this.icon,
    this.label,
    this.shape = GlassButtonShape.circle,
    this.size = 44,
    this.blurSigma = 12,
    this.tint = const Color(0xB3B39DDB), // ~70% lavender
    this.borderColor = const Color(0x4DFFFFFF), // ~30% white
    this.iconColor = Colors.white,
    this.labelColor = Colors.white,
    this.selected = false,
    this.selectedTint = const Color(0xCC9B8AFB),
  }) : assert(icon != null || label != null,
            'GlassButton needs at least an icon or a label');

  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final GlassButtonShape shape;
  final double size;
  final double blurSigma;
  final Color tint;
  final Color borderColor;
  final Color iconColor;
  final Color labelColor;
  final bool selected;
  final Color selectedTint;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == GlassButtonShape.circle;
    final radius =
        isCircle ? Radius.circular(size / 2) : const Radius.circular(20);

    final content = <Widget>[];
    if (icon != null) {
      content.add(Icon(icon, color: iconColor, size: isCircle ? 22 : 18));
    }
    if (label != null) {
      if (icon != null) content.add(const SizedBox(width: 6));
      content.add(Text(
        label!,
        style: TextStyle(
          color: labelColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ));
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.all(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            // Circle: force square; pill: shrink-wrap to content + padding.
            constraints: isCircle
                ? BoxConstraints.tightFor(width: size, height: size)
                : BoxConstraints(minHeight: 36),
            padding: isCircle
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? selectedTint : tint,
              borderRadius: BorderRadius.all(radius),
              border: Border.all(color: borderColor, width: 1),
              // Soft drop shadow — gives the "floating above the map" feel
              // shown in the screenshot (Drop shadow: X 0, Y 4, Blur 4,
              // Color #000000 25%).
              boxShadow: const [
                BoxShadow(
                  color: Color(0x401A1A2E),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: isCircle
                ? Center(
                    child: Icon(icon, color: iconColor, size: 22),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: content),
          ),
        ),
      ),
    );
  }
}

/// Vertical stack of glass buttons — used for the right-side filter cluster
/// on the map (× / Все / Найденные / Скрыть). Each entry is one [GlassButton]
/// in pill shape; the cluster is just a Column with even spacing.
class GlassButtonStack extends StatelessWidget {
  const GlassButtonStack({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
