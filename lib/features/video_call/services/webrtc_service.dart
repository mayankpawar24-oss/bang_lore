import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../data/repositories/call_repository.dart';

class WebRTCService {
  final CallRepository callRepository;
  final String callId;
  final bool isCaller;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  StreamSubscription? _callSubscription;
  StreamSubscription? _candidateSubscription;
  final Set<String> _processedCandidateIds = {};
  bool _hasSetRemoteDescription = false;
  bool _isDisposed = false;

  bool isMuted = false;
  bool isVideoOff = false;

  void Function(bool hasRemoteStream)? onRemoteStreamStateChanged;

  WebRTCService({
    required this.callRepository,
    required this.callId,
    required this.isCaller,
  });

  Future<void> initialize() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();

      // 1. Get local user media (camera & microphone)
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'optional': [],
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;

      // 2. Setup RTCPeerConnection with standard Google STUN servers
      final Map<String, dynamic> rtcConfig = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(rtcConfig);

      // 3. Add tracks to peer connection
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // 4. Remote stream track handler
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        dev.log('[WEBRTC] Remote track received: ${event.track.kind}', name: 'WebRTCService');
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          onRemoteStreamStateChanged?.call(true);
        }
      };

      // 5. ICE candidate generation handler
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null || _isDisposed) return;
        final candData = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };

        if (isCaller) {
          callRepository.addCallerCandidate(callId, candData);
        } else {
          callRepository.addReceiverCandidate(callId, candData);
        }
      };

      // 6. Signaling Flow
      if (isCaller) {
        await _initiateCallerFlow();
      } else {
        await _initiateReceiverFlow();
      }
    } catch (e, st) {
      dev.log('[WEBRTC ERROR] Initialization failed: $e', error: e, stackTrace: st, name: 'WebRTCService');
      rethrow;
    }
  }

  Future<void> _initiateCallerFlow() async {
    // Create and save Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await _peerConnection!.setLocalDescription(offer);
    await callRepository.setOffer(callId, {
      'type': offer.type,
      'sdp': offer.sdp,
    });
    dev.log('[WEBRTC] Caller created & set local offer', name: 'WebRTCService');

    // Listen for Answer
    _callSubscription = callRepository.streamCall(callId).listen((call) async {
      if (_isDisposed || call == null) return;
      if (call.answer != null && !_hasSetRemoteDescription) {
        _hasSetRemoteDescription = true;
        final answer = RTCSessionDescription(
          call.answer!['sdp'] as String?,
          call.answer!['type'] as String?,
        );
        await _peerConnection?.setRemoteDescription(answer);
        dev.log('[WEBRTC] Caller set remote description from Answer', name: 'WebRTCService');
      }
    });

    // Listen for Receiver candidates
    _candidateSubscription = callRepository.streamReceiverCandidates(callId).listen((candidates) async {
      if (_isDisposed) return;
      for (var cand in candidates) {
        final id = cand['id'] as String?;
        if (id != null && !_processedCandidateIds.contains(id)) {
          _processedCandidateIds.add(id);
          final candidate = RTCIceCandidate(
            cand['candidate'] as String?,
            cand['sdpMid'] as String?,
            cand['sdpMLineIndex'] as int?,
          );
          await _peerConnection?.addCandidate(candidate);
        }
      }
    });
  }

  Future<void> _initiateReceiverFlow() async {
    // Listen for Offer
    _callSubscription = callRepository.streamCall(callId).listen((call) async {
      if (_isDisposed || call == null) return;
      if (call.offer != null && !_hasSetRemoteDescription) {
        _hasSetRemoteDescription = true;
        final offer = RTCSessionDescription(
          call.offer!['sdp'] as String?,
          call.offer!['type'] as String?,
        );
        await _peerConnection?.setRemoteDescription(offer);
        dev.log('[WEBRTC] Receiver set remote description from Offer', name: 'WebRTCService');

        // Create and save Answer
        RTCSessionDescription answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 1,
        });
        await _peerConnection!.setLocalDescription(answer);
        await callRepository.setAnswer(callId, {
          'type': answer.type,
          'sdp': answer.sdp,
        });
        dev.log('[WEBRTC] Receiver created & set local answer', name: 'WebRTCService');
      }
    });

    // Listen for Caller candidates
    _candidateSubscription = callRepository.streamCallerCandidates(callId).listen((candidates) async {
      if (_isDisposed) return;
      for (var cand in candidates) {
        final id = cand['id'] as String?;
        if (id != null && !_processedCandidateIds.contains(id)) {
          _processedCandidateIds.add(id);
          final candidate = RTCIceCandidate(
            cand['candidate'] as String?,
            cand['sdpMid'] as String?,
            cand['sdpMLineIndex'] as int?,
          );
          await _peerConnection?.addCandidate(candidate);
        }
      }
    });
  }

  void toggleMic() {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      isMuted = !isMuted;
      audioTracks[0].enabled = !isMuted;
    }
  }

  void toggleCamera() {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      isVideoOff = !isVideoOff;
      videoTracks[0].enabled = !isVideoOff;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks[0]);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      await _callSubscription?.cancel();
      await _candidateSubscription?.cancel();

      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      _localStream = null;

      await _peerConnection?.close();
      _peerConnection = null;

      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (e) {
      dev.log('[WEBRTC ERROR] Dispose error: $e', name: 'WebRTCService');
    }
  }
}
