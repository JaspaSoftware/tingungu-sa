import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EMarketScreen extends StatefulWidget {
  const EMarketScreen({super.key});

  @override
  State<EMarketScreen> createState() => _EMarketScreenState();
}

class _EMarketScreenState extends State<EMarketScreen> {
  static const _defaultXpressiveCultureUrl = 'https://wa.me/c/27839467882';
  static const _defaultFempreneursUrl =
      'https://fempreneurs.co.za/user/xpressive-culture-the-gifting-alchemist/?profiletab=vendor';

  late Future<Map<String, String>> _marketLinks;

  @override
  void initState() {
    super.initState();
    _marketLinks = _loadMarketLinks();
  }

  Future<Map<String, String>> _loadMarketLinks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('config')
          .get();
      final services = snapshot.data()?['mobileServices'];
      if (services is Map<String, dynamic>) {
        return {
          'xpressiveCultureUrl':
              (services['xpressiveCultureUrl'] as String?)?.trim().isNotEmpty ==
                  true
              ? services['xpressiveCultureUrl'] as String
              : _defaultXpressiveCultureUrl,
          'fempreneursUrl':
              (services['fempreneursUrl'] as String?)?.trim().isNotEmpty == true
              ? services['fempreneursUrl'] as String
              : _defaultFempreneursUrl,
        };
      }
    } catch (_) {
      // Keep the built-in links available when remote configuration is unavailable.
    }
    return {
      'xpressiveCultureUrl': _defaultXpressiveCultureUrl,
      'fempreneursUrl': _defaultFempreneursUrl,
    };
  }

  Future<void> _openLink(
    BuildContext context,
    String url,
    String errorMessage,
  ) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
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
          'E-Market',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _marketLinks,
        builder: (context, snapshot) {
          final links = snapshot.data ?? const <String, String>{};
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildLinkTile(
                    context: context,
                    icon: Icons.storefront_rounded,
                    title: 'Xpressive Culture',
                    subtitle: 'View catalog on WhatsApp',
                    onTap: () => _openLink(
                      context,
                      links['xpressiveCultureUrl'] ??
                          _defaultXpressiveCultureUrl,
                      'Could not open WhatsApp catalog.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLinkTile(
                    context: context,
                    icon: Icons.storefront_rounded,
                    title: 'Fempreneurs',
                    subtitle: 'View vendor profile',
                    onTap: () => _openLink(
                      context,
                      links['fempreneursUrl'] ?? _defaultFempreneursUrl,
                      'Could not open Fempreneurs profile.',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinkTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFB8B24).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFFB8B24), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
