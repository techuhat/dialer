import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndNavigate();
  }

  Future<void> _checkPermissionsAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    final bool phoneGranted = await Permission.phone.isGranted;
    final bool contactsGranted = await Permission.contacts.isGranted;
    if (!mounted) return;
    final String route = phoneGranted && contactsGranted ? '/home' : '/permission';
    await Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1C3A5E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon with glow
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.05),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        Icons.call,
                        size: 110,
                        color: const Color(0xFF42A5F5),
                        shadows: [
                          Shadow(
                            color: const Color(0xFF42A5F5),
                            blurRadius: 25,
                          ),
                          Shadow(
                            color: const Color(0xFF42A5F5),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Title text
              const Text(
                'Call Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              const Text(
                'Smart Dialer. Smarter Calls.',
                style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
