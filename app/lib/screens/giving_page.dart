import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'thank_you_screen.dart';
import '../components/payment_method_selector.dart';

class GivingPage extends StatefulWidget {
  static const String id = "givingScreen";
  const GivingPage({super.key});

  @override
  State<GivingPage> createState() => _GivingPageState();
}

class _GivingPageState extends State<GivingPage> {
  String? selectedGivingType;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final bool _isProcessing = false;

  final user = FirebaseAuth.instance.currentUser;

  void _processGiving() {
    if (selectedGivingType == null || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select type and enter amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentMethodSelector(
        amount: amount,
        title: 'Giving: $selectedGivingType',
        description: noteController.text.isEmpty ? 'General Giving' : noteController.text,
        onPaymentSuccess: (method) async {
          // Record transaction
          final txRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('transactions').doc();
          await txRef.set({
            'amount': amount,
            'type': 'Giving: $selectedGivingType ($method)',
            'date': FieldValue.serverTimestamp(),
            'note': noteController.text,
          });

          // Record global giving record
          final givingRef = FirebaseFirestore.instance.collection('givings').doc();
          await givingRef.set({
            'type': selectedGivingType,
            'amount': amount,
            'giverName': user!.displayName ?? 'Anonymous',
            'giverUID': user!.uid,
            'note': noteController.text,
            'createdAt': FieldValue.serverTimestamp(),
            'method': method,
          });

          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ThankYouScreen(amount: amount)),
          );
        },
        onPaymentFailed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('Give', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF3B0D11),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Giving Type",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('giving_options').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                final options = snapshot.data!.docs;
                if (options.isEmpty) return const Text("No giving options available. Please seed data.");

                return DropdownButtonFormField<String>(
                  initialValue: selectedGivingType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                  items: options.map((doc) {
                    final name = doc.get('name') as String;
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (val) => setState(() => selectedGivingType = val),
                  hint: const Text("Choose what to give for"),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Amount",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "R ",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                hintText: "0.00",
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Note (Optional)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                hintText: "Add a message...",
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processGiving,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFB8B24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Complete Giving", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
