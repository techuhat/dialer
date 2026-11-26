import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_service.dart';
import 'services/sim_service.dart';
import 'utils/format_utils.dart';
import 'widgets/feedback.dart';

/// The one way pages start a call: SIM choice, MMI codes and the failure message included.
/// The call screen itself opens from the native `outgoingCall` event.
class CallLauncher {
  const CallLauncher._();

  static Future<bool> dial(BuildContext context, String number) async {
    if (number.trim().isEmpty) return false;
    HapticFeedback.selectionClick();
    final int? simSlot = await SimService.pickSimForCall(context, number: number);
    if (simSlot == null) return false;
    final bool isCode = PhoneUtils.isMmiCode(number);
    final bool ok = isCode
        ? await CallService.sendMmi(number, simSlot: simSlot)
        : await CallService.makeCall(number, simSlot: simSlot);
    if (!ok && context.mounted) showToast(context, isCode ? "Couldn't run $number" : "Couldn't place the call");
    return ok;
  }

  static Future<void> message(BuildContext context, String number) async {
    if (!await CallService.composeSms(number) && context.mounted) showToast(context, 'No messaging app found');
  }

  static Future<void> copyNumber(BuildContext context, String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) showToast(context, 'Number copied');
  }
}
