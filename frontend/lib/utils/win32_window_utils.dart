import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Makes the current active window cover the entire monitor (hides taskbar)
/// and provides a reliable minimize using Win32 ShowWindow.
class Win32WindowUtils {
  // Cache the HWND for our Flutter window so we can reliably operate on it
  static int _cachedHwnd = 0;

  static bool _isWindowForCurrentProcess(int hwnd) {
    if (hwnd == 0) return false;
    final pidPtr = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(hwnd, pidPtr);
      final pid = pidPtr.value;
      return pid == GetCurrentProcessId();
    } finally {
      free(pidPtr);
    }
  }

  static int _findWindowForCurrentProcess() {
    final currentPid = GetCurrentProcessId();
    int hwnd = GetTopWindow(NULL);
    while (hwnd != 0) {
      final pidPtr = calloc<Uint32>();
      try {
        GetWindowThreadProcessId(hwnd, pidPtr);
        if (pidPtr.value == currentPid && IsWindowVisible(hwnd) == 1) {
          return hwnd;
        }
      } finally {
        free(pidPtr);
      }
      hwnd = GetWindow(hwnd, GW_HWNDNEXT);
    }
    return 0;
  }

  static int _resolveHwnd() {
    // If cached and valid, return
    if (_cachedHwnd != 0 && _isWindowForCurrentProcess(_cachedHwnd)) {
      return _cachedHwnd;
    }

    // Try foreground window
    final fg = GetForegroundWindow();
    if (fg != 0 && _isWindowForCurrentProcess(fg)) {
      _cachedHwnd = fg;
      return fg;
    }

    // Try active window
    final active = GetActiveWindow();
    if (active != 0 && _isWindowForCurrentProcess(active)) {
      _cachedHwnd = active;
      return active;
    }

    // Fall back to scanning top-level windows for our process
    final found = _findWindowForCurrentProcess();
    if (found != 0) {
      _cachedHwnd = found;
      return found;
    }

    return 0;
  }

  /// Aggressively enforce fullscreen: apply fullscreen style, toggle topmost off/on,
  /// and force a native maximize. Use this when other window managers reset styles.
  static void enforceFullscreenPersistent() {
    final hwnd = _resolveHwnd();
    if (hwnd == 0) return;

    try {
      // Initial apply
      setWindowFullscreen();

      // Reapply: toggle NOTOPMOST then TOPMOST to force z-order and repaint
      final monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      final mi = calloc<MONITORINFO>();
      mi.ref.cbSize = sizeOf<MONITORINFO>();
      if (GetMonitorInfo(monitor, mi) != 0) {
        int left = mi.ref.rcMonitor.left - 12;
        int top = mi.ref.rcMonitor.top - 12;
        int right = mi.ref.rcMonitor.right + 12;
        int bottom = mi.ref.rcMonitor.bottom + 12;
        final flags = SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOOWNERZORDER;

        // Set NOTOPMOST then TOPMOST
        SetWindowPos(
          hwnd,
          HWND_NOTOPMOST,
          left,
          top,
          right - left,
          bottom - top,
          flags,
        );
        SetWindowPos(
          hwnd,
          HWND_TOPMOST,
          left,
          top,
          right - left,
          bottom - top,
          flags,
        );
      }
      free(mi);

      // Ensure maximized state
      ShowWindow(hwnd, SW_SHOWMAXIMIZED);
    } catch (_) {
      // ignore
    }
  }

  /// Set the active window to a fullscreen-like WS_POPUP covering the monitor.
  static void setWindowFullscreen() {
    final hwnd = _resolveHwnd();
    if (hwnd == 0) return;

    final monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    final mi = calloc<MONITORINFO>();
    mi.ref.cbSize = sizeOf<MONITORINFO>();
    final ok = GetMonitorInfo(monitor, mi);
    if (ok == 0) {
      free(mi);
      return;
    }

    int left = mi.ref.rcMonitor.left;
    int top = mi.ref.rcMonitor.top;
    int right = mi.ref.rcMonitor.right;
    int bottom = mi.ref.rcMonitor.bottom;

    // Expand bounds to avoid any 1-2px gaps due to DPI/scaling or window chrome.
    // Increase this to ensure the window fully covers the monitor including the taskbar.
    const int expand = 12;
    left -= expand;
    top -= expand;
    right += expand;
    bottom += expand;

    // Remove overlapped window styles and set popup style
    final style = GetWindowLongPtr(hwnd, GWL_STYLE);
    final newStyle = (style & ~WS_OVERLAPPEDWINDOW) | WS_POPUP | WS_VISIBLE;
    SetWindowLongPtr(hwnd, GWL_STYLE, newStyle);

    // Resize and move window to monitor bounds and make it topmost so it covers the taskbar
    // Use SWP_FRAMECHANGED and SWP_SHOWWINDOW to apply style changes and show the window
    final flags = SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOOWNERZORDER;
    SetWindowPos(
      hwnd,
      HWND_TOPMOST,
      left,
      top,
      right - left,
      bottom - top,
      flags,
    );

    // Force a native maximize/show call to ensure the OS repaints and the window fills the monitor.
    ShowWindow(hwnd, SW_SHOWMAXIMIZED);

    free(mi);
  }

  /// Minimize the active window using Win32 ShowWindow.
  /// Returns true if the call was issued.
  static bool minimizeWindow() {
    final hwnd = _resolveHwnd();
    if (hwnd == 0) return false;
    return ShowWindow(hwnd, SW_MINIMIZE) != 0;
  }

  /// Restore the active window from minimized state and ensure it fills the monitor.
  static void restoreAndFill() {
    final hwnd = _resolveHwnd();
    if (hwnd == 0) return;
    ShowWindow(hwnd, SW_RESTORE);
    // Re-apply fullscreen style/size after restore
    setWindowFullscreen();
  }

  /// Toggle whether the application's main window should be TOPMOST.
  /// When [top] is true the window is set to HWND_TOPMOST; otherwise HWND_NOTOPMOST.
  static void setTopMost(bool top) {
    final hwnd = _resolveHwnd();
    if (hwnd == 0) return;
    final flags =
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED;
    SetWindowPos(hwnd, top ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, flags);
  }

  /// Bring the application's main window to the foreground and focus it.
  static void focusWindow() {
    final hwnd = _resolveHwnd();
    if (hwnd == 0) return;
    SetForegroundWindow(hwnd);
  }
}
