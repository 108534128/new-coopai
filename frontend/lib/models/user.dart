class User {
  final int userId;
  final String username;
  final String email;
  final String? fullName;
  final String? createdAt;

  User({
    required this.userId,
    required this.username,
    required this.email,
    this.fullName,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? json['userId'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'] ?? json['fullName'],
      createdAt: json['created_at'] ?? json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'full_name': fullName,
      'created_at': createdAt,
    };
  }

  User copyWith({
    int? userId,
    String? username,
    String? email,
    String? fullName,
    String? createdAt,
  }) {
    return User(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(userId: $userId, username: $username, email: $email, fullName: $fullName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.userId == userId &&
        other.username == username &&
        other.email == email &&
        other.fullName == fullName;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        username.hashCode ^
        email.hashCode ^
        fullName.hashCode;
  }
}