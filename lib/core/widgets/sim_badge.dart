import 'package:flutter/material.dart';

/// "SIM 1" / "SIM 2" on multi-SIM phones; nothing on single-SIM phones or unknown slots.
class SimBadge extends StatelessWidget {
  final int? simSlot;
  
  final int activeSimCount;

  const SimBadge({
    super.key,
    required this.simSlot,
    this.activeSimCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (activeSimCount <= 1 || simSlot == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 52,
        maxHeight: 22,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'SIM ${simSlot! + 1}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
