import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});
  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  List<dynamic> _chats = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.getMyChats();
      if (mounted) setState(() {
        _chats   = res['chats'] as List? ?? [];
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.textDark)),
          Text('Your conversations with owners', style: TextStyle(fontSize: 12, color: C.textMuted)),
        ]),
        actions: [
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: C.primary)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : _chats.isEmpty
              ? _EmptyChats()
              : RefreshIndicator(
                  color: C.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _chats[i] as Map<String, dynamic>;
                      return _ChatTile(chat: c, onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId:    c['_id']  as String,
                            ownerName: (c['owner'] as Map?)? ['name'] as String? ?? 'Owner',
                            ownerId:   (c['owner'] as Map?)? ['_id']  as String? ?? '',
                            plotName:  (c['property'] as Map?)? ['propertyName'] as String? ?? 'Plot',
                          ),
                        ));
                        _load();
                      });
                    },
                  ),
                ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owner    = chat['owner']    as Map<String, dynamic>? ?? {};
    final property = chat['property'] as Map<String, dynamic>? ?? {};
    final unread   = chat['unreadByCustomer'] as int? ?? 0;
    final lastMsg  = chat['lastMessage']  as String? ?? 'Start a conversation';
    final lastTs   = chat['lastMessageAt'] as String?;
    final name     = owner['name']             as String? ?? 'Owner';
    final plotName = property['propertyName']  as String? ?? 'Plot';
    final photos   = property['photos']        as List? ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0 ? C.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread > 0 ? C.primary.withValues(alpha: 0.3) : C.border,
            width: unread > 0 ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Plot photo or owner avatar
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photos.isNotEmpty
                  ? Image.network(
                      _fullUrl(photos.first as String),
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Avatar(name),
                    )
                  : _Avatar(name),
            ),
            if (unread > 0)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(color: C.primary, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name,
                  style: TextStyle(fontSize: 14, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                      color: C.textDark))),
              Text(_fmtTime(lastTs),
                  style: TextStyle(fontSize: 11,
                      color: unread > 0 ? C.primary : C.textLight,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400)),
            ]),
            const SizedBox(height: 2),
            Text('re: $plotName',
                style: const TextStyle(fontSize: 12, color: C.primary, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(lastMsg,
                style: TextStyle(fontSize: 12,
                    color: unread > 0 ? C.textDark : C.textMuted,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
      if (diff.inHours < 24)    return '${diff.inHours}h';
      if (diff.inDays < 7)      return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);
  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(color: C.primaryLight, borderRadius: BorderRadius.circular(12)),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'O',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.primary),
    )),
  );
}

class _EmptyChats extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(color: C.primaryLight, shape: BoxShape.circle),
        child: const Icon(Icons.chat_bubble_outline_rounded, size: 42, color: C.primary),
      ),
      const SizedBox(height: 18),
      const Text('No conversations yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textDark)),
      const SizedBox(height: 6),
      const Text('Open a plot and tap "Chat with Owner"\nto start talking',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.textMuted, fontSize: 14, height: 1.5)),
    ]),
  );
}

String _fullUrl(String url) => url.startsWith('http') ? url : 'http://localhost:5000$url';
