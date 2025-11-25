import 'package:flutter/material.dart';
import 'win32_window_utils.dart';

/// Small helper to show dialogs on Windows when the app enforces a TOPMOST/fullscreen
/// style. It temporarily clears TOPMOST so the dialog can appear above the app, then
/// restores the TOPMOST state afterwards.
class DialogHelpers {
  /// Show a dialog while temporarily disabling the app's TOPMOST flag.
  ///
  /// Example:
  /// await DialogHelpers.showWindowsDialog<bool>(
  ///   context,
  ///   builder: (c) => AlertDialog(...),
  /// );
  static Future<T?> showWindowsDialog<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    // Turn off topmost so native/OS dialogs are allowed to float above the app.
    try {
      Win32WindowUtils.setTopMost(false);
    } catch (_) {}

    try {
      final result = await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );

      return result;
    } finally {
      // Restore topmost and re-focus the app window.
      try {
        Win32WindowUtils.setTopMost(true);
        // Slight delay to allow OS to settle z-order before focusing.
        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            Win32WindowUtils.focusWindow();
          } catch (_) {}
        });
      } catch (_) {}
    }
  }
}
