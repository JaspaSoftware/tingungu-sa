import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/purchase_airtime_service.dart';
import '../components/payment_method_selector.dart';

class BuyAirtimeScreen extends StatefulWidget {
  const BuyAirtimeScreen({super.key});

  static const String id = "buyAirTineScreen";
  @override
  State<BuyAirtimeScreen> createState() => _BuyAirtimeScreenState();
}

class _BuyAirtimeScreenState extends State<BuyAirtimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedNetwork = 'MTN';
  final List<String> _networks = ['MTN', 'Vodacom', 'Cell C', 'Telkom'];

  final Map<String, int> _networkProductCodes = {
    'MTN': 101,
    'Vodacom': 102,
    'Cell C': 103,
    'Telkom': 104,
  };

  final List<String> _quickAmounts = ['10', '20', '50', '100'];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final detected = _detectNetwork(_phoneController.text);
    if (detected != null && detected != _selectedNetwork) {
      setState(() {
        _selectedNetwork = detected;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _detectNetwork(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('27')) {
      digits = '0${digits.substring(2)}';
    }
    if (digits.length < 3) return null;

    String prefix3 = digits.substring(0, 3);
    String prefix4 = digits.length >= 4 ? digits.substring(0, 4) : prefix3;

    // MTN prefixes
    final mtnPrefixes = {
      '083', '073', '078', '0603', '0604', '0605',
      '0630', '0631', '0632', '0633', '0634', '0635',
      '0710', '0717', '0718', '0719', '0810'
    };
    if (mtnPrefixes.contains(prefix3) || mtnPrefixes.contains(prefix4)) {
      return 'MTN';
    }

    // Vodacom prefixes
    final vodacomPrefixes = {
      '082', '072', '076', '079', '0606', '0607', '0608', '0609',
      '0636', '0637', '0711', '0712', '0713', '0714', '0715', '0716',
      '0811', '0812', '0813', '0814', '0815'
    };
    if (vodacomPrefixes.contains(prefix3) || vodacomPrefixes.contains(prefix4)) {
      return 'Vodacom';
    }

    // Cell C prefixes
    final cellCPrefixes = {
      '084', '074', '061', '062', '0638', '0639', '0640', '0817', '0818'
    };
    if (cellCPrefixes.contains(prefix3) || cellCPrefixes.contains(prefix4)) {
      return 'Cell C';
    }

    // Telkom Mobile prefixes
    final telkomPrefixes = {'0816', '065', '067', '0819'};
    if (telkomPrefixes.contains(prefix3) || telkomPrefixes.contains(prefix4)) {
      return 'Telkom';
    }

    // Fallback checks
    if (prefix3 == '083' || prefix3 == '073' || prefix3 == '078') return 'MTN';
    if (prefix3 == '082' || prefix3 == '072' || prefix3 == '076' || prefix3 == '079') return 'Vodacom';
    if (prefix3 == '084' || prefix3 == '074') return 'Cell C';
    if (prefix3 == '081' || prefix3 == '065' || prefix3 == '067') return 'Telkom';

    return null;
  }

  Future<void> _pickContact() async {
    bool permissionGranted = false;
    try {
      permissionGranted = await FlutterContacts.requestPermission(readonly: true);
      if (!permissionGranted) {
        permissionGranted = await FlutterContacts.requestPermission(readonly: false);
      }
    } catch (e) {
      if (kDebugMode) print('Permission error: $e');
    }

    if (!permissionGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Contacts permission was not granted. Please allow contact access in App Settings.',
          ),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _pickContact,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      final Contact? contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        Contact? fullContact = contact;
        if (fullContact.phones.isEmpty) {
          fullContact = await FlutterContacts.getContact(contact.id);
        }

        if (fullContact != null && fullContact.phones.isNotEmpty) {
          if (fullContact.phones.length == 1) {
            _applySelectedPhone(fullContact.phones.first.number);
          } else {
            _showPhoneNumberSelectionDialog(fullContact);
          }
        } else if (fullContact != null && fullContact.phones.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected contact has no phone numbers.')),
            );
          }
        }
      }
      // User selected a contact (handled above) or exited/cancelled the native picker.
      // Fully exit without opening the fallback custom modal.
      return;
    } catch (e) {
      if (kDebugMode) print('Native pick failed, opening custom modal: $e');
      _pickContactFromCustomModal();
    }
  }

  Future<void> _pickContactFromCustomModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SpinKitCircle(color: Color(0xFFFB8B24), size: 50),
      ),
    );

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final contactsWithPhones = contacts.where((c) => c.phones.isNotEmpty).toList();

      if (contactsWithPhones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts with phone numbers found on device.')),
        );
        return;
      }

      _showContactSelectionModal(contactsWithPhones);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applySelectedPhone(String rawPhone) {
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('+27')) {
      cleanPhone = '0${cleanPhone.substring(3)}';
    } else if (cleanPhone.startsWith('27') && cleanPhone.length > 9) {
      cleanPhone = '0${cleanPhone.substring(2)}';
    }

    setState(() {
      _phoneController.text = cleanPhone;
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
    });

    final detected = _detectNetwork(cleanPhone);
    if (detected != null) {
      setState(() {
        _selectedNetwork = detected;
      });
    }
  }

  void _showPhoneNumberSelectionDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Number for ${contact.displayName}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: contact.phones.map((p) {
            return ListTile(
              leading: const Icon(Icons.phone_rounded, color: Color(0xFFFB8B24)),
              title: Text(p.number),
              subtitle: Text(p.label.name.toUpperCase()),
              onTap: () {
                Navigator.pop(context);
                _applySelectedPhone(p.number);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showContactSelectionModal(List<Contact> contacts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return _ContactPickerModal(
          contacts: contacts,
          onContactSelected: (phone) {
            _applySelectedPhone(phone);
          },
          onContactPicked: (contact) {
            _showPhoneNumberSelectionDialog(contact);
          },
        );
      },
    );
  }

  Future<void> processPayment(
    String amount,
    String network,
    String phone,
  ) async {
    final itemName = Uri.encodeComponent('Airtime Top-up');
    final itemDescription = Uri.encodeComponent('$network Airtime for $phone');
    final base = 'https://payment.payfast.io/eng/process';
    final query =
        'cmd=_paynow&receiver=14362369'
        '&item_name=$itemName'
        '&email_confirmation=1'
        '&confirmation_address=conferencendlovu@gmail.com'
        '&item_description=$itemDescription'
        '&return_url=https://www.tingungu.co.za/success'
        '&cancel_url=https://www.tingungu.co.za/cancel'
        '&notify_url=https://www.tingungu.co.za/notify'
        '&amount=${Uri.encodeComponent(amount)}';

    final uri = Uri.parse('$base?$query');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SpinKitCircle(color: Colors.deepPurple, size: 50),
            SizedBox(height: 16),
            Text("Processing Payment..."),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    Navigator.of(context).pop();

    try {
      Navigator.of(context).pop();
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'launchUrl returned false';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  void _showPaymentMethodSheet() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentMethodSelector(
        amount: amount,
        title: 'Airtime Top-up',
        description: '$_selectedNetwork Airtime for ${_phoneController.text}',
        onPaymentSuccess: (method) {
          Navigator.pop(context);
          _processAirtimePurchase(method);
        },
        onPaymentFailed: () => Navigator.pop(context),
      ),
    );
  }

  void _processAirtimePurchase(String method) async {
    final airtimeService = PurchaseAirtimeService();
    final productCode = _networkProductCodes[_selectedNetwork] ?? 101;
    final amount = int.tryParse(_amountController.text) ?? 0;
    final mobileNumber = _phoneController.text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Processing Airtime via $method...'),
          ],
        ),
      ),
    );

    try {
      final result = await airtimeService.purchaseAirtime(
        productCode: productCode,
        amount: amount,
        mobileNumber: mobileNumber,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Airtime added successfully via $method!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ ${result['message'] ?? 'Purchase failed'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✗ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _processWalletPayment() async {
    final airtimeService = PurchaseAirtimeService();
    final productCode = _networkProductCodes[_selectedNetwork] ?? 101;
    final amount = int.tryParse(_amountController.text) ?? 0;
    final mobileNumber = _phoneController.text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF3B0D11).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Color(0xFF3B0D11),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Processing Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'R${_amountController.text} from your wallet',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF3B0D11).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await airtimeService.purchaseAirtime(
        productCode: productCode,
        amount: amount,
        mobileNumber: mobileNumber,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${result['responseMessage'] ?? 'Payment successful! Airtime will be added shortly.'}',
            ),
            backgroundColor: const Color(0xFF3B0D11),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ ${result['message'] ?? 'Payment failed'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _processBankCardPayment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to PayFast...'),
        backgroundColor: Color(0xFFFB8B24),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showVoucherInputSheet() {
    final TextEditingController voucherController = TextEditingController();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: const Color(0xFFFAF9F6),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Redeem Voucher',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  Text(
                    'Enter your voucher code to proceed',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Voucher Code',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: voucherController,
                    decoration: InputDecoration(
                      hintText: 'Enter voucher code',
                      hintStyle: TextStyle(color: Colors.grey[400]),
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
                        borderSide: const BorderSide(
                          color: Color(0xFFFB8B24),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (voucherController.text.isNotEmpty) {
                          Navigator.pop(context);
                          _processVoucherPayment(voucherController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFB8B24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Redeem Voucher',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processVoucherPayment(String voucherCode) async {
    final airtimeService = PurchaseAirtimeService();
    final productCode = _networkProductCodes[_selectedNetwork] ?? 101;
    final amount = int.tryParse(_amountController.text) ?? 0;
    final mobileNumber = _phoneController.text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFB8B24).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.local_offer,
                color: Color(0xFFFB8B24),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Validating Voucher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              voucherCode,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFFB8B24).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await airtimeService.purchaseAirtime(
        productCode: productCode,
        amount: amount,
        mobileNumber: mobileNumber,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${result['responseMessage'] ?? 'Voucher redeemed! Airtime added to your account.'}',
            ),
            backgroundColor: const Color(0xFFFB8B24),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✗ ${result['message'] ?? 'Voucher redemption failed'}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFFFB8B24),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Buy Airtime',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF3B0D11),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter or select phone number',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFFFB8B24)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contacts_rounded, color: Color(0xFFFB8B24)),
                    tooltip: 'Select from contacts',
                    onPressed: _pickContact,
                  ),
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
                    borderSide: const BorderSide(
                      color: Color(0xFFFB8B24),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => value == null || value.length < 10
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Network',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF3B0D11),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: _networks
                      .map(
                        (network) => DropdownMenuItem(
                          value: network,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFB8B24),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                network,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedNetwork = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Amount (R)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF3B0D11),
                ),
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
                    borderSide: const BorderSide(color: Color(0xFFFB8B24)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFB8B24),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Amount required' : null,
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
                    onSelected: (_) {
                      setState(() {
                        _amountController.text = amt;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(
                      0xFFFB8B24,
                    ).withValues(alpha: 0.2),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFFB8B24)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFFFB8B24)
                          : const Color(0xFF3B0D11),
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
                    BoxShadow(
                      color: const Color(0xFFFB8B24).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _showPaymentMethodSheet();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB8B24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Proceed to Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
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

  Widget _buildPaymentMethodCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ContactPickerModal extends StatefulWidget {
  final List<Contact> contacts;
  final Function(String phone) onContactSelected;
  final Function(Contact contact) onContactPicked;

  const _ContactPickerModal({
    required this.contacts,
    required this.onContactSelected,
    required this.onContactPicked,
  });

  @override
  State<_ContactPickerModal> createState() => _ContactPickerModalState();
}

class _ContactPickerModalState extends State<_ContactPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = widget.contacts.where((c) {
      final nameMatches = c.displayName.toLowerCase().contains(_query.toLowerCase());
      final phoneMatches = c.phones.any((p) => p.number.contains(_query));
      return nameMatches || phoneMatches;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.contacts_rounded, color: Color(0xFFFB8B24)),
              const SizedBox(width: 10),
              const Text(
                'Select Contact',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B0D11),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _query = val),
            decoration: InputDecoration(
              hintText: 'Search contacts by name or number...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFB8B24)),
              filled: true,
              fillColor: const Color(0xFFFAF9F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFB8B24), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredContacts.isEmpty
                ? Center(
                    child: Text(
                      'No matching contacts found.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredContacts.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final firstPhone = contact.phones.first.number;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFB8B24).withValues(alpha: 0.15),
                          child: Text(
                            contact.displayName.isNotEmpty
                                ? contact.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFFFB8B24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B0D11),
                          ),
                        ),
                        subtitle: Text(
                          contact.phones.map((p) => p.number).join(', '),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          if (contact.phones.length == 1) {
                            widget.onContactSelected(firstPhone);
                          } else {
                            widget.onContactPicked(contact);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
