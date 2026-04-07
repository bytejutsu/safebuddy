// lib/controllers/contacts_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Sharing History Model ─────────────────────────────────────────────────────
class SharingHistoryEntry {
  final String id;
  final String contactId;
  final String contactName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSecs;

  SharingHistoryEntry({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.startedAt,
    this.endedAt,
    this.durationSecs,
  });

  factory SharingHistoryEntry.fromMap(Map<String, dynamic> m) {
    return SharingHistoryEntry(
      id: m['id'] as String,
      contactId: m['contact_id'] as String,
      contactName: m['contact_name'] as String,
      startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
      endedAt: m['ended_at'] != null
          ? DateTime.parse(m['ended_at'] as String).toLocal()
          : null,
      durationSecs: m['duration_secs'] as int?,
    );
  }

  /// e.g. "2 min 34 sec" or "45 sec"
  String get durationLabel {
    if (durationSecs == null) return 'Active';
    if (durationSecs! < 60) return '${durationSecs}s';
    final m = durationSecs! ~/ 60;
    final s = durationSecs! % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  /// e.g. "Today 14:32" or "Mar 20 09:15"
  String get startedLabel {
    final now = DateTime.now();
    final dt = startedAt;
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    if (isToday) return 'Today $h:$min';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}  $h:$min';
  }
}

// ── Contact Model ─────────────────────────────────────────────────────────────
class TrustedContactModel {
  final String id;
  final String name;
  final String phone;
  final String category;
  final String? email;
  final String? relation;
  final String? notes;
  final RxBool _isSharing;

  TrustedContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.email,
    this.relation,
    this.notes,
    bool isSharing = false,
  }) : _isSharing = isSharing.obs;

  bool get isSharing => _isSharing.value;
  set isSharing(bool v) => _isSharing.value = v;

  factory TrustedContactModel.fromMap(Map<String, dynamic> map) {
    return TrustedContactModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      category: map['category'] as String,
      email: map['email'] as String?,
      relation: map['relation'] as String?,
      notes: map['notes'] as String?,
      isSharing: (map['is_sharing'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'id': id,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'category': category,
        'email': email,
        'relation': relation,
        'notes': notes,
        'is_sharing': isSharing,
      };
}

// ── Controller ────────────────────────────────────────────────────────────────
class ContactsController extends GetxController {
  static ContactsController get to => Get.find();

  final _db = Supabase.instance.client;

  final RxList<TrustedContactModel> contacts = <TrustedContactModel>[].obs;
  final RxList<SharingHistoryEntry> history = <SharingHistoryEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isHistoryLoading = false.obs;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          if (data.session != null) {
            fetchContacts();
            fetchHistory();
          }
          break;
        case AuthChangeEvent.signedOut:
          contacts.clear();
          history.clear();
          break;
        default:
          break;
      }
    });
  }

  // ── CONTACTS ──────────────────────────────────────────────────────────────

  Future<void> fetchContacts() async {
    if (_uid == null) return;
    try {
      isLoading.value = true;
      final rows = await _db
          .from('trusted_contacts')
          .select()
          .eq('user_id', _uid!)
          .order('created_at', ascending: true);
      contacts.value =
          (rows as List).map((r) => TrustedContactModel.fromMap(r)).toList();
    } catch (e) {
      _snackError('Failed to load contacts', e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addContact(TrustedContactModel contact) async {
    if (_uid == null) {
      Get.snackbar('❌ Not signed in', 'Please sign in first.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await _db.from('trusted_contacts').insert(contact.toMap(_uid!));
      contacts.add(contact);
    } catch (e) {
      _snackError('Failed to add contact', e);
    }
  }

  Future<void> removeContact(TrustedContactModel contact) async {
    try {
      await _db.from('trusted_contacts').delete().eq('id', contact.id);
      contacts.removeWhere((c) => c.id == contact.id);
    } catch (e) {
      _snackError('Failed to remove contact', e);
    }
  }

  // ── UPDATE CONTACT ────────────────────────────────────────────────────────

  Future<void> updateContact(TrustedContactModel updated) async {
    if (_uid == null) return;
    try {
      await _db
          .from('trusted_contacts')
          .update({
            'name': updated.name,
            'phone': updated.phone,
            'category': updated.category,
            'email': updated.email,
            'relation': updated.relation,
            'notes': updated.notes,
            'is_sharing': updated.isSharing,
          })
          .eq('id', updated.id)
          .eq('user_id', _uid!);

      final index = contacts.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        contacts[index] = updated;
        contacts.refresh();
      }
    } catch (e) {
      _snackError('Failed to update contact', e);
    }
  }

  // ── TOGGLE SHARING (writes history) ──────────────────────────────────────

  Future<void> toggleSharing(TrustedContactModel contact) async {
    if (_uid == null) return;
    final newValue = !contact.isSharing;
    try {
      // 1. Update trusted_contacts row
      await _db
          .from('trusted_contacts')
          .update({'is_sharing': newValue})
          .eq('id', contact.id);
      contact.isSharing = newValue;
      contacts.refresh();

      if (newValue) {
        // 2a. Sharing started → insert a new history row
        await _db.from('sharing_history').insert({
          'user_id': _uid!,
          'contact_id': contact.id,
          'contact_name': contact.name,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        // 2b. Sharing stopped → close the open row (no ended_at yet)
        final openRows = await _db
            .from('sharing_history')
            .select('id, started_at')
            .eq('user_id', _uid!)
            .eq('contact_id', contact.id)
            .filter('ended_at', 'is', 'null')
            .order('started_at', ascending: false)
            .limit(1);

        if ((openRows as List).isNotEmpty) {
          final row = openRows.first as Map<String, dynamic>;
          final started = DateTime.parse(row['started_at'] as String);
          final ended = DateTime.now().toUtc();
          final secs = ended.difference(started).inSeconds;

          await _db.from('sharing_history').update({
            'ended_at': ended.toIso8601String(),
            'duration_secs': secs,
          }).eq('id', row['id'] as String);
        }
      }

      // 3. Refresh history list
      await fetchHistory();

      // 4. Snackbar
      Get.snackbar(
        newValue ? '📍 Sharing On' : '🔕 Sharing Off',
        newValue
            ? 'Your location is now shared with ${contact.name}'
            : 'Location sharing stopped for ${contact.name}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: newValue ? Colors.green[600] : Colors.grey[700],
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      _snackError('Failed to update sharing', e);
    }
  }

  // ── HISTORY ───────────────────────────────────────────────────────────────

  Future<void> fetchHistory() async {
    if (_uid == null) return;
    try {
      isHistoryLoading.value = true;
      final rows = await _db
          .from('sharing_history')
          .select()
          .eq('user_id', _uid!)
          .order('started_at', ascending: false)
          .limit(50);
      history.value = (rows as List)
          .map((r) => SharingHistoryEntry.fromMap(r))
          .toList();
    } catch (e) {
      _snackError('Failed to load history', e);
    } finally {
      isHistoryLoading.value = false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> get contactNames => contacts.map((c) => c.name).toList();

  void _snackError(String title, Object e) {
    Get.snackbar('❌ $title', e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4));
  }
}