import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/providers.dart';
import '../screens/video_call_screen.dart';

class IncomingCallListener extends ConsumerWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingCallAsync = ref.watch(incomingCallStreamProvider);
    final incomingCall = incomingCallAsync.valueOrNull;

    return Stack(
      children: [
        child,
        if (incomingCall != null && incomingCall.isRinging)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(LucideIcons.video, size: 14, color: AppColors.primaryBlue),
                                SizedBox(width: 6),
                                Text(
                                  'INCOMING VIDEO CALL',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                            backgroundImage: (incomingCall.callerPhoto != null && incomingCall.callerPhoto!.isNotEmpty)
                                ? NetworkImage(incomingCall.callerPhoto!)
                                : null,
                            child: (incomingCall.callerPhoto == null || incomingCall.callerPhoto!.isEmpty)
                                ? Text(
                                    incomingCall.callerName.isNotEmpty ? incomingCall.callerName[0] : 'C',
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            incomingCall.callerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            incomingCall.callerRole == 'doctor' ? 'Doctor Consultation Call' : 'Patient Video Call',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Decline Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.danger,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(LucideIcons.phoneOff, size: 18),
                                  label: const Text(
                                    'Decline',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  onPressed: () async {
                                    await ref.read(callRepositoryProvider).rejectCall(incomingCall.id);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Accept Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(LucideIcons.phoneCall, size: 18),
                                  label: const Text(
                                    'Accept',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  onPressed: () async {
                                    await ref.read(callRepositoryProvider).acceptCall(incomingCall.id);
                                    if (context.mounted) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => VideoCallScreen(
                                            callId: incomingCall.id,
                                            channelId: incomingCall.channelId,
                                            isCaller: false,
                                            otherUserName: incomingCall.callerName,
                                            otherUserAvatar: incomingCall.callerPhoto,
                                            otherUserRole: incomingCall.callerRole,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
