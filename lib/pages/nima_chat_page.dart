import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class _Msg {
  final String role;
  final String text;
  _Msg(this.role, this.text);
}


class NimaChatPage extends StatefulWidget {
  const NimaChatPage({super.key});

  @override
  State<NimaChatPage> createState() => _NimaChatPageState();
}

class _NimaChatPageState extends State<NimaChatPage> {
  static const _blue = Color(0xFF2196F3);

  final supabase = Supabase.instance.client;

  final List<_Msg> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _isTyping = false;

 
  final List<String> _chips = [
    "Is La Marsa safe?",
    "Safest cities in Tunisia",
    "Where to go at night?",
    "Safe places near me"
  ];

  @override
  void initState() {
    super.initState();

    _messages.add(
      _Msg(
        'assistant',
        "Hi 👋 I'm Nima\nAsk me about safety, cities, or night places.",
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

 
  String? _extractCityQuery(String text) {
    final cleaned = text.trim();

    if (cleaned.split(' ').length <= 3) {
      return _capitalize(cleaned);
    }

    final pattern = RegExp(
      r'(?:is|how safe is|safety in|tell me about)\s+(.+)',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(cleaned);
    if (match != null) {
      return _capitalize(match.group(1)!.trim());
    }

    return null;
  }

  String _capitalize(String text) {
    return text
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
        .join(' ');
  }

  Future<String?> _getCityInfo(String city) async {
    try {
      final res = await supabase
          .from('safety_data')
          .select()
          .ilike('city', '%$city%');

      if (res.isEmpty) return null;

      final data = res.first;

      return '''
🌍 ${data['city']} - ${data['country']}

🟢 Safety Level: ${data['safety_level']}
📊 Crime Index: ${data['crime_index']}

⚠️ ${data['risk_note']}

🌙 Night Insight:
${data['night_advice']}

✨ Safe zones:
• City center
• Tourist areas
• Marina / waterfront
''';
    } catch (_) {
      return null;
    }
  }


  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _isTyping) return;

    _ctrl.clear();

    setState(() {
      _messages.add(_Msg('user', text));
      _isTyping = true;
    });

    final city = _extractCityQuery(text);

    String reply;

    if (city != null) {
      final data = await _getCityInfo(city);

      await Future.delayed(const Duration(milliseconds: 400));

      if (data != null) {
        reply = data;
      } else {
        reply = "⚠️ I couldn't find $city in my safety database.";
      }
    } else {
    
      reply = _smartReply(text);
    }

    if (!mounted) return;

    setState(() {
      _messages.add(_Msg('assistant', reply));
      _isTyping = false;
    });

    _scrollToBottom();
  }

 
  String _smartReply(String text) {
    final t = text.toLowerCase();

    if (t.contains("safest cities")) {
      return '''
🟢 Safest cities in Tunisia:

• Sousse (tourist areas)
• Hammamet
• Monastir
• La Marsa
• Tabarka

💡 These places are generally safe in well-lit/touristic zones.
''';
    }

    if (t.contains("night") || t.contains("where to go")) {
      return '''
🌙 Safe places to go at night:

• Waterfront / marinas
• Shopping malls
• City center cafés
• Tourist boulevards

⚠️ Avoid isolated or dark areas late at night.
''';
    }

    if (t.contains("safe places near me")) {
      return '''
📍 Safe nearby places usually include:

• Busy city center
• Cafés & restaurants
• Tourist districts
• Hotels & main streets

💡 Tell me your city for exact spots.
''';
    }

    return '''
I can help you with:

🛡️ Safety of cities
🌙 Night safety places
📍 Safe areas near you

Try:
👉 "Is La Marsa safe?"
''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => _send(_chips[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _blue.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                  )
                ],
              ),
              child: Text(
                _chips[i],
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Nima Safety AI"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),

      body: Column(
        children: [
       
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isTyping && i == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text("Nima is thinking..."),
                  );
                }

                final msg = _messages[i];

                return Align(
                  alignment: msg.role == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.role == 'user'
                          ? _blue
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.role == 'user'
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        
          _buildChips(),

      
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: "Ask about safety...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: _blue),
                  onPressed: () => _send(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}