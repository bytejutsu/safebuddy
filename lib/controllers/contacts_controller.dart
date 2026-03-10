// lib/controllers/contacts_controller.dart
import 'package:get/get.dart';

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
}

// ── Controller ────────────────────────────────────────────────────────────────
class ContactsController extends GetxController {
  static ContactsController get to => Get.find();

  final RxList<TrustedContactModel> contacts = <TrustedContactModel>[].obs;

  void addContact(TrustedContactModel contact) {
    contacts.add(contact);
  }

  void removeContact(TrustedContactModel contact) {
    contacts.removeWhere((c) => c.id == contact.id);
  }

  void toggleSharing(TrustedContactModel contact) {
    contact.isSharing = !contact.isSharing;
    contacts.refresh();
  }

  // List of contact names — used by emergency settings picker
  List<String> get contactNames => contacts.map((c) => c.name).toList();
}