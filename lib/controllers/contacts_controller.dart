import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharingHistoryEntry {
  final String id;
  final String contactId;
  final String contactName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSecs;

  SharingHistoryEntry({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.startedAt,
    this.endedAt,
    this.durationSecs,
  });

  factory SharingHistoryEntry.fromMap(Map<String, dynamic> m) {
    return SharingHistoryEntry(
      id: m['id'] as String,
      contactId: m['contact_id'] as String,
      contactName: m['contact_name'] as String,
      startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
      endedAt: m['ended_at'] != null
          ? DateTime.parse(m['ended_at'] as String).toLocal()
          : null,
      durationSecs: m['duration_secs'] as int?,
    );
  }

  String get durationLabel {
    if (durationSecs == null) return 'Active';
    if (durationSecs! < 60) return '${durationSecs}s';
    final m = durationSecs! ~/ 60;
    final s = durationSecs! % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String get startedLabel {
    final now = DateTime.now();
    final dt = startedAt;
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    if (isToday) return 'Today $h:$min';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}  $h:$min';
  }
}

class InvitationModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String senderEmail;
  final String receiverEmail;
  final String status;
  final DateTime createdAt;

  InvitationModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.senderEmail,
    required this.receiverEmail,
    required this.status,
    required this.createdAt,
  });

  factory InvitationModel.fromMap(Map<String, dynamic> m) {
    return InvitationModel(
      id: m['id'] as String,
      senderId: m['sender_id'] as String,
      receiverId: m['receiver_id'] as String,
      senderName: m['sender_name'] as String? ?? 'Unknown',
      senderEmail: m['sender_email'] as String? ?? '',
      receiverEmail: m['receiver_email'] as String? ?? '',
      status: m['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    );
  }
}

class TrustedContactModel {
  final String id;
  final String name;
  final String phone;
  final String category;
  final String? email;
  final String? relation;
  final String? notes;
  final String? avatarUrl;
  final String? profileId;
  final RxBool _isSharing;

  TrustedContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.email,
    this.relation,
    this.notes,
    this.avatarUrl,
    this.profileId,
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
      avatarUrl: map['avatar_url'] as String?,
      profileId: map['profile_id'] as String?,
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
        'avatar_url': avatarUrl,
        'profile_id': profileId,
        'is_sharing': isSharing,
      };
}

class ContactsController extends GetxController {
  static ContactsController get to => Get.find();

  final _db = Supabase.instance.client;

  final RxList<TrustedContactModel> contacts = <TrustedContactModel>[].obs;
  final RxList<SharingHistoryEntry> history = <SharingHistoryEntry>[].obs;
  final RxList<InvitationModel> receivedInvitations = <InvitationModel>[].obs;
  final RxList<InvitationModel> sentInvitations = <InvitationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isHistoryLoading = false.obs;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  void onInit() {
    super.onInit();
    _db.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          if (data.session != null) {
            fetchContacts();
            fetchHistory();
            fetchInvitations();
            _listenToInvitations();
            _listenToContacts();
          }
          break;
        case AuthChangeEvent.signedOut:
          contacts.clear();
          history.clear();
          receivedInvitations.clear();
          sentInvitations.clear();
          break;
        default:
          break;
      }
    });
  }

  void _listenToContacts() {
    if (_uid == null) return;
    _db
        .channel('contacts_channel_$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trusted_contacts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _uid!,
          ),
          callback: (payload) async {
            await fetchContacts();
          },
        )
        .subscribe();
  }

  void _listenToInvitations() {
    if (_uid == null) return;
    _db
        .channel('invitations_channel_$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invitations',
          callback: (payload) async {
            await fetchInvitations();
          },
        )
        .subscribe();
  }

  Future<void> fetchInvitations() async {
    if (_uid == null) return;
    try {
      final res = await _db
          .from('invitations')
          .select()
          .or('sender_id.eq.$_uid,receiver_id.eq.$_uid')
          .order('created_at', ascending: false);

      final all =
          (res as List).map((r) => InvitationModel.fromMap(r)).toList();

      final newSent = all.where((i) => i.senderId == _uid).toList();
      for (final inv in newSent) {
        final old = sentInvitations.where((i) => i.id == inv.id).toList();
        if (old.isNotEmpty &&
            old.first.status == 'pending' &&
            inv.status == 'accepted') {
          await fetchContacts();
          Get.snackbar(
            '✅ Invitation Accepted!',
            '${inv.receiverEmail} accepted your invitation!',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green[600],
            colorText: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          );
        } else if (old.isNotEmpty &&
            old.first.status == 'pending' &&
            inv.status == 'rejected') {
          Get.snackbar(
            '❌ Invitation Rejected',
            '${inv.receiverEmail} rejected your invitation.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          );
        }
      }

      receivedInvitations.value =
          all.where((i) => i.receiverId == _uid).toList();
      sentInvitations.value = newSent;
    } catch (e) {
      debugPrint('Failed to fetch invitations: $e');
    }
  }

  Future<bool> sendInvitation({
    required String receiverId,
    required String receiverEmail,
    required String category,
  }) async {
    if (_uid == null) return false;
    try {
      final existing = await _db
          .from('invitations')
          .select()
          .eq('sender_id', _uid!)
          .eq('receiver_id', receiverId)
          .eq('status', 'pending')
          .limit(1);

      if ((existing as List).isNotEmpty) {
        Get.snackbar(
          '⚠️ Already Sent',
          'You already sent an invitation to this user.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          borderRadius: 12,
          margin: const EdgeInsets.all(16),
        );
        return false;
      }

      final senderProfile = await _db
          .from('profiles')
          .select()
          .eq('id', _uid!)
          .limit(1);

      final sender = (senderProfile as List).isNotEmpty
          ? senderProfile.first as Map<String, dynamic>
          : <String, dynamic>{};

      await _db.from('invitations').insert({
        'sender_id': _uid,
        'receiver_id': receiverId,
        'sender_name': sender['full_name'] ?? 'SafeBuddy User',
        'sender_email': sender['email'] ?? '',
        'receiver_email': receiverEmail,
        'status': 'pending',
      });

      await fetchInvitations();
      return true;
    } catch (e) {
      _snackError('Failed to send invitation', e);
      return false;
    }
  }

  Future<void> acceptInvitation(
      InvitationModel invitation, String category) async {
    if (_uid == null) return;
    try {
      await _db
          .from('invitations')
          .update({'status': 'accepted'})
          .eq('id', invitation.id);

      // Add sender to receiver's contacts
      final senderProfile = await _db
          .from('profiles')
          .select()
          .eq('id', invitation.senderId)
          .limit(1);

      if ((senderProfile as List).isNotEmpty) {
        final sender = senderProfile.first as Map<String, dynamic>;
        final contact = TrustedContactModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: sender['full_name'] ?? invitation.senderName,
          phone: sender['phone'] ?? '',
          category: category,
          email: sender['email'] ?? invitation.senderEmail,
          avatarUrl: sender['avatar_url'],
          profileId: invitation.senderId,
        );
        await addContact(contact);
      }

      // Add receiver to sender's contacts via RPC
      final receiverProfile = await _db
          .from('profiles')
          .select()
          .eq('id', invitation.receiverId)
          .limit(1);

      if ((receiverProfile as List).isNotEmpty) {
        final receiver = receiverProfile.first as Map<String, dynamic>;
        await _db.rpc('add_contact_for_user', params: {
          'p_user_id': invitation.senderId,
          'p_id': '${DateTime.now().millisecondsSinceEpoch}1',
          'p_name': receiver['full_name'] ?? 'SafeBuddy User',
          'p_phone': receiver['phone'] ?? '',
          'p_category': category,
          'p_email': receiver['email'] ?? '',
          'p_avatar_url': receiver['avatar_url'] ?? '',
          'p_profile_id': invitation.receiverId,
        });
      }

      await fetchInvitations();
      await fetchContacts();

      Get.snackbar(
        '✅ Accepted',
        'You are now connected with ${invitation.senderName}!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[600],
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      _snackError('Failed to accept invitation', e);
    }
  }

  Future<void> rejectInvitation(InvitationModel invitation) async {
    if (_uid == null) return;
    try {
      await _db
          .from('invitations')
          .update({'status': 'rejected'})
          .eq('id', invitation.id);

      await fetchInvitations();

      Get.snackbar(
        '❌ Rejected',
        'You rejected the invitation from ${invitation.senderName}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      _snackError('Failed to reject invitation', e);
    }
  }

  String? getInvitationStatus(String profileId) {
    final sent =
        sentInvitations.where((i) => i.receiverId == profileId).toList();
    if (sent.isEmpty) return null;
    return sent.first.status;
  }

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

  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      final currentUserId = _db.auth.currentUser?.id;
      final res = await _db
          .from('profiles')
          .select()
          .eq('email', email.trim().toLowerCase())
          .neq('id', currentUserId ?? '')
          .limit(1);

      if ((res as List).isNotEmpty) {
        return res.first as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _snackError('Failed to search user', e);
      return null;
    }
  }

  bool isAlreadyAdded(String profileId) {
    return contacts.any((c) => c.profileId == profileId);
  }

  Future<void> addContact(TrustedContactModel contact) async {
    if (_uid == null) return;
    try {
      await _db.from('trusted_contacts').insert(contact.toMap(_uid!));
      contacts.add(contact);
    } catch (e) {
      _snackError('Failed to add contact', e);
    }
  }

  Future<void> removeContact(TrustedContactModel contact) async {
    try {
      await _db.from('trusted_contacts').delete().eq('id', contact.id);
      contacts.removeWhere((c) => c.id == contact.id);
    } catch (e) {
      _snackError('Failed to remove contact', e);
    }
  }

  Future<void> updateContact(TrustedContactModel updated) async {
    if (_uid == null) return;
    try {
      await _db.from('trusted_contacts').update({
        'name': updated.name,
        'phone': updated.phone,
        'category': updated.category,
        'email': updated.email,
        'relation': updated.relation,
        'notes': updated.notes,
        'avatar_url': updated.avatarUrl,
        'profile_id': updated.profileId,
        'is_sharing': updated.isSharing,
      }).eq('id', updated.id).eq('user_id', _uid!);

      final index = contacts.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        contacts[index] = updated;
        contacts.refresh();
      }
    } catch (e) {
      _snackError('Failed to update contact', e);
    }
  }

  Future<void> toggleSharing(TrustedContactModel contact) async {
    if (_uid == null) return;
    final newValue = !contact.isSharing;
    try {
      await _db
          .from('trusted_contacts')
          .update({'is_sharing': newValue})
          .eq('id', contact.id);
      contact.isSharing = newValue;
      contacts.refresh();

      if (newValue) {
        await _db.from('sharing_history').insert({
          'user_id': _uid!,
          'contact_id': contact.id,
          'contact_name': contact.name,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        final openRows = await _db
            .from('sharing_history')
            .select('id, started_at')
            .eq('user_id', _uid!)
            .eq('contact_id', contact.id)
            .filter('ended_at', 'is', 'null')
            .order('started_at', ascending: false)
            .limit(1);

        if ((openRows as List).isNotEmpty) {
          final row = openRows.first as Map<String, dynamic>;
          final started = DateTime.parse(row['started_at'] as String);
          final ended = DateTime.now().toUtc();
          final secs = ended.difference(started).inSeconds;
          await _db.from('sharing_history').update({
            'ended_at': ended.toIso8601String(),
            'duration_secs': secs,
          }).eq('id', row['id'] as String);
        }
      }

      await fetchHistory();

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

  Future<void> fetchHistory() async {
    if (_uid == null) return;
    try {
      isHistoryLoading.value = true;
      final rows = await _db
          .from('sharing_history')
          .select()
          .eq('user_id', _uid!)
          .order('started_at', ascending: false)
          .limit(50);
      history.value =
          (rows as List).map((r) => SharingHistoryEntry.fromMap(r)).toList();
    } catch (e) {
      _snackError('Failed to load history', e);
    } finally {
      isHistoryLoading.value = false;
    }
  }

  List<SharingHistoryEntry> getHistoryForContact(String contactId) {
    return history.where((h) => h.contactId == contactId).toList();
  }

  List<String> get contactNames => contacts.map((c) => c.name).toList();

  List<String> get emergencyContactNames => contacts
      .where((c) => c.category == 'Emergency')
      .map((c) => c.name)
      .toList();

  void _snackError(String title, Object e) {
    Get.snackbar('❌ $title', e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4));
  }
}