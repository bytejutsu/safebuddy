import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nima_chat_page.dart';
import '../controllers/contacts_controller.dart';

class _PlaceInfo {
  final String displayName;
  final String road;
  final String neighbourhood;
  final String suburb;
  final String city;
  final String state;
  final String country;
  final String countryCode;
  final String postcode;

  const _PlaceInfo({
    required this.displayName,
    required this.road,
    required this.neighbourhood,
    required this.suburb,
    required this.city,
    required this.state,
    required this.country,
    required this.countryCode,
    required this.postcode,
  });

  factory _PlaceInfo.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>? ?? {};
    return _PlaceInfo(
      displayName: json['display_name'] as String? ?? '',
      road: addr['road'] as String? ?? addr['pedestrian'] as String? ?? '',
      neighbourhood: addr['neighbourhood'] as String? ?? '',
      suburb: addr['suburb'] as String? ?? '',
      city: addr['city'] as String? ??
          addr['town'] as String? ??
          addr['village'] as String? ??
          addr['county'] as String? ??
          '',
      state: addr['state'] as String? ?? '',
      country: addr['country'] as String? ?? '',
      countryCode: (addr['country_code'] as String? ?? '').toUpperCase(),
      postcode: addr['postcode'] as String? ?? '',
    );
  }

  String get shortName {
    final parts = <String>[];
    if (road.isNotEmpty) parts.add(road);
    if (neighbourhood.isNotEmpty) parts.add(neighbourhood);
    else if (suburb.isNotEmpty) parts.add(suburb);
    if (city.isNotEmpty) parts.add(city);
    return parts.take(3).join(', ');
  }
}

class GlobePage extends StatefulWidget {
  const GlobePage({super.key});

  @override
  State<GlobePage> createState() => _GlobePageState();
}

class _GlobePageState extends State<GlobePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  String _locationStatus = '';
  bool _isLoadingLocation = false;

  final RxInt selectedIndex = 1.obs;

  static const _blue = Color(0xFF2196F3);
  static const _teal = Color(0xFF4FC3F7);
  static const _indigo = Color(0xFF6360B7);

  final _db = Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleNavigation(int index) {
    if (index == selectedIndex.value) return;
    selectedIndex.value = index;
    switch (index) {
      case 0: Get.offAllNamed('/home'); break;
      case 1: break;
      case 2: Get.offAllNamed('/profile'); break;
      case 3: Get.offAllNamed('/contacts'); break;
    }
  }

  Future<_PlaceInfo?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$lat&lon=$lng&addressdetails=1&accept-language=en',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'SafeBuddy/1.0',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return _PlaceInfo.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openGPS() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = '';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permission denied.';
            _isLoadingLocation = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!kIsWeb) _showPermissionDialog();
        else setState(() => _locationStatus = 'Please allow location in your browser.');
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Save location to Supabase
      if (_uid != null) {
        try {
          await _db.from('profiles').update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'location_updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', _uid!);
        } catch (_) {}
      }

      final place = await _reverseGeocode(position.latitude, position.longitude);
      setState(() => _isLoadingLocation = false);
      _showPositionSheet(position, place);
    } catch (e) {
      setState(() {
        _locationStatus = 'Could not get location.\nPlease allow location access.';
        _isLoadingLocation = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission Required',
            style: TextStyle(fontWeight: FontWeight.bold, color: _blue)),
        content: const Text('Please enable location permission in app settings.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async { Get.back(); await Geolocator.openAppSettings(); },
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    setState(() => _isLoadingLocation = false);
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openStreetView(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  // ── Share location with emergency contacts ───────────────────────────────
  Future<void> _showShareWithContactsSheet(
      Position position, _PlaceInfo? place) async {
    final ctrl = Get.find<ContactsController>();
    final emergencyContacts = ctrl.contacts
        .where((c) => c.category == 'Emergency')
        .toList();

    if (emergencyContacts.isEmpty) {
      Get.snackbar(
        '❌ No Emergency Contacts',
        'Add Emergency contacts first to share your location.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final locationUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final locationName = place?.shortName.isNotEmpty == true
        ? place!.shortName
        : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

    String myName = 'me';
    if (_uid != null) {
      try {
        final profile = await _db
            .from('profiles')
            .select('full_name')
            .eq('id', _uid!)
            .single();
        myName = profile['full_name'] ?? 'me';
      } catch (_) {}
    }

    final Set<String> selected = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.share_location,
                            color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Share Location',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Select emergency contacts',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _blue.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: _blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationName,
                            style: const TextStyle(
                                fontSize: 13,
                                color: _blue,
                                fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: emergencyContacts.length,
                    itemBuilder: (_, i) {
                      final contact = emergencyContacts[i];
                      final isSelected = selected.contains(contact.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selected.remove(contact.id);
                            } else {
                              selected.add(contact.id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.red.withOpacity(0.07)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.red.withOpacity(0.4)
                                  : Colors.grey[200]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _initials(contact.name),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(contact.name,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                    Text(contact.phone,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.red
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isSelected
                                          ? Colors.red
                                          : Colors.grey[400]!,
                                      width: 2),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _sendLocationToContacts(
                                selected,
                                emergencyContacts,
                                myName,
                                locationName,
                                locationUrl,
                                position,
                                ctrl,
                              );
                            },
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        selected.isEmpty
                            ? 'Select contacts'
                            : 'Send to ${selected.length} contact${selected.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selected.isEmpty ? Colors.grey : Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Send location messages to selected contacts ──────────────────────────
  Future<void> _sendLocationToContacts(
    Set<String> selectedIds,
    List<TrustedContactModel> contacts,
    String myName,
    String locationName,
    String locationUrl,
    Position position,
    ContactsController ctrl,
  ) async {
    if (_uid == null) return;

    int successCount = 0;

    for (final contact in contacts) {
      if (!selectedIds.contains(contact.id)) continue;
      if (contact.profileId == null) continue;

      try {
        // Check sharing history to determine first time or repeat
        final history = await _db
            .from('sharing_history')
            .select()
            .eq('user_id', _uid!)
            .eq('contact_id', contact.id)
            .order('started_at', ascending: false);

        final isFirstTime = (history as List).isEmpty;

        final message = isFirstTime
            ? '👋 Hey, it\'s $myName! I\'m sharing my location with you for the first time.\n\n📍 I am currently at: $locationName\n\n🗺️ Open in Maps: $locationUrl'
            : '👋 Hey, it\'s $myName again! Here is my updated location.\n\n📍 I am currently at: $locationName\n\n🗺️ Open in Maps: $locationUrl';

        // Send message in chat
        await _db.from('messages').insert({
          'sender_id': _uid,
          'receiver_id': contact.profileId,
          'content': message,
        });

        // Record in sharing history
        final now = DateTime.now().toUtc().toIso8601String();
        await _db.from('sharing_history').insert({
          'user_id': _uid,
          'contact_id': contact.id,
          'contact_name': contact.name,
          'started_at': now,
          'ended_at': now,
          'duration_secs': 0,
        });

        successCount++;
      } catch (e) {
        debugPrint('Failed to send to ${contact.name}: $e');
      }
    }

    await ctrl.fetchHistory();

    if (successCount > 0) {
      Get.snackbar(
        '✅ Location Shared',
        'Your location was sent to $successCount contact${successCount > 1 ? 's' : ''}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[600],
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } else {
      Get.snackbar(
        '❌ Failed',
        'Could not share location. Make sure contacts have SafeBuddy accounts.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _showPositionSheet(Position position, _PlaceInfo? place) {
    final latStr =
        '${position.latitude.abs().toStringAsFixed(5)}° ${position.latitude >= 0 ? 'N' : 'S'}';
    final lngStr =
        '${position.longitude.abs().toStringAsFixed(5)}° ${position.longitude >= 0 ? 'E' : 'W'}';
    final accuracyText = position.accuracy < 20
        ? '✓ Excellent (${position.accuracy.toStringAsFixed(0)} m)'
        : position.accuracy < 50
            ? '✓ High (${position.accuracy.toStringAsFixed(0)} m)'
            : '~ ${position.accuracy.toStringAsFixed(0)} m';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12),
              blurRadius: 24, offset: const Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: _blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.location_on, color: _blue, size: 30)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Location',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (place != null && place.shortName.isNotEmpty)
                      Text(place.shortName,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 12),
            if (place != null) ...[
              if (place.road.isNotEmpty)
                _detailRow(Icons.signpost_outlined, 'Street', place.road),
              if (place.neighbourhood.isNotEmpty || place.suburb.isNotEmpty)
                _detailRow(Icons.holiday_village_outlined, 'District',
                    place.neighbourhood.isNotEmpty
                        ? place.neighbourhood
                        : place.suburb),
              if (place.city.isNotEmpty)
                _detailRow(Icons.location_city_outlined, 'City', place.city),
              if (place.state.isNotEmpty)
                _detailRow(Icons.map_outlined, 'State / Region', place.state),
              _detailRow(Icons.flag_outlined, 'Country',
                  '${place.countryCode.isNotEmpty ? _flagEmoji(place.countryCode) + ' ' : ''}${place.country}'),
              if (place.postcode.isNotEmpty)
                _detailRow(Icons.markunread_mailbox_outlined, 'Postcode',
                    place.postcode),
            ] else ...[
              _detailRow(Icons.my_location, 'Latitude', latStr),
              _detailRow(Icons.explore_outlined, 'Longitude', lngStr),
            ],
            _detailRow(Icons.gps_fixed, 'Accuracy', accuracyText),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.pin_drop_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text('$latStr  ·  $lngStr',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace')),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(flex: 3, child: SizedBox(height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMaps(
                      position.latitude, position.longitude),
                  icon: const Icon(Icons.map, color: Colors.white, size: 20),
                  label: const Text('Google Maps',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                ))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: SizedBox(height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _openStreetView(
                      position.latitude, position.longitude),
                  icon: const Icon(Icons.streetview,
                      color: Colors.white, size: 20),
                  label: const Text('Street',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                ))),
            ]),
            const SizedBox(height: 10),
            // ── Share with SafeBuddy Emergency Contacts ──────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  _showShareWithContactsSheet(position, place);
                },
                icon: const Icon(Icons.share_location,
                    color: Colors.white, size: 20),
                label: const Text('Share with Emergency Contacts',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
              ),
            ),
            const SizedBox(height: 10),
            // ── Share via WhatsApp/Clipboard ─────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final mapsLink =
                      'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
                  final placeName = place?.shortName.isNotEmpty == true
                      ? place!.shortName
                      : '';
                  final shareText = placeName.isNotEmpty
                      ? '📍 My current location: $placeName\n$mapsLink'
                      : '📍 My current location:\n$mapsLink';
                  final whatsappUri = Uri.parse(
                      'whatsapp://send?text=${Uri.encodeComponent(shareText)}');
                  if (await canLaunchUrl(whatsappUri)) {
                    await launchUrl(whatsappUri,
                        mode: LaunchMode.externalApplication);
                  } else {
                    await Clipboard.setData(ClipboardData(text: shareText));
                    Get.back();
                    Get.snackbar('✅ Copied!',
                        'Location link copied to clipboard.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: _blue,
                        colorText: Colors.white,
                        borderRadius: 12,
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 3));
                  }
                },
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                label: const Text('Share via WhatsApp',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _flagEmoji(String countryCode) {
    if (countryCode.length != 2) return '';
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCode(base + countryCode.codeUnitAt(0)) +
        String.fromCharCode(base + countryCode.codeUnitAt(1));
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: _blue),
        const SizedBox(width: 12),
        SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  GestureDetector(
                    onTap: _openGPS,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220, height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: _teal.withOpacity(0.2),
                                  blurRadius: 56,
                                  spreadRadius: 28)
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (_, __) => CustomPaint(
                            size: const Size(210, 210),
                            painter: _PixelGlobePainter(
                                rotation:
                                    _rotationController.value * 2 * pi),
                          ),
                        ),
                        if (_isLoadingLocation)
                          Container(
                            width: 210, height: 210,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.8)),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                      color: _blue),
                                  const SizedBox(height: 12),
                                  Text('Getting location...',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      _locationStatus.isNotEmpty
                          ? _locationStatus
                          : 'The AI is constantly analyzing global\ndata to ensure your safety',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: _locationStatus.isNotEmpty
                              ? Colors.redAccent
                              : Colors.grey[600],
                          height: 1.5),
                    ),
                  ),
                  if (!_isLoadingLocation && _locationStatus.isEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: _teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.touch_app,
                            size: 16, color: _teal.withOpacity(0.9)),
                        const SizedBox(width: 6),
                        Text('Tap the globe to locate yourself',
                            style: TextStyle(
                                fontSize: 12,
                                color: _teal.withOpacity(0.9),
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                  const Spacer(flex: 3),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: GestureDetector(
                onTap: () => Get.to(() => const NimaChatPage(),
                    transition: Transition.downToUp,
                    duration: const Duration(milliseconds: 350)),
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_indigo, _blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _indigo.withOpacity(0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Center(
                    child: Text('N',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(() => Container(
            decoration: BoxDecoration(boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2)),
            ]),
            child: BottomNavigationBar(
              currentIndex: selectedIndex.value,
              type: BottomNavigationBarType.fixed,
              backgroundColor: _blue,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.6),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              onTap: _handleNavigation,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.shield_outlined),
                    activeIcon: Icon(Icons.shield),
                    label: 'Safety'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.contact_support_outlined),
                    activeIcon: Icon(Icons.contact_support),
                    label: 'Contact'),
              ],
            ),
          )),
    );
  }
}

class _PixelGlobePainter extends CustomPainter {
  final double rotation;
  _PixelGlobePainter({required this.rotation});

  static const List<List<double>> _land = [
    [5,20],[10,15],[15,20],[15,30],[10,35],[0,30],[-5,25],
    [-10,20],[-15,25],[-20,30],[5,10],[20,25],[25,30],[10,40],
    [0,15],[5,35],[-25,25],[-30,28],
    [50,10],[55,15],[48,5],[52,0],[45,10],[60,20],[55,25],
    [45,25],[48,20],[40,20],[42,15],[46,8],[54,18],
    [30,70],[35,80],[40,90],[45,100],[50,110],[55,120],
    [30,60],[25,80],[20,90],[35,50],[40,50],[60,60],
    [50,80],[45,130],[40,120],[35,140],[25,110],[20,105],
    [55,60],[65,70],[70,90],[60,100],[55,80],
    [40,-80],[45,-75],[50,-90],[55,-100],[60,-110],
    [35,-100],[30,-90],[45,-95],[40,-100],[50,-70],
    [55,-120],[60,-130],[35,-120],[25,-100],[20,-90],
    [45,-65],[42,-83],[38,-77],
    [-5,-60],[-10,-55],[-15,-50],[-20,-45],[-25,-50],
    [-30,-55],[-35,-60],[0,-65],[5,-55],[-10,-70],
    [-15,-75],[-5,-75],[5,-60],
    [-25,130],[-30,135],[-35,140],[-25,140],[-20,135],
    [-30,125],[-25,145],[-32,138],[-27,133],
    [70,-40],[72,-30],[68,-50],[75,-45],[66,-35],
    [60,40],[65,60],[70,80],[65,100],[60,130],[55,40],
    [70,100],[68,40],[58,55],[62,75],
    [35,137],[38,141],[33,132],
    [53,-2],[56,-4],[54,-6],
    [20,78],[15,75],[22,88],[28,77],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 4;

    for (final pt in _land) {
      final latRad = pt[0] * pi / 180;
      final lonRad = pt[1] * pi / 180 + rotation;
      final x = r * cos(latRad) * sin(lonRad);
      final y = -r * sin(latRad);
      final z = r * cos(latRad) * cos(lonRad);

      if (z > -5) {
        final depth = (z + r) / (2 * r);
        final dotR = 2.5 + depth * 2.0;
        final opacity = 0.35 + depth * 0.65;
        final color = Color.lerp(
          const Color(0xFF80DEEA),
          const Color(0xFF0277BD),
          depth,
        )!.withOpacity(opacity);
        canvas.drawCircle(
            Offset(cx + x, cy + y), dotR, Paint()..color = color);
      }
    }

    final rng = Random(7);
    for (int i = 0; i < 60; i++) {
      final lat = (rng.nextDouble() * 160 - 80) * pi / 180;
      final lon = rng.nextDouble() * 2 * pi + rotation;
      final x = r * cos(lat) * sin(lon);
      final y = -r * sin(lat);
      final z = r * cos(lat) * cos(lon);
      if (z > 30) {
        final depth = (z + r) / (2 * r);
        canvas.drawCircle(
            Offset(cx + x, cy + y),
            1.0,
            Paint()
              ..color = const Color(0xFF80DEEA)
                  .withOpacity(0.1 + depth * 0.12));
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGlobePainter old) => old.rotation != rotation;
}