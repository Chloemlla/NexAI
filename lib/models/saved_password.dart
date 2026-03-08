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
      id: json['id']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      strength: json['strength'] is int
          ? json['strength'] as int
          : int.tryParse(json['strength']?.toString() ?? '0') ?? 0,
    );
  }
}
