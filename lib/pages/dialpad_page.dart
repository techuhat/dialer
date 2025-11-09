import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../core/call_service.dart';
import 'active_call_screen.dart';

class DialpadPage extends StatefulWidget {
  const DialpadPage({super.key});

  @override
  State<DialpadPage> createState() => _DialpadPageState();
}

class _DialpadPageState extends State<DialpadPage> {
  static const LinearGradient _backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1929), Color(0xFF1C3A5E)],
  );

  static const List<_DialKey> _dialKeys = <_DialKey>[
    _DialKey(label: '1'),
    _DialKey(label: '2', secondary: 'ABC'),
    _DialKey(label: '3', secondary: 'DEF'),
    _DialKey(label: '4', secondary: 'GHI'),
    _DialKey(label: '5', secondary: 'JKL'),
    _DialKey(label: '6', secondary: 'MNO'),
    _DialKey(label: '7', secondary: 'PQRS'),
    _DialKey(label: '8', secondary: 'TUV'),
    _DialKey(label: '9', secondary: 'WXYZ'),
    _DialKey(label: '*'),
    _DialKey(label: '0', secondary: '+'),
    _DialKey(label: '#'),
  ];

  String _input = '';

  void _appendValue(String value) {
    setState(() {
      _input = '$_input$value';
    });
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
    });
  }

  Future<void> _onCallPressed() async {
    if (_input.isEmpty) return;
    
    debugPrint('Initiate call for $_input');
    
    try {
      // Use CallService to make call (integrates with our dialer system)
      final bool success = await CallService.makeCall(_input);
      
      if (success) {
        // Navigate to active call screen for UI
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/active',
            (Route<dynamic> route) => route.settings.name == '/home',
            arguments: ActiveCallArguments(
              number: _input,
              caller: null,
              isDialing: true,
            ),
          );
        }
      } else {
        throw Exception('Call method returned false');
      }
    } on PlatformException catch (e) {
      debugPrint('Platform exception making call: ${e.message}');
      
      // Fallback to direct caller
      try {
        await FlutterPhoneDirectCaller.callNumber(_input);
      } catch (fallbackError) {
        debugPrint('Fallback call also failed: $fallbackError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to make call: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error making call: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Dialpad',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ) ??
                                      const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                                  child: Text(_input.isEmpty ? 'Enter number' : _input),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _input.isEmpty ? 'Tap numbers to begin a call' : 'Ready to connect',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF90B0CB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _onBackspace,
                            splashRadius: 24,
                            icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 26),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int row = 0; row < 4; row++)
                        Padding(
                          padding: EdgeInsets.only(bottom: row == 3 ? 0 : 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(3, (int column) {
                              final int index = row * 3 + column;
                              final _DialKey key = _dialKeys[index];
                              return _DialButton(
                                keyData: key,
                                onPressed: () => _appendValue(key.label),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: FilledButton.icon(
                  onPressed: _input.isEmpty ? null : _onCallPressed,
                  icon: const Icon(Icons.call, size: 22),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialButton extends StatelessWidget {
  const _DialButton({required this.keyData, required this.onPressed});

  final _DialKey keyData;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(48),
      splashColor: const Color(0xFF42A5F5).withOpacity(0.3),
      child: Container(
        height: 76,
        width: 76,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              keyData.label,
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (keyData.secondary != null) ...[
              const SizedBox(height: 4),
              Text(
                keyData.secondary!,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF90B0CB),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialKey {
  const _DialKey({required this.label, this.secondary});

  final String label;
  final String? secondary;
}
