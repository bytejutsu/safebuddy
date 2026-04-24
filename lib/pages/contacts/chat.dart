import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/contacts_controller.dart';

void showMessageSheet(
  BuildContext context,
  TrustedContactModel contact,
  ContactsController ctrl,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(contact: contact, ctrl: ctrl),
    ),
  );
}

class ChatPage extends StatefulWidget {
  final TrustedContactModel contact;
  final ContactsController ctrl;

  const ChatPage({super.key, required this.contact, required this.ctrl});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = Supabase.instance.client;
  final RxList<Map<String, dynamic>> _messages = <Map<String, dynamic>>[].obs;
  final RxBool _isSending = false.obs;
  static const _blue = Color(0xFF2196F3);

  String get _myId => _db.auth.currentUser?.id ?? '';
  String get _otherId => widget.contact.profileId ?? '';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _listenToMessages();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _db.removeAllChannels();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      if (_otherId.isEmpty) return;
      final res = await _db
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_myId,receiver_id.eq.$_otherId),and(sender_id.eq.$_otherId,receiver_id.eq.$_myId)')
          .order('created_at', ascending: true);
      _messages.value = List<Map<String, dynamic>>.from(res as List);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
    }
  }

  void _listenToMessages() {
    _db
        .channel('chat_${_myId}_$_otherId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMsg = payload.newRecord;
            final senderId = newMsg['sender_id'];
            final receiverId = newMsg['receiver_id'];
            if ((senderId == _myId && receiverId == _otherId) ||
                (senderId == _otherId && receiverId == _myId)) {
              _messages.add(Map<String, dynamic>.from(newMsg));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _otherId.isEmpty) return;
    _isSending.value = true;
    try {
      await _db.from('messages').insert({
        'sender_id': _myId,
        'receiver_id': _otherId,
        'content': text.trim(),
      });
      _msgCtrl.clear();
    } catch (e) {
      Get.snackbar('❌ Error', 'Failed to send message',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      _isSending.value = false;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Family': return const Color(0xFF4FC3F7);
      case 'Friends': return const Color(0xFF81C784);
      case 'Work': return const Color(0xFFFFB74D);
      case 'Emergency': return const Color(0xFFE57373);
      default: return const Color(0xFF9575CD);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  String _formatTime(String isoStr) {
    final dt = DateTime.parse(isoStr).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static const _quickReplies = [
    '👋 Hey, are you okay?',
    '📍 I am sharing my location with you.',
    '🆘 I need help, please call me!',
    '✅ I am safe, don\'t worry.',
    '🕐 I\'ll be there soon.',
  ];

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final color = _categoryColor(contact.category);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Center(
                child: Text(_initials(contact.name),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                Text(contact.phone,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        actions: [
          Obx(() => IconButton(
                icon: Icon(
                  contact.isSharing
                      ? Icons.location_on_rounded
                      : Icons.location_off_outlined,
                  color: contact.isSharing ? Colors.green : Colors.grey,
                ),
                onPressed: () => widget.ctrl.toggleSharing(contact),
              )),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (_messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 52, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No messages yet',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey[400])),
                      const SizedBox(height: 4),
                      Text('Say hello to ${contact.name}!',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[350])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  final isMe = msg['sender_id'] == _myId;
                  final time = msg['created_at'] != null
                      ? _formatTime(msg['created_at'] as String)
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Center(
                              child: Text(_initials(contact.name),
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: color)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? _blue
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(msg['content'] as String,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87)),
                                const SizedBox(height: 4),
                                Text(time,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.grey[400])),
                              ],
                            ),
                          ),
                        ),
                        if (isMe) const SizedBox(width: 4),
                      ],
                    ),
                  );
                },
              );
            }),
          ),

          // ── Quick replies ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickReplies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    _msgCtrl.text = _quickReplies[i];
                    _msgCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _msgCtrl.text.length));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _blue.withOpacity(0.2), width: 1),
                    ),
                    child: Text(_quickReplies[i],
                        style: const TextStyle(
                            fontSize: 12,
                            color: _blue,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          ),

          // ── Input ────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: _blue, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() => GestureDetector(
                      onTap: _isSending.value
                          ? null
                          : () => _sendMessage(_msgCtrl.text),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: _isSending.value
                              ? Colors.grey[300]
                              : _blue,
                          shape: BoxShape.circle,
                        ),
                        child: _isSending.value
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}