/// Auth models mirroring `app/schemas/auth.py`.
library;

class User {
  const User({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.badgeNumber,
    this.district,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String? ?? 'citizen',
        badgeNumber: json['badge_number'] as String?,
        district: json['district'] as String?,
        createdAt: json['created_at'] as String?,
      );

  final String id;
  final String email;
  final String? fullName;
  final String role; // citizen | inspector | admin
  final String? badgeNumber;
  final String? district;
  final String? createdAt;

  bool get isInspector => role == 'inspector' || role == 'admin';

  String get displayName => fullName?.isNotEmpty == true ? fullName! : email;
}

class AuthToken {
  const AuthToken({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
        accessToken: json['access_token'] as String,
        expiresIn: (json['expires_in'] as num).toInt(),
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final int expiresIn;
  final User user;
}
