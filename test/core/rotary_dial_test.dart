import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/widgets/nav_parts.dart';

/// Hosts a [DialWinder] the way the dials do.
class _WinderHost extends StatefulWidget {
  const _WinderHost({required this.onReady});

  final ValueChanged<DialWinder> onReady;

  @override
  State<_WinderHost> createState() => _WinderHostState();
}

class _WinderHostState extends State<_WinderHost> with SingleTickerProviderStateMixin {
  late final DialWinder _winder = DialWinder(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onReady(_winder);
  }

  @override
  void dispose() {
    _winder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  test('the light finds the tick facing a direction, all the way round', () {
    expect(RotaryDial.tickToward(const Offset(0, -1)), closeTo(0, 1e-9), reason: 'up is tick 0');
    expect(RotaryDial.tickToward(const Offset(1, 0)), closeTo(3, 1e-9), reason: '3 o’clock');
    expect(RotaryDial.tickToward(const Offset(0, 1)), closeTo(6, 1e-9), reason: '6 o’clock');
    final double nearlyUp = RotaryDial.tickToward(Offset(math.sin(-0.05), -math.cos(-0.05)));
    expect(nearlyUp, closeTo(RotaryDial.ticks - 0.05 / (2 * math.pi / RotaryDial.ticks), 1e-6), reason: 'wraps below 12');
  });

  test('dialling the top tick winds the ring about a third of a turn, like a real dial', () {
    expect(RotaryDial.turnsToStop(RotaryDial.tickToward(const Offset(0, -1))), closeTo(1 / 3, 0.06));
  });

  group('DialWinder', () {
    late List<Object?> ticks;
    late DialWinder winder;

    Future<void> host(WidgetTester tester) async {
      ticks = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') ticks.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_WinderHost(onReady: (DialWinder w) => winder = w));
    }

    testWidgets('the ring runs back with a haptic tick for every tick mark it passes', (WidgetTester tester) async {
      await host(tester);
      final double turns = RotaryDial.turnsToStop(RotaryDial.tickToward(const Offset(0, -1)));

      winder.wind(turns, still: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(winder.turns, greaterThan(0.2), reason: 'wound towards the stop');
      expect(ticks, isEmpty, reason: 'silent while winding');

      for (int frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(ticks, hasLength((turns / RotaryDial.tickTurns).floor()));
      expect(ticks.toSet(), <Object?>{'HapticFeedbackType.selectionClick'});
      expect(winder.turns, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('with reduced motion it only ticks once and does not turn', (WidgetTester tester) async {
      await host(tester);

      winder.wind(1, still: true);
      await tester.pump();

      expect(ticks, hasLength(1));
      expect(winder.turns, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
