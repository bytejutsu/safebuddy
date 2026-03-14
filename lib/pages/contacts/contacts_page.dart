// lib/pages/contacts/contacts_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/contacts_controller.dart';
import 'chat.dart';
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  static const _blue = Color(0xFF2196F3);

  // FIXED: moved outside build() so it doesn't reset on every rebuild
  // This page is the Contact tab — index 4
  static final RxInt _selectedIndex = 4.obs;

  void _handleNavigation(int index) {
    if (index == _selectedIndex.value) return;
    _selectedIndex.value = index;
    switch (index) {
      case 0:
        Get.offAllNamed('/home');
        break;
      case 1:
        Get.offAllNamed('/safety');
        break;
      case 2:
        Get.offAllNamed('/settings');
        break;
      case 3:
        Get.offAllNamed('/profile');
        break;
      case 4:
        break; // already here
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ContactsController.to;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.offAllNamed('/home'),
        ),
        title: const Text(
          'Contacts you trust',
          style: TextStyle(
              color: _blue, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Obx(() => ctrl.contacts.isEmpty
          ? _buildEmptyState()
          : _buildList(context, ctrl)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddContact(context, ctrl),
        backgroundColor: _blue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: Obx(() => Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: _blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2)),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex.value,
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
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings'),
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

  Widget _buildList(BuildContext context, ContactsController ctrl) {
    final grouped = _grouped(ctrl.contacts);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        for (final entry in grouped.entries) ...[
          _buildCategoryHeader(entry.key),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: List.generate(entry.value.length, (i) {
                final contact = entry.value[i];
                final isLast = i == entry.value.length - 1;
                return Column(
                  children: [
                    _buildContactTile(context, contact, ctrl),
                    if (!isLast)
                      Divider(
                          height: 1,
                          indent: 70,
                          color: Colors.grey[100]),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Map<String, List<TrustedContactModel>> _grouped(
      List<TrustedContactModel> contacts) {
    final map = <String, List<TrustedContactModel>>{};
    const order = ['Family', 'Friends', 'Work', 'Emergency', 'Other'];
    for (final c in contacts) {
      map.putIfAbsent(c.category, () => []).add(c);
    }
    return Map.fromEntries(
      order
          .where((k) => map.containsKey(k))
          .map((k) => MapEntry(k, map[k]!)),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Family':
        return const Color(0xFF4FC3F7);
      case 'Friends':
        return const Color(0xFF81C784);
      case 'Work':
        return const Color(0xFFFFB74D);
      case 'Emergency':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF9575CD);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Family':
        return Icons.home_rounded;
      case 'Friends':
        return Icons.people_rounded;
      case 'Work':
        return Icons.work_rounded;
      case 'Emergency':
        return Icons.emergency_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: _blue.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.people_outline,
                size: 52, color: _blue.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          const Text('No trusted contacts yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            'Tap + to add people you trust\nwith your safety',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    final color = _categoryColor(category);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_categoryIcon(category), size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(category,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildContactTile(BuildContext context, TrustedContactModel contact,
      ContactsController ctrl) {
    final color = _categoryColor(contact.category);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Center(
          child: Text(_initials(contact.name),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15)),
        ),
      ),
      title: Text(contact.name,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(contact.phone,
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Call button ────────────────────────────────────────────────
          GestureDetector(
            onTap: () => Get.toNamed('/call', arguments: {
              'name': contact.name,
              'channel': 'safebuddy_${contact.id}',
            }),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.phone, size: 15, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 6),
          // ── SMS button ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () => showMessageSheet(context, contact, ctrl),            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.message,
                  size: 15, color: Colors.green),
            ),
          ),
          const SizedBox(width: 6),
          // ── Location toggle ────────────────────────────────────────────
          GestureDetector(
            onTap: () => ctrl.toggleSharing(contact),
            child: Obx(() => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: contact.isSharing
                        ? Colors.green.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    contact.isSharing
                        ? Icons.location_on
                        : Icons.location_off_outlined,
                    size: 16,
                    color: contact.isSharing ? Colors.green : Colors.grey,
                  ),
                )),
          ),
          const SizedBox(width: 6),
          // ── Delete button ──────────────────────────────────────────────
          GestureDetector(
            onTap: () => _deleteContact(context, contact, ctrl),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle),
              child:
                  const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchSms(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar(
        '❌ Error',
        'Could not open messages',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _deleteContact(BuildContext context, TrustedContactModel contact,
      ContactsController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Contact',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            Text('Remove ${contact.name} from your trusted contacts?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ctrl.removeContact(contact);
              Get.back();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddContact(BuildContext context, ContactsController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(
        onSave: (contact) {
          ctrl.addContact(contact);
          Navigator.pop(context);
          Get.snackbar(
            '✅ Contact Added',
            '${contact.name} has been added to your trusted contacts.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green[600],
            colorText: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
          );
        },
      ),
    );
  }
}

// ── Add Contact Bottom Sheet ──────────────────────────────────────────────────
class _AddContactSheet extends StatefulWidget {
  final void Function(TrustedContactModel) onSave;
  const _AddContactSheet({required this.onSave});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedCategory = 'Family';
  bool _shareLocation = false;
  bool _isSaving = false;

  static const _blue = Color(0xFF2196F3);
  static const _categories = [
    'Family',
    'Friends',
    'Work',
    'Emergency',
    'Other'
  ];

  Color _catColor(String cat) {
    switch (cat) {
      case 'Family':
        return const Color(0xFF4FC3F7);
      case 'Friends':
        return const Color(0xFF81C784);
      case 'Work':
        return const Color(0xFFFFB74D);
      case 'Emergency':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF9575CD);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _relationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final contact = TrustedContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      category: _selectedCategory,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      relation: _relationCtrl.text.trim().isEmpty
          ? null
          : _relationCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isSharing: _shareLocation,
    );
    widget.onSave(contact);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24)),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _blue.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.person_add,
                          color: _blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Add Trusted Contact',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Category',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final selected = cat == _selectedCategory;
                      final color = _catColor(cat);
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : color.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Text(cat,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : color)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel('Full Name *'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _nameCtrl,
                  hint: 'e.g. Sarah Johnson',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Phone Number *'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _phoneCtrl,
                  hint: 'e.g. xx xxx xxx',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Phone is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Email (optional)'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailCtrl,
                  hint: 'e.g. sarah@email.com',
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildLabel('Relation (optional)'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _relationCtrl,
                  hint: 'e.g. Mother, Partner, Best friend',
                  icon: Icons.favorite_border,
                ),
                const SizedBox(height: 16),
                _buildLabel('Notes (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Any additional info about this contact...',
                    hintStyle: TextStyle(
                        color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.notes_outlined,
                          color: Color(0xFF2196F3), size: 20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _blue, width: 1.5)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _shareLocation
                        ? Colors.green.withOpacity(0.06)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _shareLocation
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _shareLocation
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _shareLocation
                              ? Icons.location_on
                              : Icons.location_off_outlined,
                          size: 20,
                          color: _shareLocation
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Share location with this contact',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              _shareLocation
                                  ? 'They will see your location'
                                  : 'Location sharing is off',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _shareLocation,
                        onChanged: (v) =>
                            setState(() => _shareLocation = v),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline,
                            color: Colors.white),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Contact',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black54));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: _blue, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.red, width: 1.5)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}