import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String channelId;
  final bool isCaller;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserRole; // 'doctor' or 'patient'

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.channelId,
    required this.isCaller,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserRole = 'doctor',
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  WebRTCService? _webrtcService;
  bool _hasRemoteStream = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _callEnded = false;

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  @override
  void dispose() {
    _webrtcService?.dispose();
    super.dispose();
  }

  Future<void> _initWebRTC() async {
    try {
      // 1. Real runtime permissions for Camera and Microphone
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'Camera and Microphone permissions are required for Video Consultations.';
          });
        }
        return;
      }

      // 2. Instantiate and initialize WebRTC Service
      final callRepo = ref.read(callRepositoryProvider);
      final service = WebRTCService(
        callRepository: callRepo,
        callId: widget.callId,
        isCaller: widget.isCaller,
      );

      service.onRemoteStreamStateChanged = (hasStream) {
        if (mounted) {
          setState(() {
            _hasRemoteStream = hasStream;
          });
        }
      };

      await service.initialize();

      if (mounted) {
        setState(() {
          _webrtcService = service;
          _isInitializing = false;
        });
      }
    } catch (e, st) {
      dev.log('[VIDEO_CALL ERROR] WebRTC init error: $e', error: e, stackTrace: st, name: 'VideoCallScreen');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to establish video connection: $e';
        });
      }
    }
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;

    try {
      await ref.read(callRepositoryProvider).endCall(widget.callId);
    } catch (e) {
      dev.log('[VIDEO_CALL] Note on endCall: $e', name: 'VideoCallScreen');
    }

    await _webrtcService?.dispose();

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    if (_webrtcService == null) return;
    _webrtcService!.toggleMic();
    setState(() {
      _isMuted = _webrtcService!.isMuted;
    });
  }

  void _toggleVideo() {
    if (_webrtcService == null) return;
    _webrtcService!.toggleCamera();
    setState(() {
      _isVideoOff = _webrtcService!.isVideoOff;
    });
  }

  Future<void> _switchCamera() async {
    if (_webrtcService == null) return;
    await _webrtcService!.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to call status from Firestore to react when other participant hangs up
    ref.listen(callStreamProvider(widget.callId), (prev, next) {
      final call = next.valueOrNull;
      if (call != null && (call.isEnded || call.isRejected) && !_callEnded) {
        _callEnded = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(call.isRejected ? 'Call declined' : 'Consultation ended'),
              backgroundColor: AppColors.slate,
              duration: const Duration(seconds: 2),
            ),
          );
          final nav = Navigator.of(context);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && nav.canPop()) {
              nav.pop();
            }
          });
        }
      }
    });

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryBlue),
              const SizedBox(height: 24),
              Text(
                'Starting secure clinical video consultation...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting with ${widget.otherUserName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.alertTriangle, color: AppColors.danger, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Consultation Setup Failed',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.arrowLeft, size: 16),
                  label: const Text('Return to Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // 1. Remote Video Stream or Waiting Screen
          Positioned.fill(
            child: _hasRemoteStream && _webrtcService != null
                ? RTCVideoView(
                    _webrtcService!.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : _buildWaitingView(),
          ),

          // 2. Top Bar: Participant Info & Encryption Badge
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                      backgroundImage: (widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty)
                          ? NetworkImage(widget.otherUserAvatar!)
                          : null,
                      child: (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty)
                          ? Text(
                              widget.otherUserName.isNotEmpty ? widget.otherUserName[0] : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _hasRemoteStream ? AppColors.success : AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _hasRemoteStream ? 'Encrypted Video Connected' : 'Waiting for connection...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'P2P Encrypted',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Local Camera Preview (Picture-in-Picture)
          Positioned(
            right: 16,
            top: 96,
            width: 110,
            height: 155,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFF1E293B),
                child: Stack(
                  children: [
                    if (_webrtcService != null && !_isVideoOff)
                      RTCVideoView(
                        _webrtcService!.localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    else
                      const Center(
                        child: Icon(LucideIcons.videoOff, color: Colors.white54, size: 28),
                      ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Controls Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute
                    _buildControlButton(
                      icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      activeColor: AppColors.danger,
                      onTap: _toggleMute,
                    ),

                    // Video On / Off
                    _buildControlButton(
                      icon: _isVideoOff ? LucideIcons.videoOff : LucideIcons.video,
                      label: _isVideoOff ? 'Start Video' : 'Stop Video',
                      isActive: _isVideoOff,
                      activeColor: AppColors.warning,
                      onTap: _toggleVideo,
                    ),

                    // Flip Camera
                    _buildControlButton(
                      icon: LucideIcons.refreshCw,
                      label: 'Flip',
                      isActive: false,
                      onTap: _switchCamera,
                    ),

                    // End Call
                    _buildControlButton(
                      icon: LucideIcons.phoneOff,
                      label: 'End',
                      isActive: true,
                      activeColor: AppColors.danger,
                      isEndCall: true,
                      onTap: _endCall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
              backgroundImage: (widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty)
                  ? NetworkImage(widget.otherUserAvatar!)
                  : null,
              child: (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty)
                  ? Text(
                      widget.otherUserName.isNotEmpty ? widget.otherUserName[0] : 'U',
                      style: const TextStyle(color: AppColors.primaryBlue, fontSize: 32, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.isCaller ? 'Calling clinical participant...' : 'Connecting consultation...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    bool isEndCall = false,
    required VoidCallback onTap,
  }) {
    final bgColor = isEndCall
        ? AppColors.danger
        : (isActive ? (activeColor ?? AppColors.primaryBlue) : Colors.white.withValues(alpha: 0.2));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bgColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(isEndCall ? 18.0 : 14.0),
              child: Icon(
                icon,
                color: Colors.white,
                size: isEndCall ? 26 : 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
