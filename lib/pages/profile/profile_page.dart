// lib/pages/profile/profile_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _blue = Color(0xFF2196F3);
  static const Color _red = Color(0xFFE53935);
  static const Color _indigo = Color(0xFF6360B7);
  static const Color _green = Color(0xFF4CAF50);

  final RxInt _navIndex = 3.obs;
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  StreamSubscription<AuthState>? _authSub;

  String _name = '';
  String _phone = '';
  String _email = '';
  String _avatarUrl = '';

  bool _editPhone = false;
  bool _editEmail = false;
  bool _isLoaded = false;
  bool _isSaving = false;

  User? get _currentUser => _supabase.auth.currentUser;

  bool get _hasValidPhone => _phoneCtrl.text.trim().isNotEmpty;

  bool get _isProfileComplete =>
      _name.trim().isNotEmpty && _phone.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_refreshIndicators);
    _loadProfile();

    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.userUpdated ||
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        _syncAuthEmail();
      }

      if (data.event == AuthChangeEvent.signedOut) {
        Get.offAllNamed('/signin');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _phoneCtrl.removeListener(_refreshIndicators);
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _refreshIndicators() {
    if (!mounted) return;
    setState(() {});
  }

  bool _isValidEmailFormat(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  Future<void> _syncAuthEmail() async {
    final email = _currentUser?.email ?? '';
    if (!mounted) return;

    setState(() {
      _email = email;
      _emailCtrl.text = email;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final user = _currentUser;
      if (user == null) {
        Get.offAllNamed('/signin');
        return;
      }

      final List<dynamic> rows = await _supabase
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', user.id)
          .limit(1);

      if (rows.isEmpty) {
        await _supabase.from('profiles').insert({'id': user.id});
      }

      final List<dynamic> refreshedRows = await _supabase
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', user.id)
          .limit(1);

      final Map<String, dynamic>? profile = refreshedRows.isNotEmpty
          ? refreshedRows.first as Map<String, dynamic>
          : null;

      if (!mounted) return;

      setState(() {
        _name = (profile?['full_name'] as String?) ?? '';
        _phone = (profile?['phone'] as String?) ?? '';
        _avatarUrl = (profile?['avatar_url'] as String?) ?? '';
        _email = user.email ?? '';

        _phoneCtrl.text = _phone;
        _emailCtrl.text = _email;

        _isLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoaded = true;
      });

      Get.snackbar(
        'Error',
        'Could not load profile data.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> values) async {
    final user = _currentUser;
    if (user == null) {
      Get.offAllNamed('/signin');
      return;
    }

    await _supabase.from('profiles').update(values).eq('id', user.id);
  }

  Future<void> _saveName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    try {
      setState(() => _isSaving = true);

      await _updateProfile({'full_name': trimmed});

      if (!mounted) return;
      setState(() {
        _name = trimmed;
      });

      Get.snackbar(
        'Saved',
        'Your name has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not save your name.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _savePhone() async {
    final trimmed = _phoneCtrl.text.trim();

    try {
      setState(() => _isSaving = true);

      await _updateProfile({'phone': trimmed});

      if (!mounted) return;
      setState(() {
        _phone = trimmed;
        _editPhone = false;
      });

      Get.snackbar(
        'Saved',
        'Your phone number has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not save your phone number.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveEmail() async {
    final user = _currentUser;
    if (user == null) {
      Get.offAllNamed('/signin');
      return;
    }

    final newEmail = _emailCtrl.text.trim();
    final currentEmail = user.email?.trim() ?? '';

    if (newEmail.isEmpty) {
      Get.snackbar(
        'Invalid email',
        'Email cannot be empty.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
      return;
    }

    if (!_isValidEmailFormat(newEmail)) {
      Get.snackbar(
        'Invalid email',
        'Please enter a valid email address.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
      return;
    }

    if (newEmail.toLowerCase() == currentEmail.toLowerCase()) {
      setState(() => _editEmail = false);
      return;
    }

    try {
      setState(() => _isSaving = true);

      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      if (!mounted) return;
      setState(() {
        _editEmail = false;
      });

      Get.snackbar(
        'Confirm email change',
        'Check your inbox to confirm the new login email.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } on AuthException catch (e) {
      String message = e.message;
      final lower = e.message.toLowerCase();

      if (lower.contains('invalid') && lower.contains('email')) {
        message =
        'Supabase rejected the email change request. Check the Auth email change settings and make sure the account email in Supabase Auth is valid.';
      }

      if (!mounted) return;
      setState(() {
        _emailCtrl.text = currentEmail;
        _editEmail = false;
      });

      Get.snackbar(
        'Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _emailCtrl.text = currentEmail;
        _editEmail = false;
      });

      Get.snackbar(
        'Error',
        'Could not update your email.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: _blue,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Take a photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: _indigo,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.gallery);
                },
              ),
              if (_avatarUrl.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: _red,
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  title: const Text('Remove photo'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _removeAvatar();
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
    final user = _currentUser;
    if (user == null) {
      Get.offAllNamed('/signin');
      return;
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isSaving = true);

      final String storagePath = '${user.id}/avatar.jpg';

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await _supabase.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );
      } else {
        await _supabase.storage.from('avatars').upload(
          storagePath,
          File(picked.path),
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );
      }

      final String publicUrl =
      _supabase.storage.from('avatars').getPublicUrl(storagePath);

      final String versionedUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await _updateProfile({'avatar_url': versionedUrl});

      if (!mounted) return;
      setState(() {
        _avatarUrl = versionedUrl;
      });

      Get.snackbar(
        'Saved',
        'Your profile photo has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not upload the image.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    final user = _currentUser;
    if (user == null) {
      Get.offAllNamed('/signin');
      return;
    }

    try {
      setState(() => _isSaving = true);

      await _supabase.storage.from('avatars').remove([
        '${user.id}/avatar.jpg',
      ]);

      await _updateProfile({'avatar_url': null});

      if (!mounted) return;
      setState(() {
        _avatarUrl = '';
      });

      Get.snackbar(
        'Removed',
        'Your profile photo has been removed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not remove the profile photo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
        break;
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
                  await _supabase.auth.signOut();

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
    final controller = TextEditingController(text: _name);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Name',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _blue,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Your full name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _blue),
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;

                Navigator.pop(ctx);
                await _saveName(value);
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String _initials(String n) {
    final parts =
    n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Widget _buildAvatar() {
    Widget avatarContent;

    if (_avatarUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.network(
          _avatarUrl,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              _initials(_name),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _blue,
              ),
            ),
          ),
        ),
      );
    } else {
      avatarContent = Center(
        child: Text(
          _initials(_name),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: _blue,
          ),
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
                offset: const Offset(0, 4),
              ),
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
              color: _hasValidPhone ? _green : Colors.grey,
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
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
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
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: _blue,
                    width: 1.5,
                  ),
                ),
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
        title: const Text(
          'Your Account',
          style: TextStyle(
            color: _blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: _blue),
            onPressed: () => Get.offAllNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        if (_isProfileComplete)
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
                                    'Profile complete',
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
                          'xx xxx xxx',
                          _editPhone,
                          TextInputType.phone,
                              () => setState(() => _editPhone = true),
                              () {
                            _savePhone();
                          },
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
                              () {
                            _saveEmail();
                          },
                        ),
                      ],
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
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
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
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
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
                ],
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.08),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(
            () => Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: _blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
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
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: 'Safety',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.contact_support_outlined),
                activeIcon: Icon(Icons.contact_support),
                label: 'Contact',
              ),
            ],
          ),
        ),
      ),
    );
  }
}