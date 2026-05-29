import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'call_screen.dart';
import '../services/socket_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String ownerName;
  final String ownerId;
  final String plotName;
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.ownerName,
    required this.ownerId,
    required this.plotName,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl      = TextEditingController();
  final _scroll    = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  bool    _sending    = false;
  bool    _uploading  = false;
  // ── Audio recording ──────────────────────────────────────────
  bool    _recording  = false;
  bool    _sendingAudio = false;
  html.MediaRecorder? _mediaRecorder;
  final List<dynamic> _audioChunks = [];
  Timer?  _recordTimer;
  int     _recordSeconds = 0;
  bool    _loading   = true;
  String? _blocked;
  String? _lastTs;
  Timer?  _pollTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTyping);
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.removeListener(_onTyping);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Phone detection ───────────────────────────────────────────
  bool _looksLikePhone(String t) {
    final s = t.replaceAll(RegExp(r'[\s\-.()+\/\\|_,]'), '');
    if (RegExp(r'\d{8,}').hasMatch(s)) return true;
    if (RegExp(r'\+\d[\d\s\-().]{7,14}\d').hasMatch(t)) return true;
    return RegExp(r'\b\d\b').allMatches(t).length >= 8;
  }

  void _onTyping() {
    final blocked = _looksLikePhone(_ctrl.text);
    if (blocked != (_blocked != null)) {
      setState(() => _blocked = blocked
          ? '🚫 Phone numbers are not allowed in chat.'
          : null);
    }
  }

  // ── Load messages ─────────────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final res  = await Api.getChatMessages(widget.chatId);
      final list = res['messages'] as List? ?? [];
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(list.cast<Map<String, dynamic>>());
          if (_messages.isNotEmpty) {
            _lastTs = _messages.last['createdAt'] as String?;
          }
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Poll ──────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final since = _lastTs ??
            DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String();
        final res   = await Api.pollMessages(widget.chatId, since);
        final list  = res['messages'] as List? ?? [];
        if (list.isNotEmpty && mounted) {
          setState(() {
            for (final m in list.cast<Map<String, dynamic>>()) {
              final idx = _messages.indexWhere((e) => e['_id'] == m['_id']);
              if (idx >= 0) { _messages[idx] = m; } else { _messages.add(m); }
            }
            _messages.sort((a, b) =>
                (a['createdAt'] as String).compareTo(b['createdAt'] as String));
            if (_messages.isNotEmpty) {
              _lastTs = _messages.last['createdAt'] as String?;
            }
          });
          _scrollToBottom();
        }
      } catch (_) {}
    });
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    }
  });

  // ── Pick & upload photo ───────────────────────────────────────
  Future<void> _pickPhoto() async {
    List<int> bytes = [];
    String    name  = 'photo.jpg';

    if (kIsWeb) {
      final input = html.FileUploadInputElement()
        ..accept = 'image/jpeg,image/jpg,image/png,image/webp,image/gif'
        ..multiple = false;
      input.click();
      await input.onChange.first;
      if (input.files == null || input.files!.isEmpty) return;
      final file   = input.files!.first;
      // Build a safe filename with correct extension
      final rawName = file.name;
      final ext = rawName.contains('.')
          ? rawName.substring(rawName.lastIndexOf('.')).toLowerCase()
          : '.jpg';
      final safeExt = ['.jpg','.jpeg','.png','.webp','.gif'].contains(ext) ? ext : '.jpg';
      name = 'photo_${DateTime.now().millisecondsSinceEpoch}$safeExt';
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      bytes = (reader.result as List<dynamic>).cast<int>();
    } else {
      // On mobile, skip — or integrate image_picker separately if needed
      return;
    }

    setState(() => _uploading = true);
    try {
      final res = await Api.uploadChatPhoto(
          chatId: widget.chatId, bytes: bytes, fileName: name);
      final msg = res['message'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((e) => e['_id'] == msg['_id']);
          if (idx < 0) _messages.add(msg);
          _lastTs = msg['createdAt'] as String?;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: C.error));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Send text / link / image URL ─────────────────────────────
  // ── Audio recording methods ─────────────────────────────────
  // Tap mic to START, tap stop button to SEND, tap cancel to discard
  Future<void> _startRecording() async {
    if (!kIsWeb) return;
    if (_recording) { await _stopRecording(); return; }
    try {
      final stream = await html.window.navigator.mediaDevices
          ?.getUserMedia({'audio': true});
      if (stream == null) { _showSnack('Could not access microphone'); return; }
      _audioChunks.clear();
      // Try webm/opus first, fallback to default
      final mimeType = html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : html.MediaRecorder.isTypeSupported('audio/webm')
              ? 'audio/webm'
              : '';
      _mediaRecorder = mimeType.isNotEmpty
          ? html.MediaRecorder(stream, {'mimeType': mimeType})
          : html.MediaRecorder(stream);
      _mediaRecorder!.addEventListener('dataavailable', (e) {
        final blob = (e as html.BlobEvent).data;
        if (blob != null && blob.size > 0) _audioChunks.add(blob);
      });
      _mediaRecorder!.start(250); // collect chunks every 250ms
      _recordSeconds = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() => _recording = true);
    } catch (e) {
      _showSnack('Microphone access denied. Allow mic in browser settings.');
    }
  }

  Future<void> _stopRecording() async {
    if (_mediaRecorder == null) return;
    _recordTimer?.cancel();
    // Request final chunk then wait for stop
    _mediaRecorder!.requestData();
    final completer = Completer<void>();
    _mediaRecorder!.addEventListener('stop', (_) => completer.complete());
    _mediaRecorder!.stop();
    await completer.future;
    // Stop all mic tracks to release the mic
    _mediaRecorder!.stream?.getTracks().forEach((t) => t.stop());
    setState(() { _recording = false; _sendingAudio = true; });
    try {
      if (_audioChunks.isEmpty) { _showSnack('No audio recorded'); return; }
      final blob = html.Blob(List<dynamic>.from(_audioChunks), 'audio/webm');
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      // Flutter web returns NativeUint8List or ByteBuffer depending on version
      final result = reader.result;
      final List<int> bytes;
      if (result is ByteBuffer) {
        bytes = result.asUint8List();
      } else {
        bytes = (result as dynamic).buffer.asUint8List() as List<int>;
      }
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      await Api.uploadChatAudio(chatId: widget.chatId, bytes: bytes, fileName: fileName);
      _audioChunks.clear();
      _mediaRecorder = null;
    } catch (e) {
      _showSnack('Failed to send audio: $e');
    } finally {
      if (mounted) setState(() => _sendingAudio = false);
    }
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    _mediaRecorder?.stream?.getTracks().forEach((t) => t.stop());
    _mediaRecorder?.stop();
    _audioChunks.clear();
    _mediaRecorder = null;
    setState(() { _recording = false; _recordSeconds = 0; });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: C.error));
  }

  String _fmtRecordTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, "0")}:${(s % 60).toString().padLeft(2, "0")}';

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (_looksLikePhone(text)) {
      setState(() => _blocked = '🚫 Phone numbers are not allowed in chat.');
      return;
    }

    setState(() { _sending = true; _blocked = null; });
    try {
      final isImgUrl = _isImageUrl(text);
      final isLink   = !isImgUrl && _isUrl(text);
      final res = await Api.sendMessage(
        chatId:   widget.chatId,
        text:     isImgUrl || isLink ? '' : text,
        imageUrl: isImgUrl ? text : null,
        linkUrl:  isLink   ? text : null,
      );
      final msg = res['message'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((e) => e['_id'] == msg['_id']);
          if (idx < 0) _messages.add(msg);
          _lastTs = msg['createdAt'] as String?;
        });
        _ctrl.clear();
        _scrollToBottom();
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        if (err.contains('phone') || err.contains('blocked')) {
          setState(() => _blocked = '🚫 $err');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err), backgroundColor: C.error));
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isImageUrl(String t) {
    final l = t.toLowerCase();
    return (l.startsWith('http://') || l.startsWith('https://')) &&
        RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?|$)').hasMatch(l);
  }

  bool _isUrl(String t) =>
      t.startsWith('http://') || t.startsWith('https://');

  // ── Delete for everyone ───────────────────────────────────────
  Future<void> _directDelete(String msgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
            'This message will be deleted for both you and the other person.',
            style: TextStyle(color: C.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: C.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: C.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final res = await Api.deleteMessage(
          chatId: widget.chatId, msgId: msgId, scope: 'everyone');
      final updated = res['message'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['_id'] == msgId);
          if (idx >= 0) _messages[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: C.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: const BackButton(color: C.textDark),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.ownerName,
              style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: C.textDark)),
          Text('re: ${widget.plotName}',
              style: const TextStyle(fontSize: 12, color: C.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: C.primaryLight, borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield_outlined, size: 12, color: C.primary),
              SizedBox(width: 4),
              Text('Safe Chat',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: C.primary)),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          color: C.primaryLight,
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: C.primary),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Phone numbers are blocked. Share text, images and links safely.',
              style: TextStyle(fontSize: 11, color: C.primary, height: 1.3),
            )),
          ]),
        ),

        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : _messages.isEmpty
                  ? _EmptyChat(ownerName: widget.ownerName)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m      = _messages[i];
                        final isMe   = (m['senderType'] as String?) == 'customer';
                        final isDFMe = m['deletedForSender'] as bool? ?? false;
                        if (isDFMe) return const SizedBox.shrink();
                        final isDel  = m['deletedForEveryone'] as bool? ?? false;
                        final showDate = i == 0 ||
                            !_sameDay(
                              m['createdAt'] as String?,
                              _messages[i - 1]['createdAt'] as String?,
                            );
                        final bubble = _MsgBubble(msg: m, isMe: isMe);
                        return Column(children: [
                          if (showDate)
                            _DateDivider(ts: m['createdAt'] as String?),
                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            // Only show delete icon on OWN messages
                            child: isMe
                                ? _ChatHoverWrapper(
                                    isMe:      isMe,
                                    isDeleted: isDel,
                                    onDelete:  () => _directDelete(
                                        m['_id'] as String),
                                    child: bubble,
                                  )
                                : bubble,
                          ),
                        ]);
                      },
                    ),
        ),

        // Upload progress
        if (_uploading)
          Container(
            color: C.primaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: C.primary, strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Uploading photo…',
                  style: TextStyle(fontSize: 13, color: C.primary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

        // Phone block warning
        if (_blocked != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: C.errorBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.error.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.block_rounded, color: C.error, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(_blocked!,
                  style: const TextStyle(color: C.error, fontSize: 12))),
            ]),
          ),

        // Recording indicator
        if (_recording)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: C.error, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('Recording… ${_fmtRecordTime(_recordSeconds)}',
                  style: const TextStyle(color: C.error, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _cancelRecording,
                child: const Text('Cancel',
                    style: TextStyle(color: C.textMuted, fontSize: 13)),
              ),
            ]),
          ),

        // Input bar
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
              10, 8, 8, MediaQuery.of(context).viewInsets.bottom + 10),
          child: Row(children: [
            // Photo button
            GestureDetector(
              onTap: _uploading ? null : _pickPhoto,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: C.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded,
                    size: 20, color: C.primary),
              ),
            ),
            const SizedBox(width: 8),

            // Text field
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1, maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message, link or image URL…',
                  hintStyle: const TextStyle(
                      color: C.textLight, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  filled: true, fillColor: C.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: C.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: C.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                          color: C.primary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send / Mic button — mic when text empty, send when text present
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (_, val, __) {
                final hasText = val.text.trim().isNotEmpty;
                if (hasText) {
                  // Send button
                  return GestureDetector(
                    onTap: (_sending || _blocked != null) ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: (_blocked != null || _sending) ? null
                            : const LinearGradient(colors: [C.primaryDark, C.primary]),
                        color: (_blocked != null || _sending) ? C.textLight : null,
                        shape: BoxShape.circle,
                        boxShadow: (_blocked != null) ? []
                            : [BoxShadow(color: C.primary.withValues(alpha: 0.3),
                                blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: _sending
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  );
                }
                // Mic button — tap to start, tap again (stop icon) to send
                return GestureDetector(
                  onTap: _recording ? _stopRecording : _startRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _recording ? C.error : C.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: (_recording ? C.error : C.primary).withValues(alpha: 0.35),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: _sendingAudio
                        ? const Center(child: SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : Icon(_recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                            color: Colors.white, size: 22),
                  ),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }

  bool _sameDay(String? a, String? b) {
    if (a == null || b == null) return false;
    try {
      final da = DateTime.parse(a).toLocal();
      final db = DateTime.parse(b).toLocal();
      return da.year == db.year &&
             da.month == db.month &&
             da.day == db.day;
    } catch (_) { return false; }
  }
}

// ══════════════════════════════════════════════════════════════
//  Hover trash wrapper (web hover + mobile long-press)
// ══════════════════════════════════════════════════════════════
class _ChatHoverWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final bool isMe;
  final bool isDeleted;
  const _ChatHoverWrapper({
    required this.child,
    required this.onDelete,
    required this.isMe,
    this.isDeleted = false,
  });
  @override
  State<_ChatHoverWrapper> createState() => _ChatHoverWrapperState();
}

class _ChatHoverWrapperState extends State<_ChatHoverWrapper>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _showMob = false;
  late AnimationController _anim;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _show() { _anim.forward(); }
  void _hide() {
    _anim.reverse().then((_) {
      if (mounted) setState(() { _hovered = false; _showMob = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDeleted) return widget.child;
    final show = _hovered || _showMob;

    final btn = show
        ? FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: () { _hide(); widget.onDelete(); },
              child: Container(
                width: 30, height: 30,
                margin: EdgeInsets.only(
                  left:  widget.isMe ? 6 : 0,
                  right: widget.isMe ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 6, offset: const Offset(0, 2),
                  )],
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Color(0xFFC62828)),
              ),
            ),
          )
        : null;

    return MouseRegion(
      onEnter: (_) { setState(() => _hovered = true); _show(); },
      onExit:  (_) => _hide(),
      child: GestureDetector(
        onLongPress: () { setState(() => _showMob = true); _show(); },
        onTap:       () { if (_showMob) _hide(); },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!widget.isMe && btn != null) btn,
            Flexible(child: widget.child),
            if (widget.isMe  && btn != null) btn,
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Message bubble
// ══════════════════════════════════════════════════════════════
class _MsgBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _MsgBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final text      = msg['text']               as String? ?? '';
    final imageUrl  = msg['imageUrl']           as String?;
    final linkUrl   = msg['linkUrl']            as String?;
    final audioUrl  = msg['audioUrl']           as String?;
    final isDeleted = msg['deletedForEveryone'] as bool?   ?? false;
    final isEdited  = msg['isEdited']           as bool?   ?? false;
    final ts        = _fmt(msg['createdAt']     as String?);

    if (isDeleted) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block_rounded, size: 14, color: C.textLight),
          SizedBox(width: 6),
          Text('This message was deleted',
              style: TextStyle(fontSize: 13,
                  color: C.textLight, fontStyle: FontStyle.italic)),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl.startsWith('http')
                    ? imageUrl
                    : 'http://localhost:5000$imageUrl',
                width: 220, fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) => prog == null
                    ? child
                    : const SizedBox(width: 220, height: 140,
                        child: Center(child: CircularProgressIndicator(
                            color: C.primary, strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(
                    width: 220, height: 80, color: C.primaryLight,
                    child: const Center(child: Icon(
                        Icons.broken_image_outlined, color: C.textLight))),
              ),
            ),
          // Audio bubble
          if (audioUrl != null && audioUrl.isNotEmpty) ...[
            _AudioBubble(
              url: audioUrl.startsWith('http') ? audioUrl : 'http://localhost:5000$audioUrl',
              isMe: isMe,
            ),
          ] else if (linkUrl != null && linkUrl.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? C.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isMe ? Colors.transparent : C.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link_rounded, size: 16,
                    color: isMe ? Colors.white70 : C.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(linkUrl,
                    style: TextStyle(fontSize: 13,
                        color: isMe ? Colors.white : C.primary,
                        decoration: TextDecoration.underline),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          if (text.isNotEmpty && (audioUrl == null || audioUrl.isEmpty))
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [C.primaryDark, C.primary])
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: C.border),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(text,
                  style: TextStyle(fontSize: 14, height: 1.4,
                      color: isMe ? Colors.white : C.textDark)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isEdited)
                const Text('edited · ',
                    style: TextStyle(fontSize: 10, color: C.textLight,
                        fontStyle: FontStyle.italic)),
              Text(ts,
                  style: const TextStyle(
                      fontSize: 10, color: C.textLight)),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmt(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m  = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) { return ''; }
  }
}

// ══════════════════════════════════════════════════════════════
//  Supporting widgets
// ══════════════════════════════════════════════════════════════
class _DateDivider extends StatelessWidget {
  final String? ts;
  const _DateDivider({required this.ts});
  @override
  Widget build(BuildContext context) {
    String label = 'Today';
    if (ts != null) {
      try {
        final dt   = DateTime.parse(ts!).toLocal();
        final diff = DateTime.now().difference(dt).inDays;
        if (diff == 0)      label = 'Today';
        else if (diff == 1) label = 'Yesterday';
        else                label = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: C.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(fontSize: 11,
                  color: C.textLight, fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: C.border)),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  Hover trash wrapper (web hover + mobile long-press)
// ══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
//  Audio Bubble — plays voice messages inline
// ══════════════════════════════════════════════════════════════
class _AudioBubble extends StatefulWidget {
  final String url;
  final bool   isMe;
  const _AudioBubble({required this.url, required this.isMe});
  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  html.AudioElement? _audio;
  bool   _playing  = false;
  double _progress = 0.0;
  double _duration = 0.0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _audio = html.AudioElement()
      ..src = widget.url
      ..preload = 'metadata';
    // Append to DOM — required for browser audio pipeline in Flutter web
    html.document.body!.append(_audio!);
    _audio!.onLoadedMetadata.listen((_) {
      if (mounted) setState(() => _duration = (_audio!.duration as num).toDouble());
    });
    _audio!.onEnded.listen((_) {
      _ticker?.cancel();
      if (mounted) setState(() { _playing = false; _progress = 0.0; });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audio?.pause();
    _audio?.remove();
    _audio = null;
    super.dispose();
  }

  void _toggle() {
    if (_audio == null) return;
    if (_playing) {
      _audio!.pause();
      _ticker?.cancel();
      setState(() => _playing = false);
    } else {
      _audio!.play();
      // Poll every 80ms — most reliable approach for Flutter web
      _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (!mounted) { _ticker?.cancel(); return; }
        if (_duration > 0) {
          final t = (_audio!.currentTime as num).toDouble();
          if (t != (_progress * _duration)) {
            setState(() => _progress = (t / _duration).clamp(0.0, 1.0));
          }
        }
      });
      setState(() => _playing = true);
    }
  }

  String _fmt(double s) {
    if (!s.isFinite || s <= 0) return '0:00';
    final t = s.toInt();
    return '${(t ~/ 60)}:${(t % 60).toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final bg    = widget.isMe ? C.primary : Colors.white;
    final muted = widget.isMe
        ? Colors.white.withValues(alpha: 0.6)
        : C.textMuted;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: widget.isMe ? null : Border.all(color: C.border),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.25)
                  : C.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? Colors.white : C.primary, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor:   widget.isMe ? Colors.white : C.primary,
              inactiveTrackColor: muted,
              thumbColor:         widget.isMe ? Colors.white : C.primary,
              overlayColor: (widget.isMe ? Colors.white : C.primary).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _progress.clamp(0.0, 1.0),
              onChanged: (v) {
                if (_audio == null || _duration <= 0) return;
                _audio!.currentTime = v * _duration;
                setState(() => _progress = v);
              },
            ),
          ),
          Row(children: [
            Icon(Icons.mic_rounded, size: 11, color: muted),
            const SizedBox(width: 3),
            Text(
              _playing
                  ? _fmt((_audio!.currentTime as num).toDouble())
                  : _fmt(_duration),
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ]),
        ])),
      ]),
    );
  }
}


class _EmptyChat extends StatelessWidget {
  final String ownerName;
  const _EmptyChat({required this.ownerName});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: C.primaryLight, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 36, color: C.primary)),
      const SizedBox(height: 16),
      Text('Say hi to $ownerName!',
          style: const TextStyle(fontSize: 17,
              fontWeight: FontWeight.w800, color: C.textDark)),
      const SizedBox(height: 6),
      const Text('Ask about the plot or schedule a visit',
          style: TextStyle(color: C.textMuted, fontSize: 13)),
    ]),
  );
}
