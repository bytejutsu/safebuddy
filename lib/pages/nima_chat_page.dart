import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────
enum _MsgType { text, safetyCard, list }

class _Msg {
  final String role;
  final String text;
  final _MsgType type;
  final Map<String, dynamic>? cardData;
  final DateTime time;

  _Msg({
    required this.role,
    required this.text,
    this.type = _MsgType.text,
    this.cardData,
  }) : time = DateTime.now();
}

// ─────────────────────────────────────────────
//  Page
// ─────────────────────────────────────────────
class NimaChatPage extends StatefulWidget {
  const NimaChatPage({super.key});

  @override
  State<NimaChatPage> createState() => _NimaChatPageState();
}

class _NimaChatPageState extends State<NimaChatPage>
    with TickerProviderStateMixin {
  // ── theme ──────────────────────────────────
  static const _bg = Color(0xFF0F1923);
  static const _surface = Color(0xFF1A2636);
  static const _card = Color(0xFF1E2D42);
  static const _accent = Color(0xFF00C6FF);
  static const _accentSoft = Color(0xFF0D4F6E);
  static const _userBubble = Color(0xFF0066CC);
  static const _green = Color(0xFF00D68F);
  static const _orange = Color(0xFFFFB347);
  static const _red = Color(0xFFFF6B6B);

  // ── state ──────────────────────────────────
  final supabase = Supabase.instance.client;
  final List<_Msg> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;

  // ── suggestion chips ────────────────────────
  List<String> _chips = [
    "🏖️ Safest beach cities",
    "🌙 Where to go tonight?",
    "🏙️ Is Tunis safe?",
    "⚠️ Dangerous areas to avoid",
  ];

  // ── animation controllers ───────────────────
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            role: 'assistant',
            text:
                "Hey! I'm **Nima**, your personal safety guide for Tunisia 🇹🇳\n\nI can tell you which cities are safe, what areas to avoid, and where to go at night. What would you like to know?",
          ));
        });
      }
    });
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Query logic
  // ─────────────────────────────────────────────
  String? _extractCity(String text) {
    final t = text.trim();
    final patterns = [
      RegExp(
          r'(?:is|how safe is|safety (?:in|of)|about|tell me about|check)\s+(.+?)(?:\s+safe|\s+dangerous|\?|$)',
          caseSensitive: false),
      RegExp(r'(.+?)\s+(?:safety|safe\?|crime)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(t);
      if (m != null) return m.group(1)!.trim();
    }

    if (t.split(' ').length <= 4 && !_isQuestion(t)) {
      return t;
    }
    return null;
  }

  bool _isQuestion(String t) {
    final q = t.toLowerCase().trim();

    // Words that are never city names
    const nonCityWords = {
      'yes', 'no', 'ok', 'okay', 'hi', 'hey', 'hello',
      'thanks', 'cool', 'great', 'nice', 'wow', 'sure', 'help', 'more',
      'yep', 'nope', 'alright', 'hola', 'salam', 'salut', 'bonjour',
      'thank you', 'thx',
    };
    if (nonCityWords.contains(q)) return true;

    return q.startsWith('where') ||
        q.startsWith('what') ||
        q.startsWith('how') ||
        q.startsWith('which') ||
        q.startsWith('list') ||
        q.startsWith('show') ||
        q.contains('safest') ||
        q.contains('dangerous') ||
        q.contains('avoid') ||
        q.contains('tonight') ||
        q.contains('night') ||
        q.contains('beach');
  }

  Future<Map<String, dynamic>?> _queryCityData(String city) async {
    try {
      final res = await supabase
          .from('safety_data')
          .select()
          .ilike('city', '%${city.trim()}%');
      if ((res as List).isEmpty) return null;
      return res.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _querySafestCities({
    String? filter,
    double? maxCrime,
  }) async {
    try {
      var q = supabase.from('safety_data').select();
      if (filter != null) q = q.ilike('safety_level', '%$filter%');
      if (maxCrime != null) q = q.lte('crime_index', maxCrime);
      final res = await q.order('crime_index', ascending: true).limit(6);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _queryDangerousCities() async {
    try {
      final res = await supabase
          .from('safety_data')
          .select()
          .gte('crime_index', 60)
          .order('crime_index', ascending: false)
          .limit(6);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────
  //  Send / respond
  // ─────────────────────────────────────────────
  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _isTyping) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _isTyping = true;
    });
    _scrollToBottom();

    await Future.delayed(Duration(milliseconds: 600 + Random().nextInt(600)));
    if (!mounted) return;

    final t = text.toLowerCase().trim();

    // ── Greetings / small talk ──────────────────
    const greetings = {
      'hi', 'hello', 'hey', 'hola', 'salam', 'salut', 'bonjour',
      'yes', 'no', 'ok', 'okay', 'thanks', 'thank you', 'thx',
      'cool', 'great', 'nice', 'wow', 'yep', 'nope', 'sure', 'alright',
    };
    if (greetings.contains(t)) {
      _addMessage(_Msg(role: 'assistant', text: _smallTalkReply(t)));
      _updateChips([
        "🏖️ Safest beach cities",
        "🌙 Where to go tonight?",
        "🏙️ Is Tunis safe?",
        "⚠️ Dangerous areas to avoid",
      ]);
      return;
    }

    // ── Safest cities ───────────────────────────
    if (t.contains('safest') ||
        t.contains('safe cities') ||
        t.contains('safest cities')) {
      final cities = await _querySafestCities(maxCrime: 25);
      _addMessage(_Msg(
        role: 'assistant',
        text: 'safest_list',
        type: _MsgType.list,
        cardData: {
          'cities': cities,
          'title': '🟢 Safest Cities in Tunisia',
          'mode': 'safe'
        },
      ));
      _updateChips([
        '🏖️ Tell me about Hammamet',
        '🌙 Night safety in La Marsa',
        '🏄 Beach destinations',
        '📍 Sousse safety'
      ]);
      return;
    }

    // ── Dangerous / avoid ───────────────────────
    if (t.contains('dangerous') ||
        t.contains('avoid') ||
        t.contains('unsafe') ||
        t.contains('worst')) {
      final cities = await _queryDangerousCities();
      _addMessage(_Msg(
        role: 'assistant',
        text: 'danger_list',
        type: _MsgType.list,
        cardData: {
          'cities': cities,
          'title': '🔴 High-Risk Areas',
          'mode': 'danger'
        },
      ));
      _updateChips([
        '🛡️ How to stay safe?',
        '🏙️ Safe areas in Tunis',
        '🌙 Night safety tips',
        '📞 Emergency numbers'
      ]);
      return;
    }

    // ── Night / tonight ─────────────────────────
    if (t.contains('night') ||
        t.contains('tonight') ||
        t.contains('after dark')) {
      _addMessage(_Msg(role: 'assistant', text: _nightReply()));
      _updateChips([
        '🌙 La Marsa at night',
        '🌙 Sidi Bou Said at night',
        '🌙 Hammamet at night',
        '⚠️ Areas to avoid at night'
      ]);
      return;
    }

    // ── Beach ───────────────────────────────────
    if (t.contains('beach') || t.contains('coast') || t.contains('sea')) {
      final cities = await _querySafestCities(filter: 'safe', maxCrime: 30);
      _addMessage(_Msg(
        role: 'assistant',
        text: 'beach_list',
        type: _MsgType.list,
        cardData: {
          'cities': cities,
          'title': '🏖️ Safest Beach & Coastal Cities',
          'mode': 'safe'
        },
      ));
      _updateChips([
        '🏖️ Tell me about Djerba',
        '🏖️ Hammamet safety',
        '⛵ Port El Kantaoui',
        '🌊 Tabarka'
      ]);
      return;
    }

    // ── Tips / how to stay safe ─────────────────
    if (t.contains('tip') ||
        t.contains('stay safe') ||
        t.contains('advice') ||
        t.contains('how to')) {
      _addMessage(_Msg(role: 'assistant', text: _safetyTips()));
      _updateChips([
        '🏙️ Tunis safety',
        '🌙 Night safety',
        '🚗 Driving tips',
        '📞 Emergency numbers'
      ]);
      return;
    }

    // ── Emergency ───────────────────────────────
    if (t.contains('emergency') ||
        t.contains('police') ||
        t.contains('number') ||
        t.contains('call')) {
      _addMessage(_Msg(role: 'assistant', text: _emergencyNumbers()));
      _updateChips([
        '🛡️ Safety tips',
        '🏥 Hospitals in Tunis',
        '⚠️ High risk areas',
        '🌙 Is it safe tonight?'
      ]);
      return;
    }

    // ── City lookup ─────────────────────────────
    final city = _extractCity(text);
    if (city != null) {
      final data = await _queryCityData(city);
      if (data != null) {
        _addMessage(_Msg(
          role: 'assistant',
          text: 'card',
          type: _MsgType.safetyCard,
          cardData: data,
        ));
        _updateChips([
          '🌙 Night safety in $city',
          '📍 Safe areas near $city',
          '⚠️ What to avoid in $city',
          '🗺️ Nearby safe cities'
        ]);
        return;
      } else {
        _addMessage(_Msg(
          role: 'assistant',
          text:
              "I searched my database but couldn't find **$city** 🔍\n\nTry a different spelling, or ask me about major cities like *Tunis*, *Sousse*, *Hammamet*, or *Djerba*.",
        ));
        _updateChips([
          '🏙️ Major cities safety',
          '🏖️ Safest cities',
          '🗺️ Explore Tunisia',
          '⚠️ Dangerous areas'
        ]);
        return;
      }
    }

    // ── Fallback ────────────────────────────────
    _addMessage(_Msg(role: 'assistant', text: _fallback(text)));
    _updateChips([
      "🏖️ Safest beach cities",
      "🌙 Where to go tonight?",
      "🏙️ Is Tunis safe?",
      "⚠️ Dangerous areas to avoid",
    ]);
  }

  void _addMessage(_Msg msg) {
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  void _updateChips(List<String> chips) {
    if (mounted) setState(() => _chips = chips);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────────
  //  Smart text replies
  // ─────────────────────────────────────────────
  String _smallTalkReply(String t) {
    if (['hi', 'hello', 'hey', 'hola', 'salam', 'salut', 'bonjour']
        .contains(t)) {
      return "Hey there! 👋 I'm **Nima**, your safety guide for Tunisia 🇹🇳\n\nAsk me about any city, neighbourhood, or just where to go tonight!";
    }
    if (['thanks', 'thank you', 'thx'].contains(t)) {
      return "You're welcome! 😊 Stay safe out there.\n\n💡 *Need anything else? Just ask!*";
    }
    if (['yes', 'yep', 'sure', 'ok', 'okay', 'alright'].contains(t)) {
      return "Of course! 😊 What city or area would you like to know about?\n\nTry something like:\n• *\"Is Sousse safe?\"*\n• *\"Safest cities in Tunisia\"*\n• *\"Where to go tonight?\"*";
    }
    if (['no', 'nope'].contains(t)) {
      return "No worries! 😊 Let me know if you need anything.\n\n💡 I'm here whenever you want safety info about Tunisia.";
    }
    if (['cool', 'great', 'nice', 'wow'].contains(t)) {
      return "Glad I could help! 🙌\n\nAnything else you'd like to know about Tunisia?";
    }
    return "Got it! 😊 What city or area would you like to explore?\n\nJust type a city name or ask a question!";
  }

  String _nightReply() => '''🌙 **Night Safety in Tunisia**

Here's what you need to know for after-dark:

✅ **Generally safe at night:**
• La Marsa corniche — cafés open until late
• Sidi Bou Said — charming, well-lit, tourists
• Port El Kantaoui — resort security all night
• Les Berges du Lac — upscale, well-patrolled
• Hammamet hotel zone — active promenade

⚠️ **Exercise caution:**
• Tunis Médina after 10pm — avoid deep alleys
• Sousse Médina after 9pm — stick to main gates
• Bus stations and transport hubs

🚫 **Avoid entirely at night:**
• Ettahdhamen, Intilaka, Sijoumi
• Ben Gardane (border area)
• Rural desert roads without a guide

💡 *Ask me about a specific city for detailed night safety info.*''';

  String _safetyTips() => '''🛡️ **Safety Tips for Tunisia**

**In cities:**
• Keep bags close in souks and busy markets
• Use official taxis or ride-apps, avoid unmarked cars
• Avoid displaying expensive phones/cameras in crowds

**At night:**
• Stick to well-lit main streets and tourist zones
• Let someone know where you're going
• Trust your instincts — if it feels off, leave

**Transport:**
• Intercity buses are generally safe
• Avoid driving on unlit rural roads at night
• Always lock your car in unfamiliar areas

**Documents & Money:**
• Keep a photo of your passport on your phone
• Use hotel safes for passports and valuables
• Carry small amounts of cash, not large sums

💡 *Ask me about a specific city or region for tailored advice.*''';

  String _emergencyNumbers() => '''📞 **Emergency Numbers in Tunisia**

🚔 **Police:** 197
🚑 **SAMU (Ambulance):** 190
🚒 **Fire Brigade:** 198
🏥 **Civil Protection:** 1021

**Useful contacts:**
• Tourist Police: +216 71 341 644
• Emergency line (general): 112

**Hospitals in Tunis:**
• Charles Nicolle Hospital: +216 71 578 000
• Clinique les Oliviers: +216 71 774 311

⚠️ *In an emergency, 190 or 197 are the fastest responses.*
💡 *Save these numbers offline — you may not have internet in an emergency.*''';

  String _fallback(String input) =>
      '''I'm not sure I understood that 🤔\n\nHere's what I can help you with:\n\n🏙️ **City safety** — *"Is Sousse safe?"*\n🟢 **Safest places** — *"Show me the safest cities"*\n🔴 **Areas to avoid** — *"What areas are dangerous?"*\n🌙 **Night safety** — *"Where to go tonight in Hammamet?"*\n🛡️ **Safety tips** — *"How do I stay safe in Tunisia?"*\n📞 **Emergency info** — *"Emergency numbers Tunisia"*\n\nJust type a city name or ask a question!''';

  // ─────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildTypingIndicator(),
          _buildChipsRow(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_accent, Color(0xFF0055AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.shield_moon_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nima',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('Safety AI · Tunisia',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline_rounded,
              color: Colors.white.withOpacity(0.4), size: 20),
          onPressed: () => _showInfoSheet(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final showTime = i == 0 ||
            _messages[i].time.difference(_messages[i - 1].time).inMinutes > 5;
        return Column(
          children: [
            if (showTime) _buildTimestamp(msg.time),
            _buildMessageBubble(msg, i),
          ],
        );
      },
    );
  }

  Widget _buildTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('$h:$m',
          style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.25),
              letterSpacing: 0.5)),
    );
  }

  Widget _buildMessageBubble(_Msg msg, int index) {
    final isUser = msg.role == 'user';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [_accent, Color(0xFF0055AA)]),
                ),
                child: const Icon(Icons.shield_moon_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: isUser ? _buildUserBubble(msg) : _buildNimaBubble(msg),
            ),
            if (isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(_Msg msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_userBubble, Color(0xFF004499)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
              color: _userBubble.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Text(msg.text,
          style:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
    );
  }

  Widget _buildNimaBubble(_Msg msg) {
    if (msg.type == _MsgType.safetyCard && msg.cardData != null) {
      return _buildSafetyCard(msg.cardData!);
    }
    if (msg.type == _MsgType.list && msg.cardData != null) {
      return _buildCityList(msg.cardData!);
    }
    return _buildTextBubble(msg.text);
  }

  Widget _buildTextBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: _buildRichText(text),
    );
  }

  Widget _buildRichText(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final boldPattern = RegExp(r'\*\*(.+?)\*\*');
        if (boldPattern.hasMatch(line)) {
          final spans = <TextSpan>[];
          int last = 0;
          for (final m in boldPattern.allMatches(line)) {
            if (m.start > last) {
              spans.add(TextSpan(
                  text: line.substring(last, m.start),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.6)));
            }
            spans.add(TextSpan(
                text: m.group(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.6)));
            last = m.end;
          }
          if (last < line.length) {
            spans.add(TextSpan(
                text: line.substring(last),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    height: 1.6)));
          }
          return RichText(text: TextSpan(children: spans));
        }
        final italicPattern = RegExp(r'\*(.+?)\*');
        if (italicPattern.hasMatch(line) && !line.contains('**')) {
          return Text(
            line.replaceAllMapped(italicPattern, (m) => m.group(1)!),
            style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                height: 1.6,
                fontStyle: FontStyle.italic),
          );
        }
        return Text(
          line,
          style: TextStyle(
              color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.6),
        );
      }).toList(),
    );
  }

  Widget _buildSafetyCard(Map<String, dynamic> data) {
    final level = (data['safety_level'] as String? ?? '').trim().toLowerCase();
    final crimeIndex = (data['crime_index'] as num?)?.toDouble() ?? 0;

    Color levelColor;
    IconData levelIcon;
    String levelLabel;

    if (level.contains('safe')) {
      levelColor = _green;
      levelIcon = Icons.check_circle_rounded;
      levelLabel = 'Safe';
    } else if (level.contains('moderate')) {
      levelColor = _orange;
      levelIcon = Icons.warning_rounded;
      levelLabel = 'Moderate Risk';
    } else {
      levelColor = _red;
      levelIcon = Icons.dangerous_rounded;
      levelLabel = 'High Risk';
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(18),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          border: Border.all(color: levelColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: levelColor.withOpacity(0.12),
                border: Border(
                    bottom:
                        BorderSide(color: levelColor.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(levelIcon, color: levelColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['city'] as String? ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${data['country'] ?? 'Tunisia'} · $levelLabel',
                          style: TextStyle(
                              color: levelColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Crime index bar
                  Row(
                    children: [
                      Text('Crime Index',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12)),
                      const Spacer(),
                      Text(crimeIndex.toStringAsFixed(1),
                          style: TextStyle(
                              color: levelColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text('/100',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (crimeIndex / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(levelColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (data['risk_note'] != null) ...[
                    _infoRow(Icons.info_outline_rounded, 'Risk Overview',
                        data['risk_note'] as String),
                    const SizedBox(height: 12),
                  ],
                  if (data['night_advice'] != null) ...[
                    _infoRow(Icons.nightlight_round, 'Night Safety',
                        data['night_advice'] as String),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accent, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCityList(Map<String, dynamic> data) {
    final cities = data['cities'] as List<Map<String, dynamic>>;
    final title = data['title'] as String;
    final isDanger = data['mode'] == 'danger';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(18),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1, color: Color(0xFF263545)),
            ...cities.map((c) {
              final crime = (c['crime_index'] as num?)?.toDouble() ?? 0;
              Color dot;
              if (crime < 30) {
                dot = _green;
              } else if (crime < 55) {
                dot = _orange;
              } else {
                dot = _red;
              }

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: dot.withOpacity(0.5), blurRadius: 4)
                          ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['city'] as String? ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            isDanger
                                ? _truncate(
                                    c['risk_note'] as String? ?? '', 60)
                                : _truncate(
                                    c['night_advice'] as String? ?? '', 60),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dot.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(crime.toStringAsFixed(0),
                          style: TextStyle(
                              color: dot,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text(
                isDanger
                    ? 'Tap a city name to learn more about it.'
                    : 'Ask me about any city for detailed safety info.',
                style: TextStyle(color: _accent.withOpacity(0.6), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;

  // ─────────────────────────────────────────────
  //  Typing indicator
  // ─────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 0, 16, 8),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final offset =
                        ((_dotCtrl.value * 3 - i) % 3 + 3) % 3;
                    final scale =
                        (offset < 1.5 ? 1.0 + 0.3 * sin(offset * pi) : 0.7)
                            .clamp(0.7, 1.3);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 6,
                        height: 6,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(
                              (0.4 + 0.6 * (scale - 0.7) / 0.3)
                                  .clamp(0.0, 1.0)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text('Nima is analysing...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 11)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Chips
  // ─────────────────────────────────────────────
  Widget _buildChipsRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(
            _chips[i]
                .replaceAll(
                    RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]\s*',
                        unicode: true),
                    '')
                .trim(),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _accentSoft.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.25)),
            ),
            child: Text(
              _chips[i],
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Input bar
  // ─────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: _surface,
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(28),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _ctrl,
                onSubmitted: (_) => _send(),
                style:
                    const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask about any city or place…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [_accent, Color(0xFF0055AA)]),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Info bottom sheet
  // ─────────────────────────────────────────────
  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('About Nima',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              'Nima is your AI-powered safety guide for Tunisia. She uses a database of real safety data covering 100+ cities to help you make informed decisions.\n\nNima covers:\n• City & neighbourhood safety\n• Crime index scores\n• Night safety advice\n• Areas to avoid',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  height: 1.6),
            ),
            const SizedBox(height: 16),
            Text(
              '⚠️ Data is for guidance only. Always use common sense and check official advisories.',
              style: TextStyle(
                  color: _orange.withOpacity(0.8),
                  fontSize: 12,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}