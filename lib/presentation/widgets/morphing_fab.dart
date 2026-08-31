/// MorphingFab — a round "+" FAB that expands to a labeled pill on first tap,
/// then triggers the action on the second tap (V3.0.1 bug fix).
///
/// Behaviour (user-reported fix: «после нажатия на круглую кнопку с "+" она
/// менялась на кнопку с соответствующим текстом»):
///
///   1. Initial state — round "+" FAB (56×56).
///   2. Tap #1 — morph to an extended FAB showing [label] (with the proper
///      stadium-shaped background that fully covers the text — the previous
///      `FloatingActionButton.extended` inside the app got cut off because
///      `app_theme.dart` forced `shape: CircleBorder()` on every FAB).
///   3. Tap #2 — fire [onPressed]; the FAB collapses back to the round "+"
///      state on the next idle frame (or when the user navigates away).
///   4. Auto-collapse after 3.5s of no interaction, so a stray tap does not
///      leave the pill hanging.
///
/// Used by `GroupsPage` («Добавить группу») and `GroupDetailPage`
/// («Добавить активность») — the two screens where the user reported the
/// clipped-text bug.
import 'package:flutter/material.dart';

class MorphingFab extends StatefulWidget {
  const MorphingFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.heroTag,
  });

  /// Text shown after the first tap (e.g. "Add group", "Add activity").
  final String label;

  /// Action fired on the second tap.
  final VoidCallback onPressed;

  /// Icon for the round "+" state (defaults to `Icons.add_rounded`).
  final IconData icon;

  /// Hero tag — keep unique across pages so hero animations don't clash.
  final Object? heroTag;

  @override
  State<MorphingFab> createState() => _MorphingFabState();
}

class _MorphingFabState extends State<MorphingFab>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// Auto-collapse timer — fires after 3.5s of no interaction in the
  /// expanded state so the FAB doesn't stay stretched out indefinitely.
  void _scheduleCollapse() {
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && _expanded) {
        setState(() => _expanded = false);
      }
    });
  }

  void _onTap() {
    if (!_expanded) {
      setState(() => _expanded = true);
      _scheduleCollapse();
      return;
    }
    setState(() => _expanded = false);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use the FAB theme colors but force the proper shape per state — the
    // app no longer sets a global `shape` in `floatingActionButtonTheme`
    // (V3.0.1 fix), so we own the shape here.
    final bgColor = theme.floatingActionButtonTheme.backgroundColor ??
        theme.colorScheme.primaryContainer;
    final fgColor = theme.floatingActionButtonTheme.foregroundColor ??
        theme.colorScheme.onPrimaryContainer;

    if (_expanded) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: SizedBox(
          key: const ValueKey('morph-fab-extended'),
          height: 56,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onTap,
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(28),
                  // Match the global FAB elevation (default 4).
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: fgColor, size: 24),
                    const SizedBox(width: 12),
                    // Flexible so the label never overflows the pill — even on
                    // narrow devices with long localized labels.
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fgColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: SizedBox(
        key: const ValueKey('morph-fab-round'),
        width: 56,
        height: 56,
        child: FloatingActionButton(
          key: const ValueKey('morph-fab-round-btn'),
          heroTag: widget.heroTag,
          onPressed: _onTap,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          shape: const CircleBorder(),
          elevation: 4,
          child: Icon(widget.icon, size: 24),
        ),
      ),
    );
  }
}
