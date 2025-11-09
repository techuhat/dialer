import 'dart:developer' as developer;

import '../models/call_log_entry.dart';
import 'call_log_service.dart';
import 'contacts_service.dart';

class CallEventHandler {
  static String? _currentCallNumber;
  static DateTime? _callStartTime;
  static CallType? _currentCallType;
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    developer.log('CallEventHandler initialized', name: 'CallEventHandler');
  }

  static Future<void> handleEvent(String method, Map<String, dynamic> payload) async {
    if (!_isInitialized) {
      initialize();
    }

    try {
      final String number = (payload['number'] as String?)?.trim() ?? 'Unknown';
      developer.log('Call event: $method, number: $number', name: 'CallEventHandler');

      switch (method) {
        case 'incomingCall':
          await _handleIncomingCall(number);
          break;
        case 'incomingCallConnected':
          await _handleIncomingCallConnected(number);
          break;
        case 'outgoingCall':
          await _handleOutgoingCall(number);
          break;
        case 'outgoingCallConnected':
          await _handleOutgoingCallConnected(number);
          break;
        case 'callEnded':
          await _handleCallEnded();
          break;
      }
    } catch (e) {
      developer.log('Error handling call event: $e', name: 'CallEventHandler', error: e);
    }
  }

  static Future<void> _handleIncomingCall(String number) async {
    _currentCallNumber = number;
    _callStartTime = DateTime.now();
    _currentCallType = CallType.incoming;
    developer.log('Incoming call from: $number', name: 'CallEventHandler');
  }

  static Future<void> _handleOutgoingCall(String number) async {
    _currentCallNumber = number;
    _callStartTime = DateTime.now();
    _currentCallType = CallType.outgoing;
    developer.log('Outgoing call to: $number', name: 'CallEventHandler');
  }

  static Future<void> _handleIncomingCallConnected(String number) async {
    if (_currentCallNumber == number && _currentCallType == CallType.incoming) {
      _callStartTime = DateTime.now();
      developer.log('Incoming call connected: $number', name: 'CallEventHandler');
    }
  }

  static Future<void> _handleOutgoingCallConnected(String number) async {
    if (_currentCallNumber == number && _currentCallType == CallType.outgoing) {
      _callStartTime = DateTime.now();
      developer.log('Outgoing call connected to: $number, updated start time', name: 'CallEventHandler');
    }
  }

  static Future<void> _handleCallEnded() async {
    if (_currentCallNumber == null || _callStartTime == null || _currentCallType == null) {
      developer.log('Call ended but no active call tracked', name: 'CallEventHandler');
      return;
    }

    final callNumber = _currentCallNumber!;
    final callStartTime = _callStartTime!;
    final callType = _currentCallType!;

    // Reset before processing to avoid duplicate handling
    _currentCallNumber = null;
    _callStartTime = null;
    _currentCallType = null;

    try {
      final endTime = DateTime.now();
      final duration = endTime.difference(callStartTime).inSeconds;

      final isMissed = callType == CallType.incoming && duration < 3;
      final actualType = isMissed ? CallType.missed : callType;

      String? contactName;
      try {
        if (await ContactsService.hasPermission()) {
          final contact = await ContactsService.getContactByNumber(callNumber);
          contactName = contact?.displayName;
        }
      } catch (e) {
        developer.log('Error fetching contact: $e', name: 'CallEventHandler');
      }

      final callLog = CallLogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        number: callNumber,
        name: contactName ?? callNumber,
        type: actualType,
        timestamp: callStartTime,
        duration: isMissed ? 0 : (duration > 0 ? duration : 1),
        isRead: actualType != CallType.missed,
      );

      await CallLogService.addCallLog(callLog);

      developer.log(
        'Call log saved: ${callLog.displayName}, type: ${actualType.name}, duration: ${callLog.duration} seconds',
        name: 'CallEventHandler',
      );
    } catch (e) {
      developer.log('Error saving call log: $e', name: 'CallEventHandler', error: e);
    }
  }

  static void dispose() {
    _isInitialized = false;
    _currentCallNumber = null;
    _callStartTime = null;
    _currentCallType = null;
  }
}
