import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/contacts_controller.dart';
import 'chat.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  static const _blue = Color(0xFF2196F3);
  static final RxSet<String> _expandedIds = <String>{}.obs;

  void _handleNavigation(int index) {
    switch (index) {
      case 0: Get.offAllNamed('/home'); break;
      case 1: Get.offAllNamed('/safety'); break;
      case 2: Get.offAllNamed('/profile'); break;
      case 3: break;
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
        title: const Text('Contacts you trust',
            style: TextStyle(
                color: _blue, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Obx(() {
            final pending = ctrl.receivedInvitations
                .where((i) => i.status == 'pending')
                .length;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: _blue),
                  onPressed: () =>
                      _showInvitationsSheet(context, ctrl),
                ),
                if (pending > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$pending',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      body: Obx(() => ctrl.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : ctrl.contacts.isEmpty
              ? _buildEmptyState()
              : _buildList(context, ctrl)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSearchContact(context, ctrl),
        backgroundColor: _blue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.person_search, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: _blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 3,
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
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile'),
            BottomNavigationBarItem(
                icon: Icon(Icons.contact_support_outlined),
                activeIcon: Icon(Icons.contact_support),
                label: 'Contact'),
          ],
        ),
      ),
    );
  }

  // ── Search contact by email ──────────────────────────────────────────────
  void _openSearchContact(BuildContext context, ContactsController ctrl) {
    final emailCtrl = TextEditingController();
    bool isSearching = false;
    Map<String, dynamic>? foundProfile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: _blue.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.person_search,
                            color: _blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('Find SafeBuddy User',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter email address...',
                      hintStyle: TextStyle(
                          color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: _blue, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _blue, width: 1.5)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isSearching
                          ? null
                          : () async {
                              final email =
                                  emailCtrl.text.trim().toLowerCase();
                              if (email.isEmpty) return;
                              setState(() {
                                isSearching = true;
                                foundProfile = null;
                              });
                              try {
                                final result =
                                    await ctrl.searchUserByEmail(email);
                                setState(() {
                                  isSearching = false;
                                  foundProfile = result;
                                });
                                if (result == null) {
                                  Get.snackbar(
                                    '❌ Not Found',
                                    'No SafeBuddy account found with this email.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    borderRadius: 12,
                                    margin: const EdgeInsets.all(16),
                                  );
                                }
                              } catch (e) {
                                setState(() => isSearching = false);
                              }
                            },
                      icon: isSearching
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search, color: Colors.white),
                      label: Text(
                        isSearching ? 'Searching...' : 'Search',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (foundProfile != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(
                            foundProfile!['avatar_url'],
                            foundProfile!['full_name'] ?? '',
                            size: 56,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  foundProfile!['full_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(foundProfile!['phone'] ?? '',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[500])),
                                Text(foundProfile!['email'] ?? '',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400])),
                              ],
                            ),
                          ),
                          if (ctrl.isAlreadyAdded(foundProfile!['id'] ?? ''))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Added',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            )
                          else
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                await _showAddContactSheet(
                                    context, ctrl, foundProfile!);
                              },
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_add,
                                    color: Colors.green, size: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Send invitation sheet ────────────────────────────────────────────────
  Future<void> _showAddContactSheet(
    BuildContext context,
    ContactsController ctrl,
    Map<String, dynamic> profile,
  ) async {
    String selectedCategory = 'Family';
    const categories = ['Family', 'Friends', 'Work', 'Emergency', 'Other'];

    Color catColor(String cat) {
      switch (cat) {
        case 'Family': return const Color(0xFF4FC3F7);
        case 'Friends': return const Color(0xFF81C784);
        case 'Work': return const Color(0xFFFFB74D);
        case 'Emergency': return const Color(0xFFE57373);
        default: return const Color(0xFF9575CD);
      }
    }

    final invStatus = ctrl.getInvitationStatus(profile['id'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Send Invitation',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'They will receive an invitation to accept or reject.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAvatar(
                      profile['avatar_url'],
                      profile['full_name'] ?? '',
                      size: 50,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile['full_name'] ?? 'Unknown',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text(profile['email'] ?? '',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (invStatus == 'pending') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Invitation already sent — waiting for response.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.orange)),
                        ),
                      ],
                    ),
                  ),
                ] else if (invStatus == 'rejected') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This user rejected your invitation.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
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
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        final selected = cat == selectedCategory;
                        final color = catColor(cat);
                        return GestureDetector(
                          onTap: () => setState(() => selectedCategory = cat),
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
                  const SizedBox(height: 24),
                  StatefulBuilder(
                    builder: (ctx2, setState2) {
                      bool isAdding = false;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isAdding
                              ? null
                              : () async {
                                  setState2(() => isAdding = true);
                                  final success = await ctrl.sendInvitation(
                                    receiverId: profile['id'],
                                    receiverEmail: profile['email'] ?? '',
                                    category: selectedCategory,
                                  );
                                  setState2(() => isAdding = false);
                                  if (success) {
                                    Navigator.pop(context);
                                    Get.snackbar(
                                      '📨 Invitation Sent',
                                      'Waiting for ${profile['full_name']} to accept.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.blue[600],
                                      colorText: Colors.white,
                                      borderRadius: 12,
                                      margin: const EdgeInsets.all(16),
                                    );
                                  }
                                },
                          icon: isAdding
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send, color: Colors.white),
                          label: Text(
                            isAdding ? 'Sending...' : 'Send Invitation',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Invitations sheet ────────────────────────────────────────────────────
  void _showInvitationsSheet(
      BuildContext context, ContactsController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Invitations',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  final received = ctrl.receivedInvitations;
                  final sent = ctrl.sentInvitations;

                  if (received.isEmpty && sent.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mail_outline,
                              size: 52, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No invitations yet',
                              style: TextStyle(
                                  fontSize: 15, color: Colors.grey[400])),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (received.isNotEmpty) ...[
                        const Text('Received',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _blue)),
                        const SizedBox(height: 10),
                        ...received.map((inv) => _buildInvitationTile(
                            context, inv, ctrl,
                            isReceived: true)),
                        const SizedBox(height: 20),
                      ],
                      if (sent.isNotEmpty) ...[
                        const Text('Sent',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _blue)),
                        const SizedBox(height: 10),
                        ...sent.map((inv) => _buildInvitationTile(
                            context, inv, ctrl,
                            isReceived: false)),
                      ],
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Invitation tile ──────────────────────────────────────────────────────
  Widget _buildInvitationTile(
    BuildContext context,
    InvitationModel inv,
    ContactsController ctrl, {
    required bool isReceived,
  }) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (inv.status) {
      case 'accepted':
        statusColor = Colors.green;
        statusLabel = 'Accepted';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(
                  null,
                  isReceived ? inv.senderName : inv.receiverEmail,
                  size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived ? inv.senderName : inv.receiverEmail,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isReceived ? inv.senderEmail : 'Invitation sent',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          if (isReceived && inv.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ctrl.rejectInvitation(inv);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ctrl.acceptInvitation(inv, 'Friends');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text('Accept',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Contact Profile Sheet ────────────────────────────────────────────────
  void _showContactProfile(
    BuildContext context,
    TrustedContactModel contact,
    ContactsController ctrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    _buildAvatar(
                      contact.avatarUrl,
                      contact.name,
                      size: 90,
                      color: _categoryColor(contact.category),
                    ),
                    const SizedBox(height: 12),
                    Text(contact.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _categoryColor(contact.category)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        contact.category,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor(contact.category)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 16),
              const Text('Contact Info',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _blue)),
              const SizedBox(height: 12),
              _profileInfoRow(Icons.phone_outlined, 'Phone', contact.phone),
              if (contact.email != null)
                _profileInfoRow(
                    Icons.email_outlined, 'Email', contact.email!),
              if (contact.relation != null)
                _profileInfoRow(Icons.favorite_border, 'Relation',
                    contact.relation!),
              if (contact.notes != null)
                _profileInfoRow(
                    Icons.notes_outlined, 'Notes', contact.notes!),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 16),
              const Text('Location Sharing',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _blue)),
              const SizedBox(height: 12),
              Obx(() => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: contact.isSharing
                          ? Colors.green.withOpacity(0.07)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: contact.isSharing
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          contact.isSharing
                              ? Icons.location_on_rounded
                              : Icons.location_off_outlined,
                          color: contact.isSharing
                              ? Colors.green
                              : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.isSharing
                                    ? 'You are sharing your location'
                                    : 'Location sharing is off',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: contact.isSharing
                                        ? Colors.green[700]
                                        : Colors.black87),
                              ),
                              Text(
                                contact.isSharing
                                    ? '${contact.name} can see your location'
                                    : 'Tap to share your location',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: contact.isSharing,
                          onChanged: (_) => ctrl.toggleSharing(contact),
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 16),
              const Text('Sharing History',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _blue)),
              const SizedBox(height: 12),
              Obx(() {
                final contactHistory =
                    ctrl.getHistoryForContact(contact.id);
                if (contactHistory.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No sharing history with ${contact.name} yet.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                  children: contactHistory.take(10).map((entry) {
                    final isActive = entry.endedAt == null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : _blue.withOpacity(0.07),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isActive
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_outlined,
                              size: 16,
                              color: isActive ? Colors.green : _blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.startedLabel,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                if (isActive)
                                  const Text('Currently active',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green)),
                              ],
                            ),
                          ),
                          Text(entry.durationLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.green
                                      : Colors.grey[600])),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showMessageSheet(context, contact, ctrl);
                      },
                      icon: const Icon(Icons.message_outlined, size: 18),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: BorderSide(color: _blue.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.toNamed('/call', arguments: {
                          'name': contact.name,
                          'phone': contact.phone,
                        });
                      },
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(
                            color: Colors.green.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _buildAvatar(String? avatarUrl, String name,
      {double size = 44, Color? color}) {
    final c = color ?? _blue;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withOpacity(0.15),
        border: size > 50 ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: size > 50
            ? [BoxShadow(color: c.withOpacity(0.2), blurRadius: 14,
                offset: const Offset(0, 4))]
            : null,
      ),
      child: avatarUrl != null
          ? ClipOval(
              child: Image.network(avatarUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(_initials(name),
                        style: TextStyle(color: c,
                            fontWeight: FontWeight.bold,
                            fontSize: size * 0.33)),
                  )))
          : Center(
              child: Text(_initials(name),
                  style: TextStyle(color: c,
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.33))),
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _blue),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2)
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Family': return const Color(0xFF4FC3F7);
      case 'Friends': return const Color(0xFF81C784);
      case 'Work': return const Color(0xFFFFB74D);
      case 'Emergency': return const Color(0xFFE57373);
      default: return const Color(0xFF9575CD);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Family': return Icons.home_rounded;
      case 'Friends': return Icons.people_rounded;
      case 'Work': return Icons.work_rounded;
      case 'Emergency': return Icons.emergency_rounded;
      default: return Icons.person_rounded;
    }
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
                BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 10, offset: const Offset(0, 2)),
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
                      Divider(height: 1, indent: 70, color: Colors.grey[100]),
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
      order.where((k) => map.containsKey(k)).map((k) => MapEntry(k, map[k]!)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                color: _blue.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.people_outline,
                size: 52, color: _blue.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          const Text('No trusted contacts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Tap the search button to find\nSafeBuddy users to add',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    final color = _categoryColor(category);
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_categoryIcon(category), size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(category,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildContactTile(BuildContext context, TrustedContactModel contact,
      ContactsController ctrl) {
    final color = _categoryColor(contact.category);
    return Obx(() {
      final isExpanded = _expandedIds.contains(contact.id);
      return Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () {
              if (isExpanded) {
                _expandedIds.remove(contact.id);
              } else {
                _expandedIds.add(contact.id);
              }
            },
            leading: GestureDetector(
              onTap: () => _showContactProfile(context, contact, ctrl),
              child: _buildAvatar(contact.avatarUrl, contact.name,
                  size: 44, color: color),
            ),
            title: Text(contact.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text(contact.phone,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey[400], size: 18),
                ),
                const SizedBox(width: 4),
                _iconBtn(
                  color: Colors.blue,
                  icon: Icons.phone,
                  onTap: () => Get.toNamed('/call', arguments: {
                    'name': contact.name,
                    'phone': contact.phone,
                  }),
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  color: Colors.green,
                  icon: Icons.message,
                  onTap: () => showMessageSheet(context, contact, ctrl),
                ),
                const SizedBox(width: 6),
                Obx(() => GestureDetector(
                      onTap: () => ctrl.toggleSharing(contact),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30, height: 30,
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
                          color: contact.isSharing
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    )),
                const SizedBox(width: 6),
                _iconBtn(
                  color: Colors.red,
                  icon: Icons.close,
                  onTap: () => _deleteContact(context, contact, ctrl),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contact.email != null)
                          _buildInfoRow(Icons.email_outlined, 'Email',
                              contact.email!, color),
                        if (contact.relation != null) ...[
                          if (contact.email != null)
                            Divider(height: 16, color: color.withOpacity(0.2)),
                          _buildInfoRow(Icons.favorite_border, 'Relation',
                              contact.relation!, color),
                        ],
                        if (contact.notes != null) ...[
                          if (contact.email != null || contact.relation != null)
                            Divider(height: 16, color: color.withOpacity(0.2)),
                          _buildInfoRow(Icons.notes_outlined, 'Notes',
                              contact.notes!, color),
                        ],
                        if (contact.email == null &&
                            contact.relation == null &&
                            contact.notes == null)
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey[400]),
                              const SizedBox(width: 8),
                              Text('No additional info saved',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[400])),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showContactProfile(context, contact, ctrl),
                        icon: Icon(Icons.person_outlined,
                            size: 16, color: color),
                        label: Text('View Profile',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600, color: color)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: color.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          backgroundColor: color.withOpacity(0.06),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  Widget _iconBtn({required Color color, required IconData icon,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Text('$label: ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }

  void _deleteContact(BuildContext context, TrustedContactModel contact,
      ContactsController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Contact',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove ${contact.name} from your trusted contacts?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ctrl.removeContact(contact);
              _expandedIds.remove(contact.id);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}