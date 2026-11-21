import 'package:flutter/material.dart';

/// Keeps content at a readable width on tablets and wide screens by centering
/// it with a maximum width. On phones (narrower than [maxWidth]) the child
/// simply fills the available width, so mobile layouts are unchanged.
///
/// Use [ResponsiveCenter.form] for forms and detail pages, and
/// [ResponsiveCenter.list] for lists and dashboards.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.alignment = Alignment.topCenter,
  });

  /// Forms, dialogs content and single-item detail pages.
  const ResponsiveCenter.form({super.key, required this.child, this.alignment = Alignment.topCenter})
      : maxWidth = 680;

  /// Lists, reports and dashboards.
  const ResponsiveCenter.list({super.key, required this.child, this.alignment = Alignment.topCenter})
      : maxWidth = 1040;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
