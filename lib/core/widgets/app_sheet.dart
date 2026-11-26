import 'package:flutter/material.dart';

/// Bottom sheet with the app's rounded top and drag handle.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? background,
  bool fullHeight = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: fullHeight,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => AppSheet(background: background, child: builder(sheetContext)),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({required this.child, this.background, super.key});

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final Color color = background ?? Theme.of(context).colorScheme.surface;
    final bool dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
