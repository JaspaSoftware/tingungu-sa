import 'package:flutter/material.dart';
import '../components/coming_soon_sheet.dart';

class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});

  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedNetwork = 'MTN';
  final List<String> _networks = ['MTN', 'Vodacom', 'Cell C', 'Telkom'];

  final List<Map<String, String>> _bundles = [
    {'size': '50MB', 'price': '5', 'validity': 'Daily'},
    {'size': '150MB', 'price': '15', 'validity': 'Weekly'},
    {'size': '500MB', 'price': '29', 'validity': 'Monthly'},
    {'size': '1GB', 'price': '49', 'validity': 'Monthly'},
    {'size': '2GB', 'price': '89', 'validity': 'Monthly'},
    {'size': '5GB', 'price': '149', 'validity': 'Monthly'},
    {'size': '20GB', 'price': '299', 'validity': 'Monthly'},
  ];
  int _selectedBundleIndex = 3;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_formKey.currentState!.validate()) {
      final bundle = _bundles[_selectedBundleIndex];
      showComingSoonSheet(
        context,
        icon: Icons.wifi_rounded,
        title: 'Data Bundles Coming Soon',
        message:
            "We're finalizing our data bundle partner integration. "
            "${bundle['size']} for $_selectedNetwork will be available to purchase here shortly.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF3B0D11),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Data Bundles',
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
                  'Phone Number',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFFFB8B24)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFB8B24)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFB8B24), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value == null || value.length < 10 ? 'Enter a valid number' : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Select Network',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedNetwork,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _networks
                        .map((network) => DropdownMenuItem(
                              value: network,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(color: Color(0xFFFB8B24), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(network, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedNetwork = value);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Select Bundle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bundles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, index) {
                    final bundle = _bundles[index];
                    final isSelected = _selectedBundleIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedBundleIndex = index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFB8B24) : Colors.grey.shade200,
                            width: isSelected ? 2 : 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              bundle['size']!,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFFB8B24) : const Color(0xFF3B0D11),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('R${bundle['price']} • ${bundle['validity']}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFB8B24).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _proceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFB8B24),
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
