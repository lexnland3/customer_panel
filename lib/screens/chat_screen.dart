import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String ownerName;
  final String plotName;
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.ownerName,
    required this.plotName,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  bool _sending = false;
  bool _uploading = false;
  String _uploadLabel = 'Uploading…';
  bool _loading = true;
  String? _blocked;
  String? _lastTs;
  Timer? _pollTimer;

  // Voice recording
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _recSecs = 0;
  Timer? _recTimer;

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
    _recTimer?.cancel();
    _recorder.dispose();
    _ctrl.removeListener(_onTyping);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Record & send voice message ───────────────────────────────
  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      _recTimer?.cancel();
      if (mounted) setState(() => _recording = false);
      if (path == null) return;
      try {
        final bytes = await XFile(path).readAsBytes();
        if (mounted)
          setState(() {
            _uploading = true;
            _uploadLabel = 'Processing audio…';
          });
        final res = await Api.uploadChatAudio(
            chatId: widget.chatId,
            bytes: bytes,
            fileName: 'voice.webm',
            duration: _recSecs);
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
              content: Text('Voice send failed: $e'),
              backgroundColor: C.error));
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } else {
      try {
        if (!await _recorder.hasPermission()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Microphone permission denied')));
          }
          return;
        }
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus),
            path: 'voice');
        if (mounted)
          setState(() {
            _recording = true;
            _recSecs = 0;
          });
        _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recSecs++);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not start recording: $e'),
              backgroundColor: C.error));
        }
      }
    }
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
      setState(() => _blocked =
          blocked ? '🚫 Phone numbers are not allowed in chat.' : null);
    }
  }

  // ── Load messages ─────────────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final res = await Api.getChatMessages(widget.chatId);
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
            DateTime.now()
                .subtract(const Duration(seconds: 10))
                .toIso8601String();
        final res = await Api.pollMessages(widget.chatId, since);
        final list = res['messages'] as List? ?? [];
        if (list.isNotEmpty && mounted) {
          setState(() {
            for (final m in list.cast<Map<String, dynamic>>()) {
              final idx = _messages.indexWhere((e) => e['_id'] == m['_id']);
              if (idx >= 0) {
                _messages[idx] = m;
              } else {
                _messages.add(m);
              }
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
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut);
        }
      });

  // ── Pick & upload photo ───────────────────────────────────────
  Future<void> _pickPhoto() async {
    Uint8List bytes;
    String name;
    try {
      final picker = ImagePicker();
      final xf =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xf == null) return;
      bytes = await xf.readAsBytes();
      name = xf.name;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not pick photo: $e'),
            backgroundColor: C.error));
      }
      return;
    }

    setState(() {
      _uploading = true;
      _uploadLabel = 'Uploading photo…';
    });
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
            content: Text('Upload failed: $e'), backgroundColor: C.error));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Send text / link / image URL ─────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (_looksLikePhone(text)) {
      setState(() => _blocked = '🚫 Phone numbers are not allowed in chat.');
      return;
    }

    setState(() {
      _sending = true;
      _blocked = null;
    });
    try {
      final isImgUrl = _isImageUrl(text);
      final isLink = !isImgUrl && _isUrl(text);
      final res = await Api.sendMessage(
        chatId: widget.chatId,
        text: isImgUrl || isLink ? '' : text,
        imageUrl: isImgUrl ? text : null,
        linkUrl: isLink ? text : null,
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err), backgroundColor: C.error));
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

  bool _isUrl(String t) => t.startsWith('http://') || t.startsWith('https://');

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

  // ── Edit message ──────────────────────────────────────────────
  Future<void> _editMessage(String msgId, String currentText) async {
    final ctrl = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Message',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          decoration: InputDecoration(
            hintText: 'Edit your message',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: C.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save',
                style:
                    TextStyle(color: C.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (newText == null ||
        newText.isEmpty ||
        newText == currentText ||
        !mounted) {
      return;
    }
    try {
      final res = await Api.editMessage(
          chatId: widget.chatId, msgId: msgId, newText: newText);
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: C.textDark),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.ownerName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: C.textDark)),
          Text('re: ${widget.plotName}',
              style: const TextStyle(fontSize: 12, color: C.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: C.primary)),
            ]),
          ),
        ],
      ),
      body: Column(children: [
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
                        final m = _messages[i];
                        final isMe = (m['senderType'] as String?) == 'customer';
                        final isDFMe = m['deletedForSender'] as bool? ?? false;
                        if (isDFMe) return const SizedBox.shrink();
                        final isDel = m['deletedForEveryone'] as bool? ?? false;
                        final showDate = i == 0 ||
                            !_sameDay(
                              m['createdAt'] as String?,
                              _messages[i - 1]['createdAt'] as String?,
                            );
                        return Column(children: [
                          if (showDate)
                            _DateDivider(ts: m['createdAt'] as String?),
                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: _ChatHoverWrapper(
                              isMe: isMe,
                              isDeleted: isDel,
                              onEdit: () => _editMessage(m['_id'] as String,
                                  m['text'] as String? ?? ''),
                              onDelete: () => _directDelete(m['_id'] as String),
                              child: _MsgBubble(msg: m, isMe: isMe),
                            ),
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
            child: Row(children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: C.primary, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(_uploadLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      color: C.primary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

        // Recording indicator
        if (_recording)
          Container(
            color: C.errorBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.fiber_manual_record, color: C.error, size: 13),
              const SizedBox(width: 8),
              Text('Recording…  ${_recSecs}s',
                  style: const TextStyle(
                      fontSize: 13,
                      color: C.error,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('tap ■ to send',
                  style: TextStyle(fontSize: 12, color: C.textMuted)),
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
              Expanded(
                  child: Text(_blocked!,
                      style: const TextStyle(color: C.error, fontSize: 12))),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded,
                    size: 20, color: C.primary),
              ),
            ),
            const SizedBox(width: 8),

            // Mic / record button
            GestureDetector(
              onTap: _uploading ? null : _toggleRecord,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _recording ? C.error : C.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (_recording ? C.error : C.primary)
                          .withValues(alpha: 0.3)),
                ),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 20, color: _recording ? Colors.white : C.primary),
              ),
            ),
            const SizedBox(width: 8),

            // Text field
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message, link or image URL…',
                  hintStyle: const TextStyle(color: C.textLight, fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: C.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: C.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: C.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide:
                          const BorderSide(color: C.primary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: (_sending || _blocked != null) ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: (_blocked != null || _sending)
                      ? null
                      : const LinearGradient(
                          colors: [C.primaryDark, C.primary]),
                  color: (_blocked != null || _sending) ? C.textLight : null,
                  shape: BoxShape.circle,
                  boxShadow: (_blocked != null)
                      ? []
                      : [
                          BoxShadow(
                              color: C.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                ),
                child: _sending
                    ? const Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
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
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  Hover trash wrapper (web hover + mobile long-press)
// ══════════════════════════════════════════════════════════════
class _ChatHoverWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isMe;
  final bool isDeleted;
  const _ChatHoverWrapper({
    required this.child,
    required this.onEdit,
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
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _show() {
    _anim.forward();
  }

  void _hide() {
    _anim.reverse().then((_) {
      if (mounted)
        setState(() {
          _hovered = false;
          _showMob = false;
        });
    });
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: C.primary),
            title: const Text('Edit message',
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: C.textDark)),
            onTap: () {
              Navigator.pop(sheetCtx);
              widget.onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: C.error),
            title: const Text('Delete for everyone',
                style: TextStyle(fontWeight: FontWeight.w600, color: C.error)),
            onTap: () {
              Navigator.pop(sheetCtx);
              widget.onDelete();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDeleted) return widget.child;
    final show = _hovered || _showMob;

    // Only the sender sees the actions button — never on the other person's
    // messages. Tapping it opens a menu with exactly two options.
    final btn = (show && widget.isMe)
        ? FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: () {
                _hide();
                _openMenu();
              },
              child: Container(
                width: 30,
                height: 30,
                margin: EdgeInsets.only(
                  left: widget.isMe ? 6 : 0,
                  right: widget.isMe ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.more_vert_rounded,
                    size: 18, color: C.textMuted),
              ),
            ),
          )
        : null;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _show();
      },
      onExit: (_) => _hide(),
      child: GestureDetector(
        onLongPress: () {
          setState(() => _showMob = true);
          _show();
        },
        onTap: () {
          if (_showMob) _hide();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!widget.isMe && btn != null) btn,
            Flexible(child: widget.child),
            if (widget.isMe && btn != null) btn,
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
    final text = msg['text'] as String? ?? '';
    final imageUrl = msg['imageUrl'] as String?;
    final audioUrl = msg['audioUrl'] as String?;
    final linkUrl = msg['linkUrl'] as String?;
    final isDeleted = msg['deletedForEveryone'] as bool? ?? false;
    final isEdited = msg['isEdited'] as bool? ?? false;
    final ts = _fmt(msg['createdAt'] as String?);

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
              style: TextStyle(
                  fontSize: 13,
                  color: C.textLight,
                  fontStyle: FontStyle.italic)),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (audioUrl != null && audioUrl.isNotEmpty)
            _VoiceMessage(
              url: audioUrl.startsWith('http')
                  ? audioUrl
                  : '${Api.mediaBase}$audioUrl',
              isMe: isMe,
              durationSecs: (msg['audioDuration'] as num?)?.toInt() ?? 0,
            ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl.startsWith('http')
                    ? imageUrl
                    : '${Api.mediaBase}$imageUrl',
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) => prog == null
                    ? child
                    : const SizedBox(
                        width: 220,
                        height: 140,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: C.primary, strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(
                    width: 220,
                    height: 80,
                    color: C.primaryLight,
                    child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: C.textLight))),
              ),
            ),
          if (linkUrl != null && linkUrl.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? C.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isMe ? Colors.transparent : C.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link_rounded,
                    size: 16, color: isMe ? Colors.white70 : C.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(linkUrl,
                        style: TextStyle(
                            fontSize: 13,
                            color: isMe ? Colors.white : C.primary,
                            decoration: TextDecoration.underline),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
              ]),
            ),
          if (text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(colors: [C.primaryDark, C.primary])
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: C.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isMe ? Colors.white : C.textDark)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isEdited)
                const Text('edited · ',
                    style: TextStyle(
                        fontSize: 10,
                        color: C.textLight,
                        fontStyle: FontStyle.italic)),
              Text(ts,
                  style: const TextStyle(fontSize: 10, color: C.textLight)),
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
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) {
      return '';
    }
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
        final dt = DateTime.parse(ts!).toLocal();
        final diff = DateTime.now().difference(dt).inDays;
        if (diff == 0)
          label = 'Today';
        else if (diff == 1)
          label = 'Yesterday';
        else
          label = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: C.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: C.textLight,
                  fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: C.border)),
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
          Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(color: C.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: C.primary)),
          const SizedBox(height: 16),
          Text('Say hi to $ownerName!',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: C.textDark)),
          const SizedBox(height: 6),
          const Text('Ask about the plot',
              style: TextStyle(color: C.textMuted, fontSize: 13)),
        ]),
      );
}

// ── Voice message player ─────────────────────────────────────
class _VoiceMessage extends StatefulWidget {
  final String url;
  final bool isMe;
  final int durationSecs;
  const _VoiceMessage(
      {required this.url, required this.isMe, this.durationSecs = 0});
  @override
  State<_VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<_VoiceMessage> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted)
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMe ? Colors.white : C.primary;
    final bg = widget.isMe ? C.primary : Colors.white;
    // Prefer the player's reported duration; fall back to the stored recording
    // duration (recorded WebM often reports no duration in the browser).
    final totalMs = _dur.inMilliseconds > 0
        ? _dur.inMilliseconds
        : widget.durationSecs * 1000;
    final progress =
        totalMs > 0 ? (_pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      width: 220,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.isMe ? Colors.transparent : C.border),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 34,
              color: fg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: fg.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            ),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.mic_rounded,
                  size: 13, color: fg.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                  _pos > Duration.zero
                      ? _fmt(_pos)
                      : (totalMs > 0
                          ? _fmt(Duration(milliseconds: totalMs))
                          : 'Voice message'),
                  style: TextStyle(
                      fontSize: 11, color: fg.withValues(alpha: 0.9))),
            ]),
          ]),
        ),
      ]),
    );
  }
}
