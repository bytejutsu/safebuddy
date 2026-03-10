// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/contacts_controller.dart';
import 'pages/auth/signin_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/globe_page.dart';
import 'pages/settings/setting_page.dart';
import 'pages/settings/emergency_settings_page.dart';
import 'pages/contacts/contacts_page.dart';
import 'pages/contacts/call_page.dart';
import 'pages/profile/profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hjkcyekgdpqkeijdntah.supabase.co',
    anonKey: 'sb_publishable_BZO0LBVdNsybm0Hh90xmLw_Ov2I-6oG',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SafeBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(ContactsController());
      }),
      initialRoute: '/signin',
      getPages: [
        GetPage(name: '/signin',   page: () => SignInPage()),
        GetPage(name: '/signup',   page: () => SignUpPage()),
        GetPage(name: '/home',     page: () => SettingsPage()),
        GetPage(name: '/safety',   page: () => GlobePage()),
        GetPage(name: '/settings', page: () => EmergencySettingsPage()),
        GetPage(name: '/contacts', page: () => ContactsPage()),
        GetPage(name: '/profile',  page: () => ProfilePage()),
        GetPage(
          name: '/call',
          page: () {
            final args = Get.arguments as Map<String, dynamic>? ?? {};
            return CallPage(
              contactName: args['name'] as String? ?? 'Unknown',
              contactPhone: args['phone'] as String? ?? '',
              isIncoming: args['isIncoming'] as bool? ?? false,
            );
          },
        ),
      ],
    );
  }
}