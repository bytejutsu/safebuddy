import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiProtectionService {
  static String get _apiKey =>
      dotenv.env['GROQ_API_KEY']
      ?? (throw Exception('GROQ_API_KEY not found in .env'));
  static const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static final _notifications = FlutterLocalNotificationsPlugin();

  // ── Init notifications once at app start ──
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  // ── Main function called when toggle turns ON ──
  static Future<void> checkAndNotify() async {
    try {
      // 1. Get location
      final position = await _getLocation();
      if (position == null) {
        await _sendNotification(
          title: '📍 Nima — Location Error',
          body: 'Could not get your location. Please enable GPS.',
        );
        return;
      }

      // 2. Convert to city name
      final city = await _getCity(position);

      // 3. Check Supabase for city safety
      final safetyData = await _queryCitySafety(city);

      // 4. Ask Groq (Nima) to generate smart message
      final message = await _askNima(city, safetyData);

      // 5. Send notification
      await _sendNotification(
        title: '🛡️ Nima Safety Update — $city',
        body: message,
      );
    } catch (e) {
      await _sendNotification(
        title: '🛡️ Nima',
        body: 'Could not complete safety check. Please try again.',
      );
    }
  }

  // ── Get GPS position ──
  static Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ── Convert coords to city name ──
  static Future<String> _getCity(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'your location';
      }
    } catch (_) {}
    return 'your location';
  }

  // ── Query Supabase for safety data ──
  static Future<Map<String, dynamic>?> _queryCitySafety(String city) async {
    try {
      final res = await Supabase.instance.client
          .from('safety_data')
          .select()
          .ilike('city', '%$city%');
      if ((res as List).isNotEmpty) {
        return res.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Ask Nima (Groq) to generate safety message ──
  static Future<String> _askNima(
    String city,
    Map<String, dynamic>? safetyData,
  ) async {
    String context;

    if (safetyData != null) {
      final crime = safetyData['crime_index'] ?? 'unknown';
      final level = safetyData['safety_level'] ?? 'unknown';
      final note = safetyData['risk_note'] ?? '';
      final night = safetyData['night_advice'] ?? '';
      context = '''
City: $city
Safety Level: $level
Crime Index: $crime/100
Risk Note: $note
Night Advice: $night
''';
    } else {
      context = 'City: $city\nNo specific safety data available.';
    }

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are Nima, a safety AI. Generate a SHORT (max 2 sentences) friendly push notification about the user\'s current location safety. Be direct and helpful. No markdown.',
            },
            {
              'role': 'user',
              'content': 'Generate a safety notification for:\n$context',
            }
          ],
          'max_tokens': 100,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
    } catch (_) {}

    // Fallback if Groq fails
    if (safetyData != null) {
      final level = safetyData['safety_level'] ?? 'moderate risk';
      return '$city is currently rated as $level. Stay aware of your surroundings.';
    }
    return 'Stay safe in $city! No specific data available for this area.';
  }

  // ── Send the actual notification ──
  static Future<void> _sendNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'nima_safety_channel',
      'Nima Safety Alerts',
      channelDescription: 'Safety notifications from Nima AI',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}