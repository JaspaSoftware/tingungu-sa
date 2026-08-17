import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/society_model.dart';
import '../services/society_service.dart';
import '../services/presence_service.dart';
import '../utils/avatar_utils.dart';
import 'society_selection_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Society? userSociety;
  bool _isLoading = true;
  String? userId;
  int _selectedTab = 0; // 0: Chat, 1: Members, 2: Info
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  // Presence's Away state is derived from a timestamp rather than pushed by
  // the backgrounded device (see PresenceService), so nothing tells this
  // screen when a member crosses the away threshold. Rebuild periodically
  // so that transition still becomes visible without a fresh Firestore write.
  Timer? _presenceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUserSociety();
    _presenceRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presenceRefreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSociety() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      userId = user?.uid ?? prefs.getString('user_id');

      if (userId == null) {
        if (kDebugMode) {
          print('User ID not found');
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (user != null) {
        await prefs.setString('user_id', user.uid);
      }

      final society = await SocietyService.getUserSociety(userId!);

      if (society != null) {
        await prefs.setString('user_society', jsonEncode(society.toMap()));
      } else {
        final cachedJson = prefs.getString('user_society');
        if (cachedJson != null) {
          try {
            final cachedData = jsonDecode(cachedJson);
            final cachedSociety = Society.fromJson(cachedData);
            if (mounted) {
              setState(() {
                userSociety = cachedSociety;
                _isLoading = false;
              });
            }
            return;
          } catch (_) {}
        } else {
          await prefs.remove('user_society');
        }
      }

      if (mounted) {
        setState(() {
          userSociety = society;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading society: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSocietySelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SocietySelectionPage(currentSociety: userSociety?.name ?? ''),
      ),
    ).then((_) {
      _loadUserSociety();
    });
  }

  void _leaveSociety() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Society?'),
        content: Text('Are you sure you want to leave ${userSociety?.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLeaveSociety();
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLeaveSociety() async {
    if (userId == null) return;

    final result = await SocietyService.leaveSociety(userId!);

    if (result['success']) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_society');

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'society': FieldValue.delete(),
        'society_name': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          userSociety = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the society'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showMemberProfile({
    required String memberId,
    required String name,
    required String avatarUrl,
    String? email,
    String? role,
    String? cellNumber,
  }) async {
    Map<String, dynamic> userData = {};
    if (memberId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        if (doc.exists) {
          userData = doc.data() ?? {};
        }
      } catch (_) {}
    }

    final displayName =
        userData['displayname'] ??
        userData['display_name'] ??
        (name.isNotEmpty ? name : 'Member');
    final avatar = userData['avatar']?.toString() ?? avatarUrl;
    final userEmail = userData['email']?.toString() ?? email ?? '';
    final userCell = userData['cellnumber']?.toString() ?? cellNumber ?? '';
    final userRole = userData['role']?.toString() ?? role ?? 'Society Member';
    final userSocietyName =
        userData['society'] ??
        userData['society_name'] ??
        userSociety?.name ??
        'Methodist Society';

    if (!mounted) return;

    final avatarProvider = AvatarUtils.getAvatarImageProvider(avatar);
    final isMe = memberId == FirebaseAuth.instance.currentUser?.uid;
    final presenceActive = userData['presence_active'] == true;
    final currentStatus = userData['presence_status']?.toString();
    final currentBackgroundedAt = userData['presence_backgrounded_at'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? selectedStatus = currentStatus;
        bool selectedActive = presenceActive;

        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).padding.bottom > 0 ? 16 : 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => AvatarUtils.showFullAvatarView(
                      context,
                      avatarUrl: avatar,
                      name: displayName,
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(
                        0xFF3B0D11,
                      ).withValues(alpha: 0.15),
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'M',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B0D11),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  const SizedBox(height: 4),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFFB8B24).withValues(alpha: 0.15)
                          : const Color(0xFF3B0D11).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isMe ? 'YOU • $userRole' : userRole,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? const Color(0xFFFB8B24)
                            : const Color(0xFF3B0D11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isMe) ...[
                    const Text(
                      'Set your status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusChip(
                            label: 'Online',
                            color: Colors.green.shade600,
                            isSelected:
                                !selectedActive ||
                                selectedStatus == null ||
                                selectedStatus == 'online',
                            onTap: () {
                              setModalState(() {
                                selectedStatus = 'online';
                                selectedActive = true;
                              });
                              PresenceService.setStatus(PresenceStatus.online);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusChip(
                            label: 'Away',
                            color: const Color(0xFFFB8B24),
                            isSelected:
                                selectedActive && selectedStatus == 'away',
                            onTap: () {
                              setModalState(() {
                                selectedStatus = 'away';
                                selectedActive = true;
                              });
                              PresenceService.setStatus(PresenceStatus.away);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusChip(
                            label: 'Busy',
                            color: Colors.red.shade600,
                            isSelected:
                                selectedActive && selectedStatus == 'busy',
                            onTap: () {
                              setModalState(() {
                                selectedStatus = 'busy';
                                selectedActive = true;
                              });
                              PresenceService.setStatus(PresenceStatus.busy);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(),
                  const SizedBox(height: 8),

                  _buildProfileDetailRow(
                    Icons.church,
                    'Society',
                    userSocietyName,
                  ),
                  if (userSociety?.circuit != null)
                    _buildProfileDetailRow(
                      Icons.location_city,
                      'Circuit',
                      userSociety!.circuit!,
                    ),
                  if (userEmail.isNotEmpty)
                    _buildProfileDetailRow(
                      Icons.email_outlined,
                      'Email',
                      userEmail,
                    ),
                  if (userCell.isNotEmpty)
                    _buildProfileDetailRow(
                      Icons.phone_outlined,
                      'Contact',
                      userCell,
                    ),
                  _buildProfileDetailRow(
                    Icons.circle,
                    'Status',
                    PresenceService.labelFor(
                      active: selectedActive,
                      status: selectedStatus,
                      backgroundedAt: isMe ? null : currentBackgroundedAt,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B0D11),
                            side: const BorderSide(color: Color(0xFF3B0D11)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (!isMe) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedTab = 0;
                              });
                              _messageController.text = '@$displayName ';
                              _messageController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _messageController.text.length,
                                    ),
                                  );
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: Text(
                              'Message @$displayName',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B0D11),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip({
    required VoidCallback onTap,
    required String label,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF3B0D11) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFB8B24)),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B0D11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || userSociety == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final senderName =
          userData['displayname'] ??
          userData['display_name'] ??
          currentUser.displayName ??
          'Member';
      final senderAvatar = userData['avatar'] ?? '';

      _messageController.clear();

      await FirebaseFirestore.instance
          .collection('community_chats')
          .doc(userSociety!.name.trim())
          .collection('messages')
          .add({
            'senderId': currentUser.uid,
            'senderName': senderName,
            'senderAvatar': senderAvatar,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (kDebugMode) print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B0D11)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading community...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (userSociety == null) {
      return _buildNoSocietyView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF3B0D11),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          userSociety!.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: 'Switch Society',
            onPressed: _navigateToSocietySelector,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Community Summary Bar
            _buildCommunityHeader(),

            // Segmented Navigation Tabs
            _buildTabSelector(),

            // Main Tab Content Area
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildGroupChatView(),
                  _buildMembersListView(),
                  _buildSocietyInfoView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          int memberCount = 0;
          if (snapshot.hasData && userSociety != null) {
            final targetName = userSociety!.name.toLowerCase().trim();
            memberCount = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final userSoc =
                  (data['society'] ?? data['society_name'])
                      ?.toString()
                      .toLowerCase()
                      .trim() ??
                  '';
              return userSoc == targetName;
            }).length;
          }

          return Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B0D11).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF3B0D11),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userSociety!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B0D11),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${userSociety!.circuit ?? "Circuit"} • $memberCount ${memberCount == 1 ? "Member" : "Members"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 0.8),
        ),
        child: Row(
          children: [
            _buildTabItem(0, Icons.chat_bubble_outline, 'Group Chat'),
            _buildTabItem(1, Icons.people_outline, 'Members'),
            _buildTabItem(2, Icons.info_outline, 'Info'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B0D11) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupChatView() {
    if (userSociety == null) return const SizedBox.shrink();

    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // Messages Stream
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('community_chats')
                .doc(userSociety!.name.trim())
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B0D11),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading chat messages',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 56,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome to the ${userSociety!.name} group chat! 👋',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B0D11),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first member to send a message.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final senderId = data['senderId'] ?? '';
                  final isMe = senderId == currentUser?.uid;
                  final senderName = data['senderName'] ?? 'Member';
                  final text = data['text'] ?? '';
                  final senderAvatar = data['senderAvatar'] ?? '';
                  final Timestamp? timestamp = data['timestamp'] as Timestamp?;

                  String timeStr = '';
                  if (timestamp != null) {
                    final dt = timestamp.toDate();
                    timeStr =
                        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          GestureDetector(
                            onTap: () {
                              _showMemberProfile(
                                memberId: senderId,
                                name: senderName,
                                avatarUrl: senderAvatar,
                              );
                            },
                            child: _LiveSenderAvatar(
                              senderId: senderId,
                              fallbackAvatar: senderAvatar,
                              senderName: senderName,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                GestureDetector(
                                  onTap: () {
                                    _showMemberProfile(
                                      memberId: senderId,
                                      name: senderName,
                                      avatarUrl: senderAvatar,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF3B0D11)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Bottom Message Input Bar
        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share with ${userSociety!.name}...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFFAF9F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xFFFB8B24),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B0D11),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersListView() {
    if (userSociety == null) return const SizedBox.shrink();

    final targetSociety = userSociety!.name.toLowerCase().trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B0D11)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading community members',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final members = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final userSoc =
              (data['society'] ?? data['society_name'])
                  ?.toString()
                  .toLowerCase()
                  .trim() ??
              '';
          return userSoc == targetSociety;
        }).toList();

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 56,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'No members registered in ${userSociety!.name} yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final doc = members[index];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = doc.id == currentUser?.uid;

            final name =
                data['displayname'] ??
                data['display_name'] ??
                data['email'] ??
                'Member';
            final avatar = data['avatar']?.toString() ?? '';
            final role =
                data['role']?.toString() ?? (isMe ? 'Active Member' : 'Member');
            final presenceActive = data['presence_active'] == true;
            final presenceStatus = data['presence_status']?.toString();
            final presenceBackgroundedAt = data['presence_backgrounded_at'];
            final presenceColor = PresenceService.colorFor(
              active: presenceActive,
              status: presenceStatus,
              backgroundedAt: presenceBackgroundedAt,
            );
            final presenceLabel = PresenceService.labelFor(
              active: presenceActive,
              status: presenceStatus,
              backgroundedAt: presenceBackgroundedAt,
            );

            final avatarProvider = AvatarUtils.getAvatarImageProvider(avatar);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                onTap: () {
                  _showMemberProfile(
                    memberId: doc.id,
                    name: name,
                    avatarUrl: avatar,
                    email: data['email']?.toString(),
                    role: role,
                    cellNumber: data['cellnumber']?.toString(),
                  );
                },
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => AvatarUtils.showFullAvatarView(
                        context,
                        avatarUrl: avatar,
                        name: name,
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(
                          0xFF3B0D11,
                        ).withValues(alpha: 0.12),
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B0D11),
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: presenceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B0D11),
                        ),
                      ),
                    ),
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB8B24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: presenceColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        presenceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        ' · $role',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSocietyInfoView() {
    if (userSociety == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Banner Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B0D11).withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.church,
                      size: 64,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userSociety!.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B0D11),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF3B0D11,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          userSociety!.circuit ?? 'Church Circuit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B0D11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Information Details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B0D11),
                  ),
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  'Circuit',
                  userSociety!.circuit ?? 'Methodist Circuit',
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Location', userSociety!.location ?? 'TBC'),
                const SizedBox(height: 12),
                _buildInfoRow('Society Leader', userSociety!.leader ?? 'TBC'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Leave Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _leaveSociety,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              child: const Text(
                'Leave Community',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNoSocietyView() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B0D11).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    color: Color(0xFF3B0D11),
                    size: 60,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'No Community Yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B0D11),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You haven\'t joined any society yet. Each member can join one society to connect with like-minded believers, chat, and serve together.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToSocietySelector,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B0D11),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Explore Societies',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B0D11),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders a chat message sender's avatar from their live `users/{senderId}`
/// document instead of the `senderAvatar` copy frozen into the message at
/// send-time, so older messages pick up profile picture changes immediately.
class _LiveSenderAvatar extends StatelessWidget {
  final String senderId;
  final String fallbackAvatar;
  final String senderName;

  const _LiveSenderAvatar({
    required this.senderId,
    required this.fallbackAvatar,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    if (senderId.isEmpty) {
      return _avatar(AvatarUtils.getAvatarImageProvider(fallbackAvatar));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .snapshots(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data() as Map<String, dynamic>?;
        final liveAvatar = liveData?['avatar'] as String?;
        final avatarProvider = AvatarUtils.getAvatarImageProvider(
          (liveAvatar != null && liveAvatar.trim().isNotEmpty)
              ? liveAvatar
              : fallbackAvatar,
        );
        return _avatar(avatarProvider);
      },
    );
  }

  Widget _avatar(ImageProvider? avatarProvider) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF3B0D11).withValues(alpha: 0.15),
      backgroundImage: avatarProvider,
      child: avatarProvider == null
          ? Text(
              senderName.isNotEmpty ? senderName[0].toUpperCase() : 'M',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B0D11),
              ),
            )
          : null,
    );
  }
}
