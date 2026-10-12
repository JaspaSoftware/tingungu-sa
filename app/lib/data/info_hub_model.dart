// Models for the Circuits & Societies directory shown on the Community tab,
// mirroring the district -> circuit -> society -> minister structure of the
// church's circuit register spreadsheet.

class HubMinister {
  final String id;
  final String surname;
  final String firstName;
  final String? cellphone;
  final String? email;

  HubMinister({
    required this.id,
    required this.surname,
    required this.firstName,
    this.cellphone,
    this.email,
  });

  String get fullName {
    final name = '$firstName $surname'.trim();
    return name.isEmpty ? 'Minister' : name;
  }

  factory HubMinister.fromMap(String id, Map<String, dynamic> map) {
    return HubMinister(
      id: id,
      surname: map['surname']?.toString() ?? '',
      firstName: map['firstName']?.toString() ?? '',
      cellphone: map['cellphone']?.toString(),
      email: map['email']?.toString(),
    );
  }
}

class HubAppointment {
  final HubMinister minister;
  final String categoryName;

  HubAppointment({required this.minister, required this.categoryName});
}

class HubSociety {
  final String id;
  final String name;
  final String circuitId;
  final List<HubAppointment> appointments = [];

  HubSociety({required this.id, required this.name, required this.circuitId});
}

class HubCircuit {
  final String id;
  final String code;
  final String name;
  final String districtId;
  final List<HubSociety> societies = [];

  HubCircuit({
    required this.id,
    required this.code,
    required this.name,
    required this.districtId,
  });

  /// The circuit's lead minister is whoever is appointed to the society
  /// sharing the circuit's own name (its "home" society), falling back to
  /// the first appointment found anywhere in the circuit.
  HubAppointment? get leadAppointment {
    for (final society in societies) {
      if (society.name.toLowerCase() == name.toLowerCase() &&
          society.appointments.isNotEmpty) {
        return society.appointments.first;
      }
    }
    for (final society in societies) {
      if (society.appointments.isNotEmpty) return society.appointments.first;
    }
    return null;
  }

  int get sortKey => int.tryParse(id) ?? 1 << 30;
}

class HubDistrict {
  final String id;
  final String name;
  final List<HubCircuit> circuits = [];

  HubDistrict({required this.id, required this.name});
}
