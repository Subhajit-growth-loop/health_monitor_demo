import 'dart:convert';

import 'onboarding_draft.dart';
import 'user_profile.dart';

Map<String, dynamic> _decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    switch (payload.length % 4) {
      case 2:
        payload += '==';
      case 3:
        payload += '=';
    }
    return jsonDecode(utf8.decode(base64.decode(payload)))
        as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

class ReferralResult {
  const ReferralResult({required this.valid, this.memberName, this.email});
  final bool valid;
  final String? memberName;
  final String? email;

  factory ReferralResult.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      return const ReferralResult(valid: false);
    }
    final email = json['email'] as String?;
    return ReferralResult(valid: email != null && email.isNotEmpty, email: email);
  }
}

class AuthResult {
  const AuthResult({
    required this.userId,
    this.token = '',
    this.refreshToken = '',
    this.email,
    this.gender,
    this.name,
    this.role,
  });
  final String userId;
  final String token;         // access_token
  final String refreshToken;  // refresh_token
  final String? email;
  final String? gender;
  final String? name;
  final String? role;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final accessToken =
        json['access_token'] as String? ?? json['token'] as String? ?? '';
    final refreshToken = json['refresh_token'] as String? ?? '';
    final jwt = accessToken.isNotEmpty ? _decodeJwt(accessToken) : <String, dynamic>{};

    return AuthResult(
      userId: jwt['sub'] as String? ??
          json['id'] as String? ??
          json['userId'] as String? ??
          '',
      token: accessToken,
      refreshToken: refreshToken,
      email: jwt['email'] as String? ?? json['email'] as String?,
      gender: json['gender'] as String?,
      name: json['name'] as String?,
      role: jwt['role'] as String? ?? json['role'] as String?,
    );
  }
}

/// Result of `GET /onboarding` — the saved answer draft plus the step the user
/// had reached, which is what lets a returning user resume mid-flow.
class OnboardingSnapshot {
  const OnboardingSnapshot({
    required this.profile,
    required this.draft,
    this.stepIndex = 0,
  });

  final UserProfile profile;
  final OnboardingDraft draft;

  /// Index into the user's step list — persisted per email by the mock.
  final int stepIndex;

  factory OnboardingSnapshot.fromJson(Map<String, dynamic> json) =>
      OnboardingSnapshot(
        profile: UserProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] as Map? ?? {}),
        ),
        draft: OnboardingDraft.fromJson(
          Map<String, dynamic>.from(json['draft'] as Map? ?? {}),
        ),
        stepIndex: (json['stepIndex'] as num?)?.toInt() ??
            (json['step_index'] as num?)?.toInt() ??
            0,
      );
}

/// Result of `POST /onboarding/complete`.
class CompletionResult {
  const CompletionResult({
    required this.coachName,
    required this.userName,
    required this.whatHappensNext,
  });
  final String coachName;
  final String userName;
  final List<String> whatHappensNext;

  factory CompletionResult.fromJson(Map<String, dynamic> json) =>
      CompletionResult(
        coachName: json['coachName'] as String? ?? 'Maya',
        userName: json['userName'] as String? ?? '',
        whatHappensNext:
            (json['whatHappensNext'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
