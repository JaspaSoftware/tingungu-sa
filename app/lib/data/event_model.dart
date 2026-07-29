class Event {
  final String id;
  final String month;
  final String dateStart;
  final String? dateEnd;
  final String description;
  final String? venue;
  final String? district;
  final String? society;

  Event({
    required this.id,
    required this.month,
    required this.dateStart,
    this.dateEnd,
    required this.description,
    this.venue,
    this.district,
    this.society,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      month: json['month'] ?? '',
      dateStart: json['date_start'] ?? '',
      dateEnd: json['date_end'],
      description: json['description'] ?? '',
      venue: json['venue'],
      district: json['district'],
      society: json['society'],
    );
  }

  factory Event.fromMap(Map<String, dynamic> map, String id) {
    return Event(
      id: id,
      month: map['month'] ?? '',
      dateStart: map['date_start'] ?? '',
      dateEnd: map['date_end'],
      description: map['description'] ?? '',
      venue: map['venue'],
      district: map['district'],
      society: map['society'],
    );
  }
}
