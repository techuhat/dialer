import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class CallService {
  static const MethodChannel _channel = MethodChannel('com.example.umar_dailer/calls');

  /// Makes a call to the specified number
  static Future<bool> makeCall(String number) async {
    try {
      final bool result = await _channel.invokeMethod('makeCall', {'number': number});
      return result;
    } on PlatformException catch (e) {
      developer.log('Error making call: $e', name: 'CallService');
      return false;
    } catch (e) {
      developer.log('Unexpected error making call: $e', name: 'CallService');
      return false;
    }
  }

  /// Ends the current call
  static Future<bool> endCall() async {
    try {
      final bool result = await _channel.invokeMethod('endCall');
      return result;
    } on PlatformException catch (e) {
      developer.log('Error ending call: $e', name: 'CallService');
      return false;
    } catch (e) {
      developer.log('Unexpected error ending call: $e', name: 'CallService');
      return false;
    }
  }

  /// Rejects an incoming call
  static Future<bool> rejectCall() async {
    try {
      final bool result = await _channel.invokeMethod('rejectCall');
      return result;
    } on PlatformException catch (e) {
      developer.log('Error rejecting call: $e', name: 'CallService');
      return false;
    } catch (e) {
      developer.log('Unexpected error rejecting call: $e', name: 'CallService');
      return false;
    }
  }

  /// Answers an incoming call
  static Future<bool> answerCall() async {
    try {
      final bool result = await _channel.invokeMethod('answerCall');
      return result;
    } on PlatformException catch (e) {
      developer.log('Error answering call: $e', name: 'CallService');
      return false;
    } catch (e) {
      developer.log('Unexpected error answering call: $e', name: 'CallService');
      return false;
    }
  }
}