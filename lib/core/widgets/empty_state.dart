import 'package:flutter/material.dart';

import '../theme.dart';

/// Friendly placeholder for an empty list; the copy is allowed to have a sense of humour.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.emoji, required this.title, required this.message, this.action, super.key});

  final String emoji;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text, fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 14.5, height: 1.4),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
