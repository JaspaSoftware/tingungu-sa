import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notices')
                      .snapshots(),
                  builder: (context, noticeSnap) {
                    if (!noticeSnap.hasData) return const SizedBox.shrink();
                    final allDocs = noticeSnap.data!.docs;
                    final allIds = allDocs.map((d) => d.id).toList();
                    final unreadCount = allIds
                        .where((id) => !readNotices.contains(id))
                        .length;

                    if (unreadCount == 0) return const SizedBox.shrink();

                    return TextButton.icon(
                      onPressed: () => _markAllAsRead(allIds),
                      icon: const Icon(
                        Icons.done_all,
                        color: Color(0xFFFB8B24),
                        size: 20,
                      ),
                      label: const Text(
                        'Mark all read',
                        style: TextStyle(
                          color: Color(0xFFFB8B24),
                          fontSize: 12,
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

                      if (!noticesSnapshot.hasData ||
                          noticesSnapshot.data!.docs.isEmpty) {
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

                      final notices = noticesSnapshot.data!.docs;

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

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isRead
                                  ? BorderSide.none
                                  : const BorderSide(
                                      color: Color(0xFFFB8B24),
                                      width: 1.5,
                                    ),
                            ),
                            elevation: isRead ? 0 : 2,
                            color: isRead
                                ? Colors.white.withValues(alpha: 0.85)
                                : Colors.white,
                            child: InkWell(
                              onTap: isRead
                                  ? null
                                  : () => _markNoticeAsRead(noticeId),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? Colors.grey.withValues(alpha: 0.1)
                                            : const Color(
                                                0xFFFB8B24,
                                              ).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.campaign,
                                        color: isRead
                                            ? Colors.grey
                                            : const Color(0xFFFB8B24),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isRead
                                                        ? Colors.grey[700]
                                                        : const Color(
                                                            0xFF3B0D11,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFB8B24,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'NEW',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            message,
                                            style: TextStyle(
                                              color: isRead
                                                  ? Colors.grey[600]
                                                  : Colors.grey[800],
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              if (!isRead)
                                                InkWell(
                                                  onTap: () =>
                                                      _markNoticeAsRead(
                                                        noticeId,
                                                      ),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 4,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .check_circle_outline,
                                                          size: 16,
                                                          color: Color(
                                                            0xFFFB8B24,
                                                          ),
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Mark as read',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Color(
                                                              0xFFFB8B24,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              else
                                                const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Read',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
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
}
