class AuthResponse {
  final String token;
  final String refreshToken;
  final int? expiresIn;
  final String userId;
  final String? email;
  final String? name;
  final String? role;
  final String? gender;

  const AuthResponse({
    required this.token,
    required this.refreshToken,
    this.expiresIn,
    required this.userId,
    this.email,
    this.name,
    this.role,
    this.gender,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      userId: (json['id'] ?? json['user_id'] ?? '').toString(),
      email: json['email'] as String?,
      name: json['name'] as String?,
      role: json['role'] as String?,
      gender: json['gender'] as String?,
    );
  }
}
