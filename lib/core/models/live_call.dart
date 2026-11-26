import 'package:flutter/foundation.dart';

import '../utils/format_utils.dart';

enum CallPhase { ringing, dialing, selectSim, active, holding, disconnecting, disconnected }

/// One call as reported by the native InCallService (`callsChanged`).
@immutable
class LiveCall {
  const LiveCall({
    required this.id,
    required this.number,
    required this.phase,
    this.name,
    this.isNetworkName = false,
    this.isIncoming = false,
    this.connectedAt,
    this.canHold = false,
    this.canMerge = false,
    this.canSwap = false,
    this.isConference = false,
    this.isHd = false,
    this.isWifi = false,
    this.simSlot,
    this.carrier,
  });

  factory LiveCall.fromMap(Map<Object?, Object?> map) {
    final int? connectedAt = (map['connectedAt'] as num?)?.toInt();
    return LiveCall(
      id: map['id'] as String? ?? '',
      number: map['number'] as String? ?? '',
      name: map['name'] as String?,
      isNetworkName: map['nameSource'] == 'network',
      phase: CallPhase.values.asNameMap()[map['state']] ?? CallPhase.disconnected,
      isIncoming: map['incoming'] == true,
      connectedAt: connectedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(connectedAt),
      canHold: map['canHold'] == true,
      canMerge: map['canMerge'] == true,
      canSwap: map['canSwap'] == true,
      isConference: map['conference'] == true,
      isHd: map['hd'] == true,
      isWifi: map['wifi'] == true,
      simSlot: (map['simSlot'] as num?)?.toInt(),
      carrier: map['carrier'] as String?,
    );
  }

  final String id;
  final String number;
  final String? name;

  /// The name is the network's caller ID (CNAP), not a saved contact.
  final bool isNetworkName;
  final CallPhase phase;
  final bool isIncoming;
  final DateTime? connectedAt;
  final bool canHold;
  final bool canMerge;
  final bool canSwap;
  final bool isConference;
  final bool isHd;
  final bool isWifi;
  final int? simSlot;
  final String? carrier;

  bool get isRinging => phase == CallPhase.ringing;
  bool get isActive => phase == CallPhase.active;
  bool get isHeld => phase == CallPhase.holding;
  bool get isConnecting => phase == CallPhase.dialing || phase == CallPhase.selectSim;

  String get displayName {
    if (isConference) return 'Conference call';
    final String? trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return number.isEmpty ? 'Unknown' : PhoneUtils.formatPhoneNumber(number);
  }

  /// `SIM 2 · Jio`; null on single-SIM phones (native only sends a slot when there are two).
  String? get simLabel => simSlot == null ? null : <String>['SIM ${simSlot! + 1}', ?carrier].join(' · ');

  @override
  bool operator ==(Object other) =>
      other is LiveCall &&
      other.id == id &&
      other.number == number &&
      other.name == name &&
      other.isNetworkName == isNetworkName &&
      other.phase == phase &&
      other.connectedAt == connectedAt &&
      other.canHold == canHold &&
      other.canMerge == canMerge &&
      other.canSwap == canSwap &&
      other.isConference == isConference &&
      other.isHd == isHd &&
      other.isWifi == isWifi &&
      other.simSlot == simSlot &&
      other.carrier == carrier;

  @override
  int get hashCode => Object.hash(id, number, name, isNetworkName, phase, connectedAt, canHold, canMerge, canSwap,
      isConference, isHd, isWifi, simSlot, carrier);
}

/// Audio route and mute state of the current call.
@immutable
class CallAudio {
  const CallAudio({
    this.route = earpiece,
    this.routes = const <String>[earpiece, speaker],
    this.isMuted = false,
    this.bluetoothName,
  });

  factory CallAudio.fromMap(Map<Object?, Object?> map) => CallAudio(
        route: map['route'] as String? ?? earpiece,
        routes: (map['routes'] as List<Object?>?)?.whereType<String>().toList(growable: false) ??
            const <String>[earpiece, speaker],
        isMuted: map['muted'] == true,
        bluetoothName: map['bluetoothName'] as String?,
      );

  static const String earpiece = 'earpiece';
  static const String speaker = 'speaker';
  static const String wired = 'wired';
  static const String bluetooth = 'bluetooth';

  final String route;
  final List<String> routes;
  final bool isMuted;
  final String? bluetoothName;

  bool get isSpeaker => route == speaker;

  /// With a headset or Bluetooth device the stock dialer shows a route picker instead of a toggle.
  bool get hasRouteChoice => routes.contains(bluetooth) || routes.contains(wired);

  CallAudio copyWith({String? route, bool? isMuted}) => CallAudio(
        route: route ?? this.route,
        routes: routes,
        isMuted: isMuted ?? this.isMuted,
        bluetoothName: bluetoothName,
      );

  @override
  bool operator ==(Object other) =>
      other is CallAudio &&
      other.route == route &&
      listEquals(other.routes, routes) &&
      other.isMuted == isMuted &&
      other.bluetoothName == bluetoothName;

  @override
  int get hashCode => Object.hash(route, Object.hashAll(routes), isMuted, bluetoothName);
}

/// The call that just ended, shown briefly as "Call ended" before leaving the call screen.
@immutable
class EndedCall {
  const EndedCall({required this.number, this.name, this.duration});

  final String number;
  final String? name;
  final Duration? duration;
}
