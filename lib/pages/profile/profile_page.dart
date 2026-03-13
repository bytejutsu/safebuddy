// lib/pages/profile/profile_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _blue   = Color(0xFF2196F3);
  static const Color _red    = Color(0xFFE53935);
  static const Color _indigo = Color(0xFF6360B7);
  static const Color _green  = Color(0xFF4CAF50);

  // This page is the Profile tab — index 3
  final RxInt _navIndex = 3.obs;

  // Profile data
  String _name      = '';
  String _phone     = '';
  String _email     = '';
  String _dob       = '';
  String _address   = '';
  String _photoPath = '';

  // Controllers
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _dobCtrl   = TextEditingController();
  final TextEditingController _addrCtrl  = TextEditingController();

  // Edit states
  bool _editPhone  = false;
  bool _editEmail  = false;
  bool _editDob    = false;
  bool _editAddr   = false;
  bool _isSaving   = false;
  bool _isLoaded   = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name      = prefs.getString('profile_name')    ?? '';
      _phone     = prefs.getString('profile_phone')   ?? '';
      _email     = prefs.getString('profile_email')   ?? '';
      _dob       = prefs.getString('profile_dob')     ?? '';
      _address   = prefs.getString('profile_address') ?? '';
      _photoPath = prefs.getString('profile_photo')   ?? '';
      _phoneCtrl.text = _phone;
      _emailCtrl.text = _email;
      _dobCtrl.text   = _dob;
      _addrCtrl.text  = _address;
      _isLoaded = true;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name',    _name);
    await prefs.setString('profile_phone',   _phoneCtrl.text.trim());
    await prefs.setString('profile_email',   _emailCtrl.text.trim());
    await prefs.setString('profile_dob',     _dobCtrl.text.trim());
    await prefs.setString('profile_address', _addrCtrl.text.trim());
    if (_photoPath.isNotEmpty) {
      await prefs.setString('profile_photo', _photoPath);
    }
    setState(() {
      _phone     = _phoneCtrl.text.trim();
      _email     = _emailCtrl.text.trim();
      _dob       = _dobCtrl.text.trim();
      _address   = _addrCtrl.text.trim();
      _editPhone = false;
      _editEmail = false;
      _editDob   = false;
      _editAddr  = false;
      _isSaving  = false;
    });
    Get.snackbar(
      '✅ Saved!',
      'Your profile has been saved successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _green,
      colorText: Colors.white,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Choose Photo',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2196F3),
                    child: Icon(Icons.camera_alt, color: Colors.white)),
                title: const Text('Take a photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFF6360B7),
                    child: Icon(Icons.photo_library, color: Colors.white)),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.gallery);
                },
              ),
              if (_photoPath.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE53935),
                      child: Icon(Icons.delete, color: Colors.white)),
                  title: const Text('Remove photo'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('profile_photo');
                    setState(() => _photoPath = '');
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (picked != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo', picked.path);
        setState(() => _photoPath = picked.path);
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not pick image. Try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _red,
          colorText: Colors.white);
    }
  }

  void _onNav(int i) {
    if (i == _navIndex.value) return;
    _navIndex.value = i;
    switch (i) {
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
        break; // already here
      case 4:
        Get.offAllNamed('/contacts');
        break;
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _red),
              onPressed: () async {
                Navigator.pop(ctx);

                try {
                  await Supabase.instance.client.auth.signOut();

                  Get.snackbar(
                    'Signed out',
                    'You have been signed out successfully.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: _green,
                    colorText: Colors.white,
                    borderRadius: 12,
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  );

                  Get.offAllNamed('/signin');
                } on AuthException catch (e) {
                  Get.snackbar(
                    'Error',
                    e.message,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: _red,
                    colorText: Colors.white,
                    borderRadius: 12,
                    margin: const EdgeInsets.all(16),
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Could not sign out. Please try again.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: _red,
                    colorText: Colors.white,
                    borderRadius: 12,
                    margin: const EdgeInsets.all(16),
                  );
                }
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editName() {
    final c = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Name',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: _blue)),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Your full name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _blue),
              onPressed: () {
                if (c.text.trim().isNotEmpty) {
                  setState(() => _name = c.text.trim());
                }
                Navigator.pop(ctx);
              },
              child:
                  const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  Widget _buildAvatar() {
    Widget avatarContent;

    if (_photoPath.isNotEmpty && !kIsWeb) {
      avatarContent = ClipOval(
        child: Image.file(
          File(_photoPath),
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(_initials(_name),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _blue)),
          ),
        ),
      );
    } else {
      avatarContent = Center(
        child: Text(
          _name.isEmpty ? '?' : _initials(_name),
          style: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.bold, color: _blue),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _blue.withOpacity(0.12),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: avatarContent,
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _name.isNotEmpty ? _green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.check, size: 13, color: Colors.white),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _indigo,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
    bool editing,
    TextInputType kb,
    VoidCallback onEdit,
    VoidCallback onDone,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: editing
                ? TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: kb,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: hint,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _blue, width: 1.5),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        ctrl.text.isEmpty ? hint : ctrl.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ctrl.text.isEmpty
                              ? Colors.grey[400]
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: editing ? onDone : onEdit,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: editing
                    ? _green.withOpacity(0.12)
                    : _blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                editing ? Icons.check : Icons.edit,
                size: 16,
                color: editing ? _green : _blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.offAllNamed('/home'),
        ),
        title: const Text('Your Account',
            style: TextStyle(
                color: _blue,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: _blue),
            onPressed: () => Get.offAllNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            kBottomNavigationBarHeight +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          children: [
              Center(
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _editName,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _name.isEmpty ? 'Tap to set your name' : _name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _name.isEmpty
                                  ? Colors.grey[400]
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                    if (_name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 14, color: _green),
                              const SizedBox(width: 4),
                              Text(
                                'Profile saved',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Contact Info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildRow(
                      Icons.phone_outlined,
                      'Phone',
                      _phoneCtrl,
                      '(480) 555-0103',
                      _editPhone,
                      TextInputType.phone,
                          () => setState(() => _editPhone = true),
                          () => setState(() => _editPhone = false),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey[100],
                    ),
                    _buildRow(
                      Icons.email_outlined,
                      'Email',
                      _emailCtrl,
                      'your@email.com',
                      _editEmail,
                      TextInputType.emailAddress,
                          () => setState(() => _editEmail = true),
                          () => setState(() => _editEmail = false),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey[100],
                    ),
                    _buildRow(
                      Icons.cake_outlined,
                      'Birthday',
                      _dobCtrl,
                      'DD / MM / YYYY',
                      _editDob,
                      TextInputType.datetime,
                          () => setState(() => _editDob = true),
                          () => setState(() => _editDob = false),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey[100],
                    ),
                    _buildRow(
                      Icons.home_outlined,
                      'Address',
                      _addrCtrl,
                      'Your home address',
                      _editAddr,
                      TextInputType.text,
                          () => setState(() => _editAddr = true),
                          () => setState(() => _editAddr = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Profile',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sharing History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text(
                      'No sharing history yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Will be connected to database soon',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                  label: const Text(
                    'Sign out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Obx(() => Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: _blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2))
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _navIndex.value,
              type: BottomNavigationBarType.fixed,
              backgroundColor: _blue,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.6),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              onTap: _onNav,
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
}