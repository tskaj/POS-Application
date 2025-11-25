class User {
  final int id;
  final String username;
  final String email;
  final String password;
  final String picture;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.picture,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      picture: json['picture'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'picture': picture,
      'is_active': isActive,
    };
  }
}

class UserPermissions {
  final int userId;
  final Map<String, bool> permissions;

  UserPermissions({required this.userId, required this.permissions});

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      userId: json['user_id'] ?? 0,
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'permissions': permissions};
  }
}
