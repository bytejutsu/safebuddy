// lib/controllers/contacts_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
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
  final RxBool isLoading = false.obs;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          if (data.session != null) fetchContacts();
          break;
        case AuthChangeEvent.signedOut:
          contacts.clear();
          break;
        default:
          break;
      }
    });
  }

  // ── READ ──────────────────────────────────────────────────────────────────

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

  // ── CREATE ────────────────────────────────────────────────────────────────

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

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> removeContact(TrustedContactModel contact) async {
    try {
      await _db.from('trusted_contacts').delete().eq('id', contact.id);
      contacts.removeWhere((c) => c.id == contact.id);
    } catch (e) {
      _snackError('Failed to remove contact', e);
    }
  }

  // ── UPDATE (sharing toggle) ───────────────────────────────────────────────
  // Snackbar lives HERE so it always uses the correct newValue — not in the UI.

  Future<void> toggleSharing(TrustedContactModel contact) async {
    final newValue = !contact.isSharing; // capture BEFORE any await
    try {
      await _db
          .from('trusted_contacts')
          .update({'is_sharing': newValue})
          .eq('id', contact.id);
      contact.isSharing = newValue;
      contacts.refresh();
      // Show feedback only after Supabase confirms the update
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> get contactNames => contacts.map((c) => c.name).toList();

  void _snackError(String title, Object e) {
    Get.snackbar('❌ $title', e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4));
  }
}