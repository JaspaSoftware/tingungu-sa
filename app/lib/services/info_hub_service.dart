import '../config/app_config.dart';
import '../data/info_hub_model.dart';
import 'api_client.dart';

class InfoHubService {
  static final ApiClient _api = ApiClient.shared;

  static List<Map<String, dynamic>> _records(Object? body, String endpoint) {
    if (body is! List) {
      throw FormatException('$endpoint response must be a list.');
    }
    return body.map((row) {
      if (row is! Map) {
        throw FormatException('$endpoint records must be objects.');
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  static Future<List<HubDistrict>> loadDirectory() async {
    final responses = await Future.wait([
      _api.get('districts', baseUrl: AppConfig.apiBaseUrl),
      _api.get('circuits', baseUrl: AppConfig.apiBaseUrl),
      _api.get('societies', baseUrl: AppConfig.apiBaseUrl),
      _api.get('ministers', baseUrl: AppConfig.apiBaseUrl),
    ]);
    final districtRows = _records(responses[0].body, 'Districts');
    final circuitRows = _records(responses[1].body, 'Circuits');
    final societyRows = _records(responses[2].body, 'Societies');
    final appointmentRows = _records(responses[3].body, 'Ministers');

    final districtsById = <String, HubDistrict>{
      for (final row in districtRows)
        row['district_id'].toString(): HubDistrict(
          id: row['district_id'].toString(),
          name: row['district_name']?.toString() ?? 'District',
        ),
    };

    final circuitsById = <String, HubCircuit>{};
    for (final row in circuitRows) {
      final id = row['circuit_id'].toString();
      final circuit = HubCircuit(
        id: id,
        code: row['circuit_code']?.toString() ?? '',
        name: row['circuit_name']?.toString() ?? 'Circuit',
        districtId: row['district_id']?.toString() ?? '',
      );
      circuitsById[id] = circuit;
      districtsById[circuit.districtId]?.circuits.add(circuit);
    }

    final societiesById = <String, HubSociety>{};
    for (final row in societyRows) {
      final id = row['society_id'].toString();
      final circuitId = row['circuit_id']?.toString() ?? '';
      final society = HubSociety(
        id: id,
        name: row['society_name']?.toString() ?? 'Society',
        circuitId: circuitId,
      );
      societiesById[id] = society;
      circuitsById[circuitId]?.societies.add(society);
    }

    final ministersById = <String, HubMinister>{};
    for (final row in appointmentRows) {
      final ministerId = row['person_id'].toString();
      final minister = ministersById.putIfAbsent(
        ministerId,
        () => HubMinister(
          id: ministerId,
          surname: row['surname']?.toString() ?? '',
          firstName: row['first_name']?.toString() ?? '',
          cellphone: row['cellphone']?.toString(),
          email: row['email']?.toString(),
        ),
      );
      final society = societiesById[row['society_id']?.toString()];
      if (society == null) continue;
      society.appointments.add(
        HubAppointment(
          minister: minister,
          categoryName: row['category_name']?.toString() ?? 'Minister',
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
  }
}
