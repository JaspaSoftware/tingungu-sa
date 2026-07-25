class Event {
  final String id;
  final String month;
  final String dateStart;
  final String? dateEnd;
  final String description;
  final String? venue;

  Event({
    required this.id,
    required this.month,
    required this.dateStart,
    this.dateEnd,
    required this.description,
    this.venue,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      month: json['month'] ?? '',
      dateStart: json['date_start'] ?? '',
      dateEnd: json['date_end'],
      description: json['description'] ?? '',
      venue: json['venue'],
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
    );
  }
}
