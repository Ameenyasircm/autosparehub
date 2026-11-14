import 'package:flutter/material.dart';

/// Rebuilds [builder] whenever the nearest enclosing scroll view scrolls,
/// passing the current scroll offset (negative while over-scrolling at the top).
/// Only the builder output is rebuilt, so [child] can hold the expensive part.
class ScrollOffsetBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, double offset, Widget? child) builder;
  final Widget? child;

  const ScrollOffsetBuilder({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return builder(context, 0, child);
    return AnimatedBuilder(
      animation: position,
      child: child,
      builder: (context, child) =>
          builder(context, position.hasPixels ? position.pixels : 0, child),
    );
  }
}

/// Fades [child] in while sliding it up a little the first time it is built.
/// [index] staggers neighbouring items; the stagger is capped so items far
/// down a list do not wait long.
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;

  const FadeSlideIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const base = 380;
    const step = 60;
    final delay = step * (index % 8);
    final total = base + delay;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
    );
  }
}
