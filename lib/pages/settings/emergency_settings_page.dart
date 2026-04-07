import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/contacts_controller.dart';

class EmergencySettingsPage extends StatefulWidget {
  const EmergencySettingsPage({super.key});

  @override
  State<EmergencySettingsPage> createState() => _EmergencySettingsPageState();
}

class _EmergencySettingsPageState extends State<EmergencySettingsPage> {
  final RxInt missedChecksThreshold = 5.obs;
  final RxString selectedContact = ''.obs;

  final RxInt selectedIndex = 2.obs;

  final ContactsController _contactsCtrl = ContactsController.to;

  static const _blue = Color(0xFF2196F3);
  static const _green = Color(0xFF4CAF50);

  void _handleNavigation(int index) {
    if (index == selectedIndex.value) return;
    selectedIndex.value = index;
    switch (index) {
      case 0:
        Get.offAllNamed('/home');
        break;
      case 1:
        Get.offAllNamed('/safety');
        break;
      case 2:
        break; 
      case 3:
        Get.offAllNamed('/profile');
        break;
      case 4:
        Get.offAllNamed('/contacts');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _blue, size: 28),
          onPressed: () => Get.offAllNamed('/home'),
        ),
        title: const Text(
          'Emergency Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call emergency',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _blue,
              ),
            ),
            const SizedBox(height: 20),
            Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CounterButton(
                      icon: Icons.remove,
                      color: _green,
                      onTap: () {
                        if (missedChecksThreshold.value > 1) {
                          missedChecksThreshold.value--;
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 56,
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${missedChecksThreshold.value}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CounterButton(
                      icon: Icons.add,
                      color: _green,
                      onTap: () => missedChecksThreshold.value++,
                    ),
                  ],
                )),
            const SizedBox(height: 14),
            Obx(() => Text(
                  'Emergency will be contacted if ${missedChecksThreshold.value} check notifications are missed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                )),
            const SizedBox(height: 36),
            const Text(
              'Emergency contact',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _blue,
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              final names = _contactsCtrl.contactNames;

              if (selectedContact.value.isNotEmpty &&
                  !names.contains(selectedContact.value)) {
                selectedContact.value = '';
              }

              return Center(
                child: GestureDetector(
                  onTap: names.isEmpty
                      ? () => Get.snackbar(
                            'No contacts',
                            'Go to the Contacts tab and add a trusted contact first.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: _blue,
                            colorText: Colors.white,
                            borderRadius: 12,
                            margin: const EdgeInsets.all(16),
                          )
                      : () => _showContactPicker(context, names),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(24),
                      color: names.isEmpty ? Colors.grey[100] : Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          names.isEmpty
                              ? 'No contacts added yet'
                              : selectedContact.value.isEmpty
                                  ? 'Select contact'
                                  : selectedContact.value,
                          style: TextStyle(
                            fontSize: 15,
                            color: (names.isEmpty ||
                                    selectedContact.value.isEmpty)
                                ? Colors.grey[500]
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: names.isEmpty
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Obx(() => _contactsCtrl.contacts.isEmpty
                ? Center(
                    child: Text(
                      'Add contacts in the Contacts tab to select one here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          height: 1.5),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
      bottomNavigationBar: Obx(() => Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: selectedIndex.value,
              type: BottomNavigationBarType.fixed,
              backgroundColor: _blue,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withValues(alpha: 0.6),
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

  void _showContactPicker(BuildContext context, List<String> names) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Emergency Contact',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...names.map(
            (name) => Obx(() => ListTile(
                  title: Text(name),
                  leading: const Icon(Icons.person_outline),
                  trailing: selectedContact.value == name
                      ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                      : null,
                  onTap: () {
                    selectedContact.value = name;
                    Navigator.pop(context);
                  },
                )),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}