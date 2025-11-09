 import 'package:flutter/material.dart';

import '../core/call_service.dart';
import 'active_call_screen.dart';

const Color _gradientStart = Color(0xFF0A1929);
const Color _gradientEnd = Color(0xFF1C3A5E);
const Color _primaryBlue = Color(0xFF42A5F5);

class IncomingCallArguments {
  const IncomingCallArguments({
    required this.number,
    this.caller,
  });

  final String number;
  final String? caller;
}

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({
    required this.number,
    this.caller,
    super.key,
  });

  final String number;
  final String? caller;

  @override
  Widget build(BuildContext context) {
    final String resolvedCaller = caller ?? number;
    final String displayNumber = number;

    return Scaffold(
      backgroundColor: _gradientStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_gradientStart, _gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildHeader(context),
                _buildCallerInfo(resolvedCaller, displayNumber),
                _buildActions(context, resolvedCaller, displayNumber),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'Incoming Call',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'Inter',
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Swipe or tap to manage the call',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                color: Colors.white70,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Widget _buildCallerInfo(String resolvedCaller, String displayNumber) {
    return Column(
      children: <Widget>[
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _primaryBlue.withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            resolvedCaller.isNotEmpty ? resolvedCaller[0].toUpperCase() : '?',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          resolvedCaller,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayNumber,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    String resolvedCaller,
    String displayNumber,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _ActionButton(
          label: 'Decline',
          icon: Icons.call_end,
          backgroundColor: const Color(0xFFE53935),
          onTap: () async {
            try {
              // Immediately navigate to home for better user feedback
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (Route<dynamic> route) => false,
                );
              }
              
              // Then attempt to reject the incoming call
              await CallService.rejectCall();
              // Note: Call result logged in CallService
              
              // If call rejection failed, still stay on home screen
              // The user sees immediate feedback regardless
              
            } catch (e) {
              // Note: Error logged in CallService
              // Even if there's an error, ensure we're on home screen
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (Route<dynamic> route) => false,
                );
              }
            }
          },
        ),
        _ActionButton(
          label: 'Answer',
          icon: Icons.call,
          backgroundColor: const Color(0xFF2E7D32),
          onTap: () async {
            final answered = await CallService.answerCall();
            if (!context.mounted) return;

            Navigator.of(context).pushNamedAndRemoveUntil(
              '/active',
              (Route<dynamic> route) => route.settings.name == '/home' || route.isFirst,
              arguments: ActiveCallArguments(
                caller: resolvedCaller,
                number: displayNumber,
                isDialing: !answered,
              ),
            );

            if (!answered) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to answer call automatically. Showing call screen.'),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 84,
            width: 84,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: backgroundColor.withOpacity(0.35),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
