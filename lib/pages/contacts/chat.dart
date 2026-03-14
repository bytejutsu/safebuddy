// lib/pages/contacts/chat.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/contacts_controller.dart';

// ── Public helper ─────────────────────────────────────────────────────────────
void showMessageSheet(
  BuildContext context,
  TrustedContactModel contact,
  ContactsController ctrl,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MessageSheet(contact: contact, ctrl: ctrl),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────
class _MessageSheet extends StatefulWidget {
  final TrustedContactModel contact;
  final ContactsController ctrl;

  const _MessageSheet({required this.contact, required this.ctrl});

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  final _msgCtrl = TextEditingController();
  static const _blue = Color(0xFF2196F3);

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Family':    return const Color(0xFF4FC3F7);
      case 'Friends':   return const Color(0xFF81C784);
      case 'Work':      return const Color(0xFFFFB74D);
      case 'Emergency': return const Color(0xFFE57373);
      default:          return const Color(0xFF9575CD);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  static const _quickReplies = [
    '👋 Hey, are you okay?',
    '📍 I am sharing my location with you.',
    '🆘 I need help, please call me!',
    '✅ I am safe, don\'t worry.',
    '🕐 I\'ll be there soon.',
  ];

  Future<void> _sendSms(String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: widget.contact.phone,
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar('❌ Error', 'Could not open messages',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          borderRadius: 12,
          margin: const EdgeInsets.all(16));
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final ctrl    = widget.ctrl;
    final color   = _categoryColor(contact.category);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Contact header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(contact.name),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.name,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(contact.phone,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            contact.category,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[100]),
            const SizedBox(height: 14),

            // ── Location sharing card ──────────────────────────────────────
            // Snackbar is handled inside ctrl.toggleSharing — do NOT add one here
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Obx(() {
                final sharing = contact.isSharing;
                return GestureDetector(
                  onTap: () => ctrl.toggleSharing(contact),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: sharing
                          ? Colors.green.withOpacity(0.07)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sharing
                            ? Colors.green.withOpacity(0.35)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: sharing
                                ? Colors.green.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            sharing
                                ? Icons.location_on_rounded
                                : Icons.location_off_outlined,
                            size: 20,
                            color: sharing ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sharing
                                    ? 'Location sharing is ON'
                                    : 'Location sharing is OFF',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: sharing
                                      ? Colors.green[700]
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sharing
                                    ? '${contact.name} can see your location'
                                    : 'Tap to share your location',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: sharing,
                          onChanged: (_) => ctrl.toggleSharing(contact),
                          activeColor: Colors.green,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // ── Quick replies ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quick messages',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500])),
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _quickReplies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    _msgCtrl.text = _quickReplies[i];
                    _msgCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _msgCtrl.text.length));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _blue.withOpacity(0.2), width: 1),
                    ),
                    child: Text(_quickReplies[i],
                        style: const TextStyle(
                            fontSize: 12,
                            color: _blue,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Compose + send ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: Colors.grey[400], fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: _blue, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      final text = _msgCtrl.text.trim();
                      if (text.isEmpty) return;
                      _sendSms(text);
                    },
                    child: Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}