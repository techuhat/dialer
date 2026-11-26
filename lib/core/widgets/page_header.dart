import 'package:flutter/material.dart';

import '../theme.dart';

/// The app bar of every tab and sub-page: big title on the left, round actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, this.subtitle, this.actions = const <Widget>[], this.onBack, super.key});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Shows a back button when set.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          if (onBack != null) HeaderAction(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: onBack!),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: onBack == null ? 28 : 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 13)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class HeaderAction extends StatelessWidget {
  const HeaderAction({required this.icon, required this.tooltip, required this.onPressed, this.badge = 0, super.key});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        backgroundColor: palette.missed,
        child: Icon(icon, color: palette.text),
      ),
    );
  }
}
