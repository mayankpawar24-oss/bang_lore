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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // TOP: Skip Button in Top-Right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
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
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // CENTER: Brand Icon + App Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.blueToIndigo,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.activity, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continuum Health',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Supporting Visual / Video Area with AspectRatio
                  Expanded(
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _isInitialized
                              ? AspectRatio(
                                  aspectRatio: _controller.value.aspectRatio > 0
                                      ? _controller.value.aspectRatio
                                      : 16 / 9,
                                  child: VideoPlayer(_controller),
                                )
                              : Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(LucideIcons.heartPulse, size: 64, color: AppColors.primaryBlue),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BOTTOM: Headline, Description & Get Started Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Continuous, Connected Healthcare',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI-coordinated proactive care, family health circles, and instant specialist consultations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                                color: Colors.white.withValues(alpha: 0.2),
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
                                  color: Color(0xFF070B14),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                LucideIcons.arrowRight,
                                size: 18,
                                color: Color(0xFF070B14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
