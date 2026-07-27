import 'onboarding_draft.dart';
import 'user_profile.dart';

/// Result of `POST /auth/referral/verify`.
class ReferralResult {
  const ReferralResult({required this.valid, this.memberName});
  final bool valid;
  final String? memberName;

  factory ReferralResult.fromJson(Map<String, dynamic> json) => ReferralResult(
    valid: json['valid'] as bool? ?? false,
    memberName: json['memberName'] as String?,
  );
}

/// Result of `POST /auth/signup` and `POST /auth/login`.
class AuthResult {
  const AuthResult({
    required this.userId,
    required this.token,
    this.email,
    this.gender,
  });
  final String userId;
  final String token;
  final String? email;

  /// The member's gender as recorded by the backend (e.g. `female` / `male`).
  /// Drives the female-only onboarding step / dynamic step count.
  final String? gender;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    userId: json['userId'] as String? ?? '',
    token: json['token'] as String? ?? '',
    email: json['email'] as String?,
    gender: json['gender'] as String?,
  );
}

/// Result of `GET /onboarding` — the profile plus the saved answer draft.
class OnboardingSnapshot {
  const OnboardingSnapshot({required this.profile, required this.draft});
  final UserProfile profile;
  final OnboardingDraft draft;

  factory OnboardingSnapshot.fromJson(Map<String, dynamic> json) =>
      OnboardingSnapshot(
        profile: UserProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] as Map? ?? {}),
        ),
        draft: OnboardingDraft.fromJson(
          Map<String, dynamic>.from(json['draft'] as Map? ?? {}),
        ),
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
