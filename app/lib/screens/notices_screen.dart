import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/notice_utils.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _markNoticeAsRead(String noticeId) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({
            'read_notices': FieldValue.arrayUnion([noticeId]),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking notice as read: $e');
    }
  }

  Future<void> _markAllAsRead(List<String> noticeIds) async {
    if (_currentUser == null || noticeIds.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({
            'read_notices': FieldValue.arrayUnion(noticeIds),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All notices marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all notices as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text(
          'Notices',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF3B0D11),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          if (_currentUser != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUser.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                final userData =
                    userSnap.data?.data() as Map<String, dynamic>? ?? {};
                final List<dynamic> readNotices =
                    userData['read_notices'] ?? [];
                final userSociety =
                    (userData['society'] ?? userData['society_name'])
                        ?.toString();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notices')
                      .snapshots(),
                  builder: (context, noticeSnap) {
                    if (!noticeSnap.hasData) return const SizedBox.shrink();
                    final visibleDocs = noticeSnap.data!.docs.where(
                      (doc) => isNoticeVisibleToSociety(
                        doc.data() as Map<String, dynamic>,
                        userSociety,
                      ),
                    );
                    final allIds = visibleDocs.map((d) => d.id).toList();
                    final unreadCount = allIds
                        .where((id) => !readNotices.contains(id))
                        .length;

                    if (unreadCount == 0) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _markAllAsRead(allIds),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB8B24),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFB8B24,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _currentUser == null
            ? const Center(child: Text('Please log in to view notices'))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final List<dynamic> rawReadNotices =
                      userData['read_notices'] ?? [];
                  final Set<String> readNoticeIds = rawReadNotices
                      .map((e) => e.toString())
                      .toSet();
                  final userSociety =
                      (userData['society'] ?? userData['society_name'])
                          ?.toString();

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notices')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, noticesSnapshot) {
                      if (noticesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFB8B24),
                          ),
                        );
                      }

                      final notices = (noticesSnapshot.data?.docs ?? [])
                          .where(
                            (doc) => isNoticeVisibleToSociety(
                              doc.data() as Map<String, dynamic>,
                              userSociety,
                            ),
                          )
                          .toList();

                      if (notices.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF3B0D11,
                                  ).withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_off_outlined,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'No notices available',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B0D11),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'We will notify you when there is something new.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: notices.length,
                        itemBuilder: (context, index) {
                          final noticeDoc = notices[index];
                          final notice =
                              noticeDoc.data() as Map<String, dynamic>;
                          final noticeId = noticeDoc.id;
                          final title = notice['title'] ?? 'Notice';
                          final message = notice['message'] ?? '';
                          final date = notice['createdAt'] != null
                              ? (notice['createdAt'] as Timestamp).toDate()
                              : DateTime.now();

                          final isRead = readNoticeIds.contains(noticeId);
                          final tag =
                              (notice['society'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? notice['society'] as String
                              : 'Church-wide';

                          return _buildNoticeCard(
                            noticeId: noticeId,
                            title: title,
                            message: message,
                            date: date,
                            isRead: isRead,
                            tag: tag,
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  static const _monthAbbreviations = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  Widget _buildNoticeCard({
    required String noticeId,
    required String title,
    required String message,
    required DateTime date,
    required bool isRead,
    required String tag,
  }) {
    final time =
        "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white.withValues(alpha: 0.85) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : const Color(0xFFFB8B24),
          width: isRead ? 0.8 : 1.4,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isRead ? null : () => _markNoticeAsRead(noticeId),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Stamp Badge - matches the Events tab's card language
                Container(
                  width: 56,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: isRead
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : const [Color(0xFF3B0D11), Color(0xFF5A151C)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isRead ? Colors.grey : const Color(0xFF3B0D11))
                            .withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFB8B24),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          _monthAbbreviations[date.month - 1],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFB8B24,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFB8B24),
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const Spacer(),
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
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isRead
                              ? Colors.grey[700]
                              : const Color(0xFF3B0D11),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isRead ? Colors.grey[600] : Colors.grey[800],
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isRead
                                ? Colors.grey[400]
                                : const Color(0xFFFB8B24),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                          if (!isRead)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _markNoticeAsRead(noticeId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFB8B24,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFB8B24,
                                      ).withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: Color(0xFFFB8B24),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Mark as read',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFFFB8B24),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 13,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Read',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
