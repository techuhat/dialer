import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class CallService {
  static const MethodChannel _roleChannel = MethodChannel('app.call_manager/role');
  static const MethodChannel _callChannel = MethodChannel('app.call_manager/call');

  static Future<bool> makeCall(String number) async {
    try {
      final result = await _roleChannel.invokeMethod('makeCall', {'number': number});
      return result == true;
    } catch (e) {
      developer.log('Error making call: $e', name: 'CallService');
      return false;
    }
  }

  static Future<bool> endCall() async {
    try {
      developer.log('Attempting to end call...', name: 'CallService');
      final result = await _roleChannel.invokeMethod('endCall');
      developer.log('End call result: $result', name: 'CallService');
      return result == true;
    } catch (e) {
      developer.log('Error ending call: $e', name: 'CallService');
      return false;
    }
  }

  static Future<bool> rejectCall() async {
    try {
      developer.log('Attempting to reject incoming call...', name: 'CallService');
      final result = await _roleChannel.invokeMethod('rejectCall');
      developer.log('Reject call result: $result', name: 'CallService');
      return result == true;
    } catch (e) {
      developer.log('Error rejecting call: $e', name: 'CallService');
      // Fallback to endCall if rejectCall is not implemented
      return await endCall();
    }
  }

  static Future<bool> answerCall() async {
    try {
      developer.log('Attempting to answer call...', name: 'CallService');
      final result = await _roleChannel.invokeMethod('answerCall');
      developer.log('Answer call result: $result', name: 'CallService');
      return result == true;
    } catch (e) {
      developer.log('Error answering call: $e', name: 'CallService');
      return false;
    }
  }

  static Future<bool> isDefaultDialer() async {
    try {
      final result = await _roleChannel.invokeMethod('isDefaultDialer');
      return result == true;
    } catch (e) {
      developer.log('Error checking default dialer: $e', name: 'CallService');
      return false;
    }
  }

  static Future<bool> requestDefaultDialer() async {
    try {
      final result = await _roleChannel.invokeMethod('requestDefaultDialer');
      return result == true;
    } catch (e) {
      developer.log('Error requesting default dialer: $e', name: 'CallService');
      return false;
    }
  }

  static void setCallEventHandler(Function(String method, dynamic arguments) handler) {
    _callChannel.setMethodCallHandler((call) async {
      handler(call.method, call.arguments);
    });
  }
}