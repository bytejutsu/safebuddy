import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RxBool isLocationSharingEnabled = true.obs;
  final RxBool isPeriodicalChecksEnabled = true.obs;
  final RxBool isAIProtectionEnabled = true.obs;
  final RxInt periodicalCheckMinutes = 5.obs; // default = 5 min

  bool _prevPeriodical = true;
  bool _prevAI = true;

  final RxInt selectedIndex = 0.obs;

  static const _blue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleNavigation(int index) {
    if (index == selectedIndex.value) return;
    selectedIndex.value = index;
    switch (index) {
      case 0:
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
        Get.offAllNamed('/contacts');
        break;
    }
  }

  /// Full readable label e.g. "Every 5 min" / "Every 1h 30m"
  String _minuteLabel(int m) {
    if (m < 60) return 'Every $m min';
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) return 'Every ${h}h';
    return 'Every ${h}h ${rem}m';
  }

  /// Short label for the thumb bubble e.g. "5m" / "1h" / "1h30"
  String _minuteShort(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) return '${h}h';
    return '${h}h${rem}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: null,
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
                    if (!v) {
                      _prevPeriodical = isPeriodicalChecksEnabled.value;
                      _prevAI = isAIProtectionEnabled.value;
                      isPeriodicalChecksEnabled.value = false;
                      isAIProtectionEnabled.value = false;
                    } else {
                      isPeriodicalChecksEnabled.value = _prevPeriodical;
                      isAIProtectionEnabled.value = _prevAI;
                    }
                    isLocationSharingEnabled.value = v;
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
                  minutes: periodicalCheckMinutes,
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

  Widget _buildSlider({required RxInt minutes, required bool enabled}) {
    const ticks = [1, 15, 30, 60, 90, 120];

    return Obx(() {
      final currentMinutes = minutes.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live badge
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFF7B6FCD).withValues(alpha: 0.12)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: enabled
                        ? const Color(0xFF7B6FCD).withValues(alpha: 0.35)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: enabled
                          ? const Color(0xFF7B6FCD)
                          : Colors.grey[400],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _minuteLabel(currentMinutes),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? const Color(0xFF7B6FCD)
                            : Colors.grey[400],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 5,
              thumbShape: _BubbleThumbShape(
                label: _minuteShort(currentMinutes),
                enabled: enabled,
              ),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 22),
              activeTrackColor:
                  enabled ? const Color(0xFF7B6FCD) : Colors.grey[300],
              inactiveTrackColor: Colors.grey[200],
              thumbColor:
                  enabled ? const Color(0xFF7B6FCD) : Colors.grey[400],
              overlayColor: enabled
                  ? const Color(0xFF7B6FCD).withValues(alpha: 0.12)
                  : Colors.transparent,
              tickMarkShape:
                  const RoundSliderTickMarkShape(tickMarkRadius: 3),
              activeTickMarkColor:
                  Colors.white.withValues(alpha: enabled ? 0.8 : 0.0),
              inactiveTickMarkColor:
                  Colors.grey[400]!.withValues(alpha: enabled ? 1.0 : 0.0),
            ),
            child: Slider(
              min: 1,
              max: 120,
              divisions: 119,
              value: currentMinutes.toDouble(),
              onChanged: enabled ? (v) => minutes.value = v.round() : null,
            ),
          ),

          // Tick labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ticks.map((t) {
                final isActive = enabled && currentMinutes >= t;
                return Text(
                  t == 1
                      ? '1m'
                      : t >= 60
                          ? '${t ~/ 60}h'
                          : '${t}m',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF7B6FCD)
                        : Colors.grey[400],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom thumb that shows the current value inside a pill bubble
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleThumbShape extends SliderComponentShape {
  final String label;
  final bool enabled;

  const _BubbleThumbShape({required this.label, required this.enabled});

  static const _purple = Color(0xFF7B6FCD);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(48, 32);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    final pillW = (label.length * 8.0 + 20).clamp(44.0, 72.0);
    const pillH = 26.0;
    const stemH = 6.0;
    const r = pillH / 2;

    final fillColor = enabled ? _purple : Colors.grey[400]!;

    // Shadow
    final shadowPaint = Paint()
      ..color = fillColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -(pillH / 2 + stemH + 1)),
        width: pillW,
        height: pillH,
      ),
      const Radius.circular(r),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // Pill body
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -(pillH / 2 + stemH)),
        width: pillW,
        height: pillH,
      ),
      const Radius.circular(r),
    );
    canvas.drawRRect(pillRect, Paint()..color = fillColor);

    // Stem triangle pointing down
    final stemPath = Path()
      ..moveTo(center.dx - 5, center.dy - stemH)
      ..lineTo(center.dx + 5, center.dy - stemH)
      ..lineTo(center.dx, center.dy - 1)
      ..close();
    canvas.drawPath(stemPath, Paint()..color = fillColor);

    // Circle thumb dot
    canvas.drawCircle(
        center, 7, Paint()..color = enabled ? _purple : Colors.grey[400]!);
    canvas.drawCircle(
        center, 4, Paint()..color = Colors.white.withValues(alpha: 0.9));

    // Label text
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      center.translate(
        -tp.width / 2,
        -(pillH / 2 + stemH + tp.height / 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
                color: ring.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 4),
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

class _PillToggle extends StatelessWidget {
  const _PillToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _onGreen = Color(0xFF4CD964);
  static const _offGrey = Color(0xFFAAAAAA);
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
            if (!isOn && isEnabled)
              const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('OFF',
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