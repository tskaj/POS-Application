import 'dart:async';
import 'package:flutter/material.dart';

/// Simple global guard to allow pages to register a confirmation callback
/// for unsaved changes. The sidebar (or any other navigation control) can
/// call [UnsavedChangesGuard.maybeNavigate] to ensure the user is prompted
/// before navigating away when the current page reports unsaved changes.
class UnsavedChangesGuard {
  UnsavedChangesGuard._privateConstructor();
  static final UnsavedChangesGuard _instance =
      UnsavedChangesGuard._privateConstructor();
  factory UnsavedChangesGuard() => _instance;

  /// A registered callback that should return true when navigation is allowed.
  /// It receives a BuildContext so pages can show dialogs using their own
  /// context if needed.
  Future<bool> Function(BuildContext context)? _confirmCallback;

  /// Register a page's confirm callback. The page should unregister in dispose.
  void register(Future<bool> Function(BuildContext context) confirmCallback) {
    _confirmCallback = confirmCallback;
  }

  /// Unregister the currently registered callback.
  void unregister() {
    _confirmCallback = null;
  }

  /// Returns true if no guard is registered or the registered callback
  /// allows navigation.
  Future<bool> confirmNavigation(BuildContext context) async {
    if (_confirmCallback == null) return true;
    try {
      return await _confirmCallback!(context);
    } catch (e) {
      // On error, be conservative and allow navigation to avoid blocking UX.
      return true;
    }
  }

  /// Helper that runs [navigation] only when allowed by the registered guard.
  Future<void> maybeNavigate(
    BuildContext context,
    FutureOr<void> Function() navigation,
  ) async {
    final allowed = await confirmNavigation(context);
    if (allowed) {
      await navigation();
    }
  }
}
