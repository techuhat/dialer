import 'package:flutter/material.dart';

class ActivePage extends StatefulWidget {
  const ActivePage({super.key});

  @override
  State<ActivePage> createState() => _ActivePageState();
}

class _ActivePageState extends State<ActivePage> {
  // TODO: Add active call state
  // String? _phoneNumber;
  // String? _contactName;
  // Duration _callDuration = Duration.zero;
  // bool _isMuted = false;
  // bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    // TODO: Start call duration timer
    // _startCallTimer();
  }

  // TODO: Implement call duration timer
  // void _startCallTimer() {
  //   // Update call duration every second
  // }

  // TODO: Implement mute toggle
  // void _toggleMute() {
  //   setState(() {
  //     _isMuted = !_isMuted;
  //   });
  //   // Apply mute through CallManager
  // }

  // TODO: Implement speaker toggle
  // void _toggleSpeaker() {
  //   setState(() {
  //     _isSpeakerOn = !_isSpeakerOn;
  //   });
  //   // Apply speaker mode through CallManager
  // }

  // TODO: Implement end call handler
  // void _endCall() {
  //   // End the active call
  //   // Navigate to SummaryPage with call details
  //   Navigator.pushReplacementNamed(context, '/summary');
  // }

  @override
  void dispose() {
    // TODO: Clean up timer and resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: UI will be implemented by developer
    return const Scaffold(
      body: Center(
        child: Text('Active Call Page - UI to be implemented'),
      ),
    );
  }
}
