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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDateFilter = 'All';
  bool _showUnreadOnly = false;

  static const _dateFilters = ['All', 'Today', 'This Week', 'This Month'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesDateFilter(DateTime date) {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'Today':
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case 'This Week':
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return !date.isBefore(startOfWeek) &&
            date.isBefore(startOfWeek.add(const Duration(days: 7)));
      case 'This Month':
        return date.year == now.year && date.month == now.month;
      default:
        return true;
    }
  }

  bool _matchesSearch(String title, String message, String tag) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        message.toLowerCase().contains(query) ||
        tag.toLowerCase().contains(query);
  }

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

  void _openNoticeDetail({
    required String noticeId,
    required String title,
    required String message,
    required DateTime date,
    required bool isRead,
    required String tag,
  }) {
    if (!isRead) _markNoticeAsRead(noticeId);

    final time =
        "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              // mainAxisSize.min lets the sheet size itself to the content -
              // short notices stay small and float above the list; the
              // maxHeight above kicks in and the message scrolls internally
              // once a notice is long enough to need the full screen.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B0D11), Color(0xFF5A151C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _monthAbbreviations[date.month - 1],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFB8B24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B0D11),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB8B24).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_offer_outlined,
                                  size: 12,
                                  color: Color(0xFFFB8B24),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B0D11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B0D11),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            : Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterRibbon(),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_currentUser.uid)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        final userData =
                            userSnapshot.data?.data()
                                as Map<String, dynamic>? ??
                            {};
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
                                .where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  if (!isNoticeVisibleToSociety(
                                    data,
                                    userSociety,
                                  )) {
                                    return false;
                                  }
                                  if (_showUnreadOnly &&
                                      readNoticeIds.contains(doc.id)) {
                                    return false;
                                  }
                                  final title = (data['title'] ?? 'Notice')
                                      .toString();
                                  final message = (data['message'] ?? '')
                                      .toString();
                                  final tag =
                                      (data['society'] as String?)
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? data['society'] as String
                                      : 'Church-wide';
                                  final date = data['createdAt'] != null
                                      ? (data['createdAt'] as Timestamp)
                                            .toDate()
                                      : DateTime.now();
                                  return _matchesDateFilter(date) &&
                                      _matchesSearch(title, message, tag);
                                })
                                .toList();

                            if (notices.isEmpty) {
                              final isFiltering =
                                  _searchQuery.trim().isNotEmpty ||
                                  _selectedDateFilter != 'All' ||
                                  _showUnreadOnly;
                              return Center(
                                child: SingleChildScrollView(
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
                                        child: Icon(
                                          isFiltering
                                              ? Icons.search_off_rounded
                                              : Icons
                                                    .notifications_off_outlined,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        isFiltering
                                            ? 'No matching notices'
                                            : 'No notices available',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3B0D11),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isFiltering
                                            ? 'Try a different search term or filter.'
                                            : 'We will notify you when there is something new.',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                    ? (notice['createdAt'] as Timestamp)
                                          .toDate()
                                    : DateTime.now();

                                final isRead = readNoticeIds.contains(
                                  noticeId,
                                );
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
                ],
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search notices by title, message, or tag...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFFB8B24),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel,
                    color: Colors.grey,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFFAF9F6),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFB8B24), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRibbon() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ..._dateFilters.map((filter) {
              final isSelected = filter == _selectedDateFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDateFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B0D11)
                          : const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B0D11)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF3B0D11,
                                ).withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () => setState(() => _showUnreadOnly = !_showUnreadOnly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _showUnreadOnly
                      ? const Color(0xFFFB8B24)
                      : const Color(0xFFFAF9F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _showUnreadOnly
                        ? const Color(0xFFFB8B24)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 14,
                      color: _showUnreadOnly ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Unread only',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _showUnreadOnly
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _showUnreadOnly
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          onTap: () => _openNoticeDetail(
            noticeId: noticeId,
            title: title,
            message: message,
            date: date,
            isRead: isRead,
            tag: tag,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              // Same eye-candy language as the Events Calendar card, but
              // top-aligned and un-clamped so the card grows with the text
              // instead of Events' fixed-height, always-2-lines layout.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Stamp Badge - matches the Events tab's card language
                Container(
                  width: 62,
                  height: 66,
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                            fontSize: 10,
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

                // Details Column - unbounded height, grows with the content
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

                      // Title - no maxLines/ellipsis: wraps in full so the
                      // card's height flexes to fit however long it is.
                      Text(
                        title,
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

                      // Message - same flexible treatment as the title.
                      Text(
                        message,
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
                const SizedBox(width: 10),

                // Trailing tap indicator - matches the Events card's chevron
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Color(0xFF3B0D11),
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
