class User {
  final String uid;
  final String account;
  final String? name;
  final String? createdAt;

  User({
    required this.uid,
    required this.account,
    this.name,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] ?? json['userId'] ?? '',
      account: json['account'],
      name: json['name'],
      createdAt: json['created_at'] ?? json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'account': account,
      'name': name,
      'created_at': createdAt,
    };
  }

  User copyWith({
    String? uid,
    String? account,
    String? name,
    String? createdAt,
  }) {
    return User(
      uid: uid ?? this.uid,
      account: account ?? this.account,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(uid: $uid, account: $account, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.uid == uid &&
        other.account == account &&
        other.name == name;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        account.hashCode ^
        name.hashCode;
  }
}