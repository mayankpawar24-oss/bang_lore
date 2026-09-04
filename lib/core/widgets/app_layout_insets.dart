import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Provides safe layout insets throughout the app, specifically accounting
/// for persistent floating or fixed bottom navigation bars across Patient & Doctor shells.
class AppLayoutInsets extends InheritedWidget {
  /// The height of the persistent bottom navigation bar in the current shell.
  final double bottomBarHeight;

  const AppLayoutInsets({
    super.key,
    required this.bottomBarHeight,
    required super.child,
  });

  static AppLayoutInsets? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLayoutInsets>();
  }

  /// Returns the height of the bottom navigation bar, or 0.0 if not present.
  static double bottomBarHeightOf(BuildContext context) {
    return of(context)?.bottomBarHeight ?? 0.0;
  }

  /// Calculates a safe bottom inset for interactive popups, modal bottom sheets,
  /// and bottom action buttons.
  ///
  /// - When the on-screen keyboard is open (`viewInsets.bottom > 0`), returns the
  ///   keyboard height so content floats above the keyboard.
  /// - When keyboard is closed, returns at least `bottomBarHeight` (and system safe
  ///   area `padding.bottom`) so content and actions are completely above the
  ///   persistent bottom navigation bar.
  static double bottomSafeInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.viewInsets.bottom > 0) {
      return mediaQuery.viewInsets.bottom;
    }
    final barHeight = bottomBarHeightOf(context);
    return math.max(mediaQuery.padding.bottom, barHeight);
  }

  @override
  bool updateShouldNotify(AppLayoutInsets oldWidget) {
    return bottomBarHeight != oldWidget.bottomBarHeight;
  }
}

/// A responsive wrapper for bottom sheets that ensures:
/// 1. Maximum width constraint (e.g. 640px) on web and tablet.
/// 2. Height is capped to viewport with internal scrolling so long sheets never overflow.
/// 3. Bottom padding clears persistent bottom bars and the software keyboard.
class AppBottomSheetWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;

  const AppBottomSheetWrapper({
    super.key,
    required this.child,
    this.maxWidth = 640.0,
    this.maxHeightFactor = 0.88,
    this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = AppLayoutInsets.bottomSafeInset(context);
    final effectiveBorderRadius = borderRadius ??
        const BorderRadius.vertical(top: Radius.circular(24.0));

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: mediaQuery.size.height * maxHeightFactor,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
            borderRadius: effectiveBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              padding: (padding as EdgeInsets).copyWith(
                bottom: bottomInset + 16.0,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
