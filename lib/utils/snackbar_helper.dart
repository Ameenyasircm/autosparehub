import 'dart:async';
import 'package:flutter/material.dart';

/// Newer Flutter versions keep a SnackBar on screen until it is tapped when it
/// has an action button (e.g. "View Cart"), and accessibility settings can do
/// the same for any SnackBar. This shows the SnackBar and closes it ourselves
/// after its duration (never longer than [maxVisible]), on every Flutter version.
extension AutoHideSnackBar on ScaffoldMessengerState {
  static const Duration maxVisible = Duration(seconds: 4);

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBarAutoHide(
    SnackBar snackBar,
  ) {
    final controller = showSnackBar(snackBar);
    var closed = false;
    controller.closed.then((_) => closed = true);

    final visibleFor = snackBar.duration < maxVisible ? snackBar.duration : maxVisible;
    // Timer starts now; if this SnackBar is queued behind another one it is
    // simply closed earlier, which is fine for short status messages.
    Timer(visibleFor, () {
      if (closed) return;
      try {
        controller.close();
      } catch (_) {
        // Not the current SnackBar any more (another one replaced it).
      }
    });
    return controller;
  }
}
