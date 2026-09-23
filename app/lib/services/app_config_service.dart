import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigService {
  static const defaults = <String, bool>{
    'airtimeEnabled': true,
    'dataEnabled': true,
    'electricityEnabled': true,
    'chatEnabled': true,
  };

  static Future<Map<String, bool>> getMobileServiceFlags() async {
    final flags = Map<String, bool>.from(defaults);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('config')
          .get();
      final services = snapshot.data()?['mobileServices'];
      if (services is Map<String, dynamic>) {
        for (final key in flags.keys) {
          if (services[key] is bool) flags[key] = services[key] as bool;
        }
      }
    } catch (_) {
      // Keep defaults when remote configuration is unavailable.
    }
    return flags;
  }
}
