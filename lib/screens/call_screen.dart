import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';

// ── Call state ────────────────────────────────────────────────
enum _CS { outgoing, incoming, active, ended }

class CallScreen extends StatefulWidget {
  // Who we are
  final String myId;
  final String myType;   // 'customer'
  final String myName;
  // Who we're calling / who called us
  final String peerId;
  final String peerType; // 'owner'
  final String peerName;
  // If incoming, we already have the offer
  final bool isOutgoing;
  final Map<String, dynamic>? incomingOffer;

  const CallScreen({
    super.key,
    required this.myId,
    required this.myType,
    required this.myName,
    required this.peerId,
    required this.peerType,
    required this.peerName,
    required this.isOutgoing,
    this.incomingOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  _CS _state = _CS.outgoing;
  RTCPeerConnection? _pc;
  MediaStream?       _localStream;
  bool _muted    = false;
  int  _seconds  = 0;
  Timer? _timer;
  Timer? _ringTimer;

  // Ringtone (web only)
  html.AudioElement? _ringtone;

  final _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _state = widget.isOutgoing ? _CS.outgoing : _CS.incoming;
    _setupSocketListeners();
    if (widget.isOutgoing) {
      _startCall();
    } else {
      _playRingtone(incoming: true);
    }
    // Auto-reject after 45 seconds if no answer
    _ringTimer = Timer(const Duration(seconds: 45), () {
      if (_state == _CS.outgoing || _state == _CS.incoming) _hangUp();
    });
  }

  void _setupSocketListeners() {
    final s = SocketService();
    s.onCallAccepted = (data) async {
      if (!mounted) return;
      _stopRingtone();
      _ringTimer?.cancel();
      final answer = RTCSessionDescription(
        data['answer']['sdp'] as String,
        data['answer']['type'] as String,
      );
      await _pc?.setRemoteDescription(answer);
      setState(() => _state = _CS.active);
      _startTimer();
    };
    s.onCallRejected = () {
      if (!mounted) return;
      _stopRingtone();
      setState(() => _state = _CS.ended);
      Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context); });
    };
    s.onIceCandidate = (data) async {
      final c = data['candidate'];
      if (c == null) return;
      await _pc?.addCandidate(RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    };
    s.onCallEnded = () {
      if (!mounted) return;
      _cleanUp();
      setState(() => _state = _CS.ended);
      Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context); });
    };
    s.onCallUnavailable = () {
      if (!mounted) return;
      _stopRingtone();
      setState(() => _state = _CS.ended);
      Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context); });
    };
  }

  Future<void> _startCall() async {
    _playRingtone(incoming: false);
    _pc = await createPeerConnection(_iceConfig);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      SocketService().sendIceCandidate(
        toUserId: widget.peerId, toUserType: widget.peerType,
        candidate: {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex},
      );
    };
    final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(offer);
    SocketService().callUser(
      toUserId: widget.peerId, toUserType: widget.peerType,
      fromUserId: widget.myId, fromUserType: widget.myType,
      fromName: widget.myName,
      offer: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  Future<void> _acceptCall() async {
    _stopRingtone();
    _ringTimer?.cancel();
    setState(() => _state = _CS.active);
    _pc = await createPeerConnection(_iceConfig);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      SocketService().sendIceCandidate(
        toUserId: widget.peerId, toUserType: widget.peerType,
        candidate: {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex},
      );
    };
    await _pc!.setRemoteDescription(RTCSessionDescription(
      widget.incomingOffer!['sdp'] as String,
      widget.incomingOffer!['type'] as String,
    ));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    SocketService().acceptCall(
      toUserId: widget.peerId, toUserType: widget.peerType,
      answer: {'sdp': answer.sdp, 'type': answer.type},
    );
    _startTimer();
  }

  void _rejectCall() {
    _stopRingtone();
    SocketService().rejectCall(toUserId: widget.peerId, toUserType: widget.peerType);
    Navigator.pop(context);
  }

  void _hangUp() {
    SocketService().endCall(toUserId: widget.peerId, toUserType: widget.peerType);
    _cleanUp();
    if (mounted) Navigator.pop(context);
  }

  void _cleanUp() {
    _stopRingtone();
    _ringTimer?.cancel();
    _timer?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _pc = null;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _timerStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2,"0")}:${s.toString().padLeft(2,"0")}';
  }

  void _toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _muted);
    setState(() => _muted = !_muted);
  }

  void _playRingtone({required bool incoming}) {
    if (!kIsWeb) return;
    try {
      _ringtone = html.AudioElement()
        ..src = incoming
            ? 'https://www.soundjay.com/phone/sounds/phone-ringing-04.mp3'
            : 'https://www.soundjay.com/phone/sounds/phone-dialing-02.mp3'
        ..loop = true;
      html.document.body!.append(_ringtone!);
      _ringtone!.play();
    } catch (_) {}
  }

  void _stopRingtone() {
    _ringtone?.pause();
    _ringtone?.remove();
    _ringtone = null;
  }

  @override
  void dispose() {
    _cleanUp();
    // Reset socket callbacks
    final s = SocketService();
    s.onCallAccepted   = null;
    s.onCallRejected   = null;
    s.onIceCandidate   = null;
    s.onCallEnded      = null;
    s.onCallUnavailable= null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _CS.outgoing: return _buildOutgoing();
      case _CS.incoming: return _buildIncoming();
      case _CS.active:   return _buildActive();
      case _CS.ended:    return _buildEnded();
    }
  }

  Widget _buildOutgoing() => _buildCallBase(
    subtitle: 'Calling…',
    actions: [
      _CallBtn(icon: Icons.call_end, color: Colors.red, label: 'Cancel', onTap: _hangUp),
    ],
  );

  Widget _buildIncoming() => _buildCallBase(
    subtitle: 'Incoming call',
    actions: [
      _CallBtn(icon: Icons.call_end, color: Colors.red, label: 'Decline', onTap: _rejectCall),
      _CallBtn(icon: Icons.call, color: Colors.green, label: 'Accept', onTap: _acceptCall),
    ],
  );

  Widget _buildActive() => _buildCallBase(
    subtitle: _timerStr,
    actions: [
      _CallBtn(
        icon:  _muted ? Icons.mic_off : Icons.mic,
        color: _muted ? Colors.orange : Colors.white24,
        label: _muted ? 'Unmute' : 'Mute',
        onTap: _toggleMute,
      ),
      _CallBtn(icon: Icons.call_end, color: Colors.red, label: 'End', onTap: _hangUp),
    ],
  );

  Widget _buildEnded() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.call_end, color: Colors.red, size: 64),
      const SizedBox(height: 16),
      Text(_state == _CS.ended && !widget.isOutgoing ? 'Call declined' : 'Call ended',
          style: const TextStyle(color: Colors.white, fontSize: 20)),
    ],
  );

  Widget _buildCallBase({required String subtitle, required List<Widget> actions}) =>
    Column(children: [
      const Spacer(),
      // Avatar circle
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          color: C.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: C.primary, width: 2),
        ),
        child: Center(child: Text(
          widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w700),
        )),
      ),
      const SizedBox(height: 20),
      Text(widget.peerName,
          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6))),
      const Spacer(),
      // Action buttons
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions),
      const SizedBox(height: 48),
    ]);
}

// ── Reusable call button ──────────────────────────────────────
class _CallBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final VoidCallback onTap;
  const _CallBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(children: [
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    ),
    const SizedBox(height: 8),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}
