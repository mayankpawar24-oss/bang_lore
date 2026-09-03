import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/providers/providers.dart';

class AppOpeningScreen extends ConsumerStatefulWidget {
  const AppOpeningScreen({super.key});

  @override
  ConsumerState<AppOpeningScreen> createState() => _AppOpeningScreenState();
}

class _AppOpeningScreenState extends ConsumerState<AppOpeningScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasNavigated = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/video/intro.mp4');
      await _controller.initialize();
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
      _controller.setLooping(false);
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
      }

      _controller.addListener(() {
        if (!mounted || _hasNavigated) return;
        final position = _controller.value.position;
        final duration = _controller.value.duration;
        // Auto proceed when video completes
        if (duration > Duration.zero && position >= duration) {
          _proceed();
        }
      });
    } catch (_) {
      // Fallback: If video player is unavailable on this device/simulator/test, proceed after delay or user tap
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && !_hasNavigated) _proceed();
      });
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isInitialized) {
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
      }
    });
  }

  void _proceed() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      final role = authState.user?.role;
      if (role == UserRole.doctor) {
        context.go('/doctor/dashboard');
      } else {
        context.go('/patient/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video or Gradient Fallback
          if (_isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E3A8A),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),

          // Vignette Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.50),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.70),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Top Bar: Brand Mark + Audio Toggle & Skip
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.blueToIndigo,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.activity, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ardius Care',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_isInitialized)
                        IconButton(
                          onPressed: _toggleMute,
                          icon: Icon(
                            _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: _isMuted ? 'Unmute' : 'Mute',
                        ),
                      TextButton(
                        onPressed: _proceed,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar: Narrative Tagline + "Get Started" Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Continuous, Connected Healthcare',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI-coordinated post-discharge recovery and proactive specialist care.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _proceed,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            color: Color(0xFF0B0C0E),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: Color(0xFF0B0C0E),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
