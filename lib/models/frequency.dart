// Frequency model for managing bill recurrence frequencies

class Frequency {
  final int? id;
  final String name; // e.g., "Weekly", "Monthly", "Bi-weekly"
  final String type; // e.g., "weekly", "monthly", "biweekly"
  final int value; // Number of days/weeks/months (e.g., 7 for weekly, 30 for monthly)
  final String displayName; // User-friendly display name
  final String userId;

  Frequency({
    this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.displayName,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'displayName': displayName,
      'userId': userId,
    };
  }

  factory Frequency.fromMap(Map<String, dynamic> map) {
    return Frequency(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      value: map['value'],
      displayName: map['displayName'] ?? map['name'],
      userId: map['userId'],
    );
  }

  Frequency copyWith({
    int? id,
    String? name,
    String? type,
    int? value,
    String? displayName,
    String? userId,
  }) {
    return Frequency(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      displayName: displayName ?? this.displayName,
      userId: userId ?? this.userId,
    );
  }
}

