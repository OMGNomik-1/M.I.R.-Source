class User {
  final String username;
  final String status;
  final DateTime lastSeen;

  User({
    required this.username,
    required this.status,
    required this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      status: json['status'] ?? '',
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : DateTime.now(),
    );
  }
}