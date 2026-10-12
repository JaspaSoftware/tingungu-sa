import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/info_hub_model.dart';

/// Loads the Districts -> Circuits -> Societies -> Ministers directory from
/// Firestore (seeded by api/seed.js) for the Circuits & Societies info hub.
class InfoHubService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<List<HubDistrict>> loadDirectory() async {
    try {
      final results = await Future.wait([
        _db.collection('districts').get(),
        _db.collection('circuits').get(),
        _db.collection('societies').get(),
        _db.collection('ministers').get(),
        _db.collection('categories').get(),
        _db.collection('appointments').get(),
      ]);

      final ministersById = {
        for (final doc in results[3].docs)
          doc.id: HubMinister.fromMap(doc.id, doc.data()),
      };
      final categoryNamesById = {
        for (final doc in results[4].docs)
          doc.id: (doc.data()['name']?.toString() ?? ''),
      };

      final districtsById = <String, HubDistrict>{
        for (final doc in results[0].docs)
          doc.id: HubDistrict(
            id: doc.id,
            name: doc.data()['name']?.toString() ?? 'District',
          ),
      };

      final circuitsById = <String, HubCircuit>{};
      for (final doc in results[1].docs) {
        final data = doc.data();
        final circuit = HubCircuit(
          id: doc.id,
          code: data['code']?.toString() ?? '',
          name: data['name']?.toString() ?? 'Circuit',
          districtId: data['districtId']?.toString() ?? '',
        );
        circuitsById[doc.id] = circuit;
        districtsById[circuit.districtId]?.circuits.add(circuit);
      }

      final societiesById = <String, HubSociety>{};
      for (final doc in results[2].docs) {
        final data = doc.data();
        final circuitId = data['circuitId']?.toString() ?? '';
        final society = HubSociety(
          id: doc.id,
          name: data['name']?.toString() ?? 'Society',
          circuitId: circuitId,
        );
        societiesById[doc.id] = society;
        circuitsById[circuitId]?.societies.add(society);
      }

      for (final doc in results[5].docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final minister = ministersById[data['ministerId']?.toString()];
        final society = societiesById[data['societyId']?.toString()];
        if (minister == null || society == null) continue;
        final categoryName = categoryNamesById[data['categoryId']?.toString()];
        society.appointments.add(
          HubAppointment(
            minister: minister,
            categoryName: (categoryName == null || categoryName.isEmpty)
                ? 'Minister'
                : categoryName,
          ),
        );
      }

      final districts = districtsById.values.toList();
      for (final district in districts) {
        district.circuits.sort((a, b) => a.sortKey.compareTo(b.sortKey));
        for (final circuit in district.circuits) {
          circuit.societies.sort(
            (a, b) => (int.tryParse(a.id) ?? 1 << 30).compareTo(
              int.tryParse(b.id) ?? 1 << 30,
            ),
          );
        }
      }
      districts.sort((a, b) => a.name.compareTo(b.name));

      return districts;
    } catch (e) {
      if (kDebugMode) print('Error loading info hub directory: $e');
      return [];
    }
  }
}
