import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _i = SocketService._();
  factory SocketService() => _i;
  SocketService._();

  IO.Socket? _socket;
  bool _registered = false;

  // ── Incoming call callbacks ──────────────────────────────────
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallAccepted;
  Function()?                     onCallRejected;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function()?                     onCallEnded;
  Function()?                     onCallUnavailable;

  void init() {
    if (_socket != null) return;
    _socket = IO.io('http://localhost:5000', IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    _socket!.onConnect((_) => print('🟢 Socket connected'));
    _socket!.onDisconnect((_) { _registered = false; print('🔴 Socket disconnected'); });

    _socket!.on('call-incoming',   (d) => onIncomingCall?.call(Map<String, dynamic>.from(d as Map)));
    _socket!.on('call-accepted',   (d) => onCallAccepted?.call(Map<String, dynamic>.from(d as Map)));
    _socket!.on('call-rejected',   (_) => onCallRejected?.call());
    _socket!.on('ice-candidate',   (d) => onIceCandidate?.call(Map<String, dynamic>.from(d as Map)));
    _socket!.on('call-ended',      (_) => onCallEnded?.call());
    _socket!.on('call-unavailable',(_) => onCallUnavailable?.call());

    _socket!.connect();
  }

  void register(String userId, String userType) {
    if (_registered) return;
    init();
    _socket!.emit('register', {'userId': userId, 'userType': userType});
    _registered = true;
    print('📞 Registered as $userType:$userId');
  }

  void callUser({
    required String toUserId, required String toUserType,
    required String fromUserId, required String fromUserType,
    required String fromName, required Map<String, dynamic> offer,
  }) => _socket?.emit('call-user', {
    'toUserId': toUserId, 'toUserType': toUserType,
    'fromUserId': fromUserId, 'fromUserType': fromUserType,
    'fromName': fromName, 'offer': offer,
  });

  void acceptCall({
    required String toUserId, required String toUserType,
    required Map<String, dynamic> answer,
  }) => _socket?.emit('call-accepted', {
    'toUserId': toUserId, 'toUserType': toUserType, 'answer': answer,
  });

  void rejectCall({required String toUserId, required String toUserType}) =>
      _socket?.emit('call-rejected', {'toUserId': toUserId, 'toUserType': toUserType});

  void sendIceCandidate({
    required String toUserId, required String toUserType,
    required Map<String, dynamic> candidate,
  }) => _socket?.emit('ice-candidate', {
    'toUserId': toUserId, 'toUserType': toUserType, 'candidate': candidate,
  });

  void endCall({required String toUserId, required String toUserType}) =>
      _socket?.emit('call-ended', {'toUserId': toUserId, 'toUserType': toUserType});

  void dispose() {
    _socket?.disconnect();
    _socket = null;
    _registered = false;
  }
}
