import 'package:flutter/material.dart';
import '../components/coming_soon_sheet.dart';

class BuyElectricityScreen extends StatefulWidget {
  const BuyElectricityScreen({super.key});

  @override
  State<BuyElectricityScreen> createState() => _BuyElectricityScreenState();
}

class _BuyElectricityScreenState extends State<BuyElectricityScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _meterController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedProvider = 'Eskom';
  final List<String> _providers = ['Eskom', 'Municipal'];

  final List<String> _quickAmounts = ['50', '100', '200', '500'];

  @override
  void dispose() {
    _meterController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_formKey.currentState!.validate()) {
      showComingSoonSheet(
        context,
        icon: Icons.bolt_rounded,
        title: 'Electricity Tokens Coming Soon',
        message:
            "We're finalizing our prepaid electricity partner integration for $_selectedProvider meters. "
            "Token purchases will be available here shortly.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Electricity Tokens',
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
                  'Meter Provider',
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
                    initialValue: _selectedProvider,
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
                    items: _providers
                        .map((provider) => DropdownMenuItem(
                              value: provider,
                              child: Text(provider, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedProvider = value);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Meter Number',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B0D11)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _meterController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter 11-digit meter number',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.speed_rounded, color: Color(0xFF2E7D32)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value == null || value.length < 6 ? 'Enter a valid meter number' : null,
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
                      borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
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
                      selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF3B0D11),
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
                      BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _proceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Buy Token',
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
