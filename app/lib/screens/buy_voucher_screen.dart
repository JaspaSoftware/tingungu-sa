import 'package:flutter/material.dart';
import '../components/coming_soon_sheet.dart';

class BuyVoucherScreen extends StatefulWidget {
  const BuyVoucherScreen({super.key});

  @override
  State<BuyVoucherScreen> createState() => _BuyVoucherScreenState();
}

class _BuyVoucherScreenState extends State<BuyVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();

  final List<Map<String, dynamic>> _retailers = [
    {'name': 'Woolworths', 'icon': Icons.checkroom_rounded},
    {'name': 'Pick n Pay', 'icon': Icons.local_grocery_store_rounded},
    {'name': 'Checkers', 'icon': Icons.shopping_cart_rounded},
    {'name': 'Spar', 'icon': Icons.store_rounded},
    {'name': 'iTunes', 'icon': Icons.music_note_rounded},
    {'name': 'Google Play', 'icon': Icons.play_circle_fill_rounded},
    {'name': 'Steam', 'icon': Icons.sports_esports_rounded},
    {'name': 'Uber', 'icon': Icons.local_taxi_rounded},
  ];
  int _selectedRetailerIndex = 0;

  final List<String> _quickAmounts = ['50', '100', '200', '500'];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_formKey.currentState!.validate()) {
      final retailer = _retailers[_selectedRetailerIndex]['name'] as String;
      showComingSoonSheet(
        context,
        icon: Icons.card_giftcard_rounded,
        title: 'Vouchers Coming Soon',
        message:
            "We're finalizing our voucher partner integration for $retailer. "
            "Gift and scratch card purchases will be available here shortly.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF6A1B9A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Gift & Store Vouchers',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'Select Retailer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _retailers.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (context, index) {
                    final retailer = _retailers[index];
                    final isSelected = _selectedRetailerIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRetailerIndex = index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey.shade200,
                            width: isSelected ? 2 : 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              retailer['icon'] as IconData,
                              color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey[500],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                retailer['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? const Color(0xFF6A1B9A) : const Color(0xFF3B0D11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Amount (R)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6A1B9A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Amount required' : null,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _quickAmounts.map((amt) {
                    bool isSelected = _amountController.text == amt;
                    return FilterChip(
                      label: Text('R$amt'),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _amountController.text = amt),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF6A1B9A).withValues(alpha: 0.15),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF6A1B9A) : const Color(0xFF3B0D11),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6A1B9A).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _proceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Proceed to Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
