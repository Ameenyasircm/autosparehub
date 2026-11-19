import 'package:flutter/material.dart';

/// Shows a network image scaled to fit (like [BoxFit.contain]) with all four
/// corners of the *image itself* rounded.
///
/// A plain [ClipRRect] around a contained image rounds the surrounding box,
/// not the visible picture. This widget reads the image's aspect ratio first,
/// then clips a box of exactly that shape.
class RoundedContainImage extends StatefulWidget {
  final String url;
  final double radius;
  final Widget Function(BuildContext context) errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;

  const RoundedContainImage({
    super.key,
    required this.url,
    required this.errorBuilder,
    this.loadingBuilder,
    this.radius = 12,
  });

  @override
  State<RoundedContainImage> createState() => _RoundedContainImageState();
}

class _RoundedContainImageState extends State<RoundedContainImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(RoundedContainImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspectRatio = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream = NetworkImage(widget.url)
        .resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _removeListener();
    _listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (mounted && w > 0 && h > 0) {
          setState(() => _aspectRatio = w / h);
        }
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream = stream..addListener(_listener!);
  }

  void _removeListener() {
    if (_listener != null) _stream?.removeListener(_listener!);
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.errorBuilder(context);
    final ratio = _aspectRatio;
    if (ratio == null) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Image.network(
            widget.url,
            fit: BoxFit.fill, // box already has the image's aspect ratio
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, _, __) => widget.errorBuilder(context),
          ),
        ),
      ),
    );
  }
}
