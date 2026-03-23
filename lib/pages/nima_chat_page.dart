// lib/pages/nima_chat_page.dart
//
// Nima — SafeBuddy's AI safety companion.
// Uses the Anthropic Messages API (claude-sonnet-4-20250514) with the
// built-in web_search tool so Nima can look up real-time safety info.
//
// Add to pubspec.yaml if not already present:
//   http: ^1.2.0   ← already in your project ✓

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

// ── Message model ─────────────────────────────────────────────────────────────
class _Msg {
  final String role; // 'user' | 'assistant'
  final String text;
  _Msg(this.role, this.text);
}

// ── Page ──────────────────────────────────────────────────────────────────────
class NimaChatPage extends StatefulWidget {
  const NimaChatPage({super.key});

  @override
  State<NimaChatPage> createState() => _NimaChatPageState();
}

class _NimaChatPageState extends State<NimaChatPage>
    with TickerProviderStateMixin {
  static const _blue = Color(0xFF2196F3);
  static const _teal = Color(0xFF4FC3F7);
  static const _indigo = Color(0xFF6360B7);

  // ── Replace with your real Anthropic API key ──────────────────────────────
  static const _apiKey = 'YOUR_ANTHROPIC_API_KEY';

  static const _systemPrompt = '''
You are Nima, a warm and caring AI safety companion inside the SafeBuddy app.
Your purpose is to help users stay safe, informed, and confident wherever they are.

Your areas of expertise:
• Safety information about cities, neighbourhoods, countries, and travel routes
• Current safety alerts, travel advisories, and warnings (use web search)
• Tips for staying safe in public spaces, at night, or in unfamiliar areas
• Emotional support — you genuinely care about the user's wellbeing
• Quick safety phrases in local languages
• Emergency numbers for any country

Your personality:
• Warm, caring, and reassuring — like a knowledgeable friend who looks out for you
• Never alarmist — give balanced, practical information
• Use emojis sparingly but naturally (📍🛡️✅⚠️🌍)
• Keep responses concise but complete
• Always end with a caring sign-off when appropriate ("Stay safe 🛡️", "Take care ✨", etc.)

When asked about a place:
1. Give a brief honest safety overview
2. Mention specific areas to be careful in (if any)
3. Share practical tips
4. Use web search to get current advisories if needed

Always prioritise the user's safety and peace of mind.
''';

  final List<_Msg> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Welcome message
    _messages.add(_Msg('assistant',
        "Hi! I'm Nima, your safety companion 🛡️\n\nI can help you with:\n• Safety info about any place in the world\n• Travel advisories & alerts\n• Tips to stay safe wherever you are\n\nWhere are you headed today?"));
  }

  @override
  void dispose() {
    _dotController.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── API call ──────────────────────────────────────────────────────────────
  Future<String> _callNima(List<_Msg> history) async {
    // Build messages array for the API
    final messages = history
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();

    final body = jsonEncode({
      'model': 'claude-sonnet-4-20250514',
      'max_tokens': 1024,
      'system': _systemPrompt,
      'tools': [
        {
          'type': 'web_search_20250305',
          'name': 'web_search',
        }
      ],
      'messages': messages,
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-beta': 'web-search-2025-03-05',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>;

        // Extract all text blocks (skip tool_use / tool_result blocks)
        final text = content
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join('\n')
            .trim();

        return text.isNotEmpty ? text : "I couldn't find anything on that. Could you rephrase?";
      } else {
        final err = jsonDecode(response.body);
        return "⚠️ ${err['error']?['message'] ?? 'Something went wrong. Try again.'}";
      }
    } catch (e) {
      return "⚠️ Connection issue. Please check your internet and try again.";
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isTyping) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Msg('user', text));
      _isTyping = true;
    });
    _scrollToBottom();

    final reply = await _callNima(List.from(_messages));

    if (!mounted) return;
    setState(() {
      _messages.add(_Msg('assistant', reply));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Quick prompts ─────────────────────────────────────────────────────────
  static const _quickPrompts = [
    '📍 Is my area safe right now?',
    '🌍 Safest cities to visit',
    '🌙 Tips for walking at night',
    '🆘 Emergency numbers in Tunisia',
    '✈️ Travel safety tips',
  ];

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_indigo, _blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _indigo.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text('N',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nima',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Safety AI · Online',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildBubble(_messages[i]);
              },
            ),
          ),

          // ── Quick prompts ────────────────────────────────────────────────
          if (_messages.length <= 1)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    _ctrl.text = _quickPrompts[i];
                    _send();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _blue.withOpacity(0.25), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4)
                      ],
                    ),
                    child: Text(_quickPrompts[i],
                        style: TextStyle(
                            fontSize: 12,
                            color: _blue,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Input bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ask Nima about safety anywhere...',
                      hintStyle: TextStyle(
                          color: Colors.grey[400], fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide:
                            BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: const BorderSide(
                            color: _blue, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FF),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isTyping
                            ? [Colors.grey[300]!, Colors.grey[400]!]
                            : [_indigo, _blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: _isTyping
                          ? []
                          : [
                              BoxShadow(
                                  color: _blue.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3)),
                            ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_indigo, _blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('N',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? _blue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _blue.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_indigo, _blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('N',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final offset = i / 3;
                    final val = ((_dotController.value + offset) % 1.0);
                    final opacity = val < 0.5
                        ? 0.3 + val * 1.4
                        : 1.0 - (val - 0.5) * 1.4;
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _blue.withOpacity(opacity.clamp(0.3, 1.0)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}