// lib/pages/settings/setting_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final RxBool isLocationSharingEnabled = true.obs;
  final RxBool isPeriodicalChecksEnabled = true.obs;
  final RxBool isAIProtectionEnabled = true.obs;
  final RxDouble periodicalCheckInterval = 0.3.obs;

  // This page is the Home tab — index 0
  final RxInt selectedIndex = 0.obs;

  late String _currentTime;
  late Timer _timer;

  static const _blue = Color(0xFF2196F3);

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _currentTime = _formatTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = _formatTime(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleNavigation(int index) {
    if (index == selectedIndex.value) return;
    selectedIndex.value = index;
    switch (index) {
      case 0:
        break; // already here
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
        automaticallyImplyLeading: false,
        title: Text(
          _currentTime,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/logo.png',
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.security,
                color: Color(0xFF2196F3),
                size: 28,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Obx(() => _BigCircleToggle(
                  value: isLocationSharingEnabled.value,
                  onChanged: (v) {
                    isLocationSharingEnabled.value = v;
                    if (!v) {
                      isPeriodicalChecksEnabled.value = false;
                      isAIProtectionEnabled.value = false;
                    }
                  },
                )),
            const SizedBox(height: 24),
            const Text(
              'share your location periodically with the persons you trust',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 36),
            Obx(() => _buildPillRow(
                  title: 'Periodical Checks',
                  value: isPeriodicalChecksEnabled,
                  enabled: isLocationSharingEnabled.value,
                )),
            const SizedBox(height: 16),
            Obx(() => _buildSlider(
                  value: periodicalCheckInterval,
                  enabled: isLocationSharingEnabled.value &&
                      isPeriodicalChecksEnabled.value,
                )),
            const SizedBox(height: 8),
            Obx(() => isLocationSharingEnabled.value
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'allow SafeBuddy to send you safety check notifications periodically',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isPeriodicalChecksEnabled.value
                            ? Colors.black54
                            : Colors.grey[400],
                        height: 1.4,
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
            const SizedBox(height: 36),
            Obx(() => _buildPillRow(
                  title: 'Enhanced AI Protection',
                  value: isAIProtectionEnabled,
                  enabled: isLocationSharingEnabled.value,
                )),
            const SizedBox(height: 40),
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
          )),
    );
  }

  Widget _buildPillRow({
    required String title,
    required RxBool value,
    required bool enabled,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: enabled ? Colors.black : Colors.grey[400],
            letterSpacing: 0.2,
          ),
        ),
        _PillToggle(
          value: value.value,
          onChanged: enabled ? (v) => value.value = v : null,
        ),
      ],
    );
  }

  Widget _buildSlider({required RxDouble value, required bool enabled}) {
    return Obx(() => SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTrackColor:
                enabled ? const Color(0xFF7B6FCD) : Colors.grey[300],
            inactiveTrackColor: Colors.grey[300],
            thumbColor: enabled ? const Color(0xFF7B6FCD) : Colors.grey[400],
            overlayColor: enabled
                ? const Color(0xFF7B6FCD).withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Slider(
            value: value.value,
            onChanged: enabled ? (v) => value.value = v : null,
          ),
        ));
  }
}

// ── Big Circle Toggle ─────────────────────────────────────────────────────────
class _BigCircleToggle extends StatelessWidget {
  const _BigCircleToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _fillBlue = Color(0xFF4FC3F7);
  static const _ringIndigo = Color(0xFF6360B7);
  static const _offFill = Color(0xFFB0BEC5);
  static const _offRing = Color(0xFF90A4AE);

  @override
  Widget build(BuildContext context) {
    final fill = value ? _fillBlue : _offFill;
    final ring = value ? _ringIndigo : _offRing;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: [
            BoxShadow(color: ring, spreadRadius: 6, blurRadius: 0),
            BoxShadow(
                color: ring.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              value ? 'ON' : 'OFF',
              key: ValueKey(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pill Toggle ───────────────────────────────────────────────────────────────
class _PillToggle extends StatelessWidget {
  const _PillToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _onGreen = Color(0xFF4CD964);
  static const _offGrey = Color(0xFFD1D1D6);
  static const _disabledGrey = Color(0xFFE5E5EA);
  static const _pillWidth = 72.0;
  static const _pillHeight = 34.0;
  static const _thumbSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final isOn = value;
    final isEnabled = onChanged != null;

    return GestureDetector(
      onTap: isEnabled ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _pillWidth,
        height: _pillHeight,
        decoration: BoxDecoration(
          color: !isEnabled ? _disabledGrey : (isOn ? _onGreen : _offGrey),
          borderRadius: BorderRadius.circular(_pillHeight / 2),
        ),
        child: Stack(
          children: [
            if (isOn && isEnabled)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text('ON',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: (isOn && isEnabled)
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: !isEnabled ? Colors.grey[300] : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: isEnabled
                        ? const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ]
                        : [],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}