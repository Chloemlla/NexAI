class SavedPassword {
  final String id;
  final String password;
  final String category;
  final String note;
  final DateTime createdAt;
  final int strength;

  SavedPassword({
    required this.id,
    required this.password,
    required this.category,
    this.note = '',
    required this.createdAt,
    required this.strength,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'password': password,
      'category': category,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'strength': strength,
    };
  }

  factory SavedPassword.fromJson(Map<String, dynamic> json) {
    return SavedPassword(
      id: json['id'] as String,
      password: json['password'] as String,
      category: json['category'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      strength: json['strength'] as int? ?? 0,
    );
  }
}
