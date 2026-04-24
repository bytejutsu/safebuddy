import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const _apiKey = ''; // from console.groq.com
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<String> ask(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama3-8b-8192',
          'messages': messages,
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
  } 
      else {
        print('❌ Groq error ${response.statusCode}: ${response.body}'); // add this
        return "I'm having trouble connecting right now. Please try again.";
  }   
  }   
      catch (e) {
        print('❌ Groq exception: $e'); // add this
        return "An error occurred while connecting. Please try again.";
    }
  }}
    
     