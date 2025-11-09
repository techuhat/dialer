import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../core/call_service.dart';


const Color _gradientStart = Color(0xFF0A1929);
const Color _gradientEnd = Color(0xFF1C3A5E);
const Color _primaryBlue = Color(0xFF42A5F5);

class ActiveCallArguments {
  const ActiveCallArguments({
    required this.number,
    this.caller,
    this.isDialing = false,
  });

  final String number;
  final String? caller;
  final bool isDialing;
}

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({
    required this.number,
    this.caller,
    this.isDialing = false,
    super.key,
  });

  final String number;
  final String? caller;
  final bool isDialing;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isOnHold = false;
  bool _isRecording = false;
  
  late AnimationController _statusAnimationController;
  late Animation<double> _statusOpacityAnimation;
  late AnimationController _avatarAnimationController;
  late Animation<double> _avatarScaleAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = !widget.isDialing;
    
    // Initialize animations
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _statusOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statusAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _avatarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _avatarScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _avatarAnimationController,
      curve: Curves.elasticOut,
    ));
    
    // Pulse animation for dialing state
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _statusAnimationController.forward();
    _avatarAnimationController.forward();
    
    // Start pulse animation for dialing state
    if (widget.isDialing) {
      _pulseAnimationController.repeat(reverse: true);
    }
    
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant ActiveCallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDialing && !widget.isDialing) {
      // Smooth transition from dialing to connected
      _transitionToConnected();
    }
  }
  
  void _transitionToConnected() async {
    setState(() {
      _isConnected = true;
    });
    
    // Add haptic feedback when call connects
    try {
      // Gentle vibration to indicate call connection
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 100, amplitude: 128);
      }
      // Also add system haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      // Ignore vibration errors
      debugPrint('Vibration not available: $e');
    }
    
    // Stop pulse animation and restart others for connected state
    _pulseAnimationController.stop();
    _pulseAnimationController.reset();
    
    _statusAnimationController.reset();
    _statusAnimationController.forward();
    
    _avatarAnimationController.reset();
    _avatarAnimationController.forward();
    
    _maybeStartTimer(forceRestart: true);
  }

  void _maybeStartTimer({bool forceRestart = false}) {
    if (widget.isDialing && !forceRestart) {
      return;
    }
    if (_timer != null && !forceRestart) {
      return;
    }
    _timer?.cancel();
    if (forceRestart || _elapsed != Duration.zero) {
      setState(() {
        _elapsed = Duration.zero;
      });
    } else {
      _elapsed = Duration.zero;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusAnimationController.dispose();
    _avatarAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final int minutes = _elapsed.inMinutes.remainder(60);
    final int seconds = _elapsed.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                _buildCallMetadata(),
                _buildControls(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return FadeTransition(
      opacity: _statusOpacityAnimation,
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, -0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              (_isConnected || !widget.isDialing) ? 'Ongoing Call' : 'Dialing…',
              key: ValueKey((_isConnected || !widget.isDialing) ? 'ongoing' : 'dialing'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.caller ?? widget.number,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.number,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: (_isConnected || !widget.isDialing) 
                  ? _primaryBlue.withOpacity(0.2)
                  : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: (_isConnected || !widget.isDialing) 
                  ? Text(
                      _elapsedLabel,
                      key: const ValueKey('timer'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : _ConnectingDotsAnimation(
                      key: const ValueKey('connecting'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallMetadata() {
    return Column(
      children: <Widget>[
        ScaleTransition(
          scale: _avatarScaleAnimation,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (_isConnected || !widget.isDialing)
                          ? _primaryBlue.withOpacity(0.5)
                          : _primaryBlue.withOpacity(0.35),
                      blurRadius: (_isConnected || !widget.isDialing) 
                          ? 35 
                          : (widget.isDialing ? 30 * _pulseAnimation.value : 30),
                      spreadRadius: (_isConnected || !widget.isDialing) 
                          ? 4 
                          : (widget.isDialing ? 3 * _pulseAnimation.value : 3),
                    ),
                    // Additional pulse ring for dialing state
                    if (widget.isDialing && !_isConnected)
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.2),
                        blurRadius: 50 * _pulseAnimation.value,
                        spreadRadius: 8 * _pulseAnimation.value,
                      ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  (widget.caller ?? widget.number).isNotEmpty
                      ? (widget.caller ?? widget.number)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            (_isConnected || !widget.isDialing) 
                ? 'Secure connection established' 
                : 'Establishing connection…',
            key: ValueKey((_isConnected || !widget.isDialing) ? 'connected' : 'connecting'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: (_isConnected || !widget.isDialing) 
                  ? Colors.greenAccent.withOpacity(0.8)
                  : Colors.white70,
              fontWeight: (_isConnected || !widget.isDialing) 
                  ? FontWeight.w600 
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _ControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              isActive: _isMuted,
              onTap: () => setState(() => _isMuted = !_isMuted),
            ),
            _ControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              isActive: _isSpeakerOn,
              onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
            ),
            _ControlButton(
              icon: _isOnHold ? Icons.play_circle : Icons.pause_circle_filled,
              label: _isOnHold ? 'Resume' : 'Hold',
              isActive: _isOnHold,
              onTap: () => setState(() => _isOnHold = !_isOnHold),
            ),
            _ControlButton(
              icon: Icons.fiber_manual_record,
              label: 'Record',
              isActive: _isRecording,
              activeColor: Colors.redAccent,
              onTap: () => setState(() => _isRecording = !_isRecording),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 80,
          width: 80,
          child: FloatingActionButton(
            heroTag: 'end_call',
            backgroundColor: const Color(0xFFE53935),
            onPressed: () async {
              // Add haptic feedback for end call
              HapticFeedback.heavyImpact();
              
              // End the actual call
              final success = await CallService.endCall();
              if (success) {
                // Navigate back to home
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (Route<dynamic> route) => false,
                  );
                }
              } else {
                // Even if ending the call failed, still navigate back
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (Route<dynamic> route) => false,
                  );
                }
                // Show error message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to end call properly'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor = _primaryBlue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isActive ? Colors.white : Colors.white70;
    final Color backgroundColor = isActive ? activeColor : Colors.white.withOpacity(0.1);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: <Widget>[
          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                if (isActive)
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectingDotsAnimation extends StatefulWidget {
  const _ConnectingDotsAnimation({super.key});

  @override
  State<_ConnectingDotsAnimation> createState() => _ConnectingDotsAnimationState();
}

class _ConnectingDotsAnimationState extends State<_ConnectingDotsAnimation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.2,
          0.6 + (index * 0.2),
          curve: Curves.easeInOut,
        ),
      ));
    });

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Connecting',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _dotAnimations[index],
                  builder: (context, child) {
                    return Opacity(
                      opacity: _dotAnimations[index].value,
                      child: const Text(
                        '•',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
