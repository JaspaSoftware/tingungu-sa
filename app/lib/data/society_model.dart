class Society {
  final String id;
  final String name;
  final String? circuit;
  final String? location;
  final String? leader;

  Society({
    required this.id,
    required this.name,
    this.circuit,
    this.location,
    this.leader,
  });

  factory Society.fromJson(Map<String, dynamic> json) {
    return Society(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      circuit: json['circuit'],
      location: json['location'],
      leader: json['leader'],
    );
  }

  /// Row from the API's /societies endpoint (MySQL is the source of truth).
  factory Society.fromApi(Map<String, dynamic> row) {
    return Society(
      id: row['society_id']?.toString() ?? '',
      name: (row['society_name'] ?? 'Unknown').toString(),
      circuit: row['circuit_name']?.toString(),
    );
  }

  factory Society.fromMap(Map<String, dynamic> map, String id) {
    return Society(
      id: id,
      name: map['name'] ?? 'Unknown',
      circuit: map['circuit'],
      location: map['location'],
      leader: map['leader'],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'circuit': circuit,
    'location': location,
    'leader': leader,
  };
}