import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  static const String id = 'transactionsScreen';

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF3B0D11),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view transactions.'))
          : Column(
              children: [
                // Header Search & Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFFB8B24)),
                      filled: true,
                      fillColor: const Color(0xFFFAF9F6),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Transactions List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('transactions')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB8B24)),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final allDocs = snapshot.data!.docs;
                      final docs = _searchQuery.isEmpty
                          ? allDocs
                          : allDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final type = (data['type'] ?? '').toString().toLowerCase();
                              final note = (data['note'] ?? '').toString().toLowerCase();
                              return type.contains(_searchQuery) || note.contains(_searchQuery);
                            }).toList();

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            'No transactions match "$_searchQuery"',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final amount = data['amount'] ?? 0;
                          final type = data['type'] ?? 'Transaction';
                          final note = data['note'] ?? '';
                          final rawDate = data['date'];

                          String dateStr = 'Pending';
                          if (rawDate != null && rawDate is Timestamp) {
                            final dt = rawDate.toDate();
                            dateStr =
                                '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          }

                          IconData iconData = Icons.receipt_long;
                          Color iconBg = const Color(0xFFFB8B24).withOpacity(0.12);
                          Color iconColor = const Color(0xFFFB8B24);

                          final typeLower = type.toString().toLowerCase();
                          if (typeLower.contains('giving') || typeLower.contains('tithe') || typeLower.contains('offering')) {
                            iconData = Icons.favorite;
                            iconBg = const Color(0xFFE53935).withOpacity(0.12);
                            iconColor = const Color(0xFFE53935);
                          } else if (typeLower.contains('airtime') || typeLower.contains('top-up')) {
                            iconData = Icons.phone_android;
                            iconBg = const Color(0xFF1E88E5).withOpacity(0.12);
                            iconColor = const Color(0xFF1E88E5);
                          } else if (typeLower.contains('wallet')) {
                            iconData = Icons.account_balance_wallet;
                            iconBg = const Color(0xFF43A047).withOpacity(0.12);
                            iconColor = const Color(0xFF43A047);
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          type,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3B0D11),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (note.toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'R ${(amount is num ? amount : double.tryParse(amount.toString()) ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3B0D11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFB8B24).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 40,
                color: Color(0xFFFB8B24),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Transactions Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B0D11),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your giving records, wallet top-ups, and utility purchases will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
