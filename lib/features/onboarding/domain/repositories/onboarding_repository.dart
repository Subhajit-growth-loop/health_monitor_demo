import '../entities/onboarding_draft.dart';
import '../entities/onboarding_results.dart';
import '../entities/user_profile.dart';

/// Contract the onboarding presentation layer depends on. The implementation
/// talks to the REST backend (Dio); callers never see transport details.
abstract interface class OnboardingRepository {
  /// `POST /auth/referral/verify`.
  Future<ReferralResult> verifyReferral(String code);

  Future<AuthResult> signup({
    required String email,
    required String password,
    String? referralCode,
    String? confirmPassword,
  });

  /// `POST /auth/login`.
  Future<AuthResult> login({required String email, required String password});

  /// `POST /auth/logout` — ends the session for [refreshToken] server-side.
  Future<void> logout(String refreshToken);

  /// `GET /onboarding` — saved answer draft + the step reached (mock-served).
  Future<OnboardingSnapshot> loadOnboarding();

  /// `PATCH /onboarding` — persist a step's answers and the current step index
  /// so a returning user resumes here (mock-served).
  Future<OnboardingDraft> saveStep(
    Map<String, dynamic> answers, {
    required int stepIndex,
  });

  /// `GET /patient/me/details` — fetch the patient's saved medical profile to
  /// prefill the verify-info step. Returns null if not yet created (404).
  Future<UserProfile?> loadPatientDetails();

  /// `PATCH /patient/me/details` — save the verified medical profile on step 1.
  /// Returns the record as the server stored it, so nothing is kept locally.
  Future<UserProfile> savePatientDetails(Map<String, dynamic> data);

  /// `POST /onboarding/complete` — finalize and fetch the welcome payload.
  Future<CompletionResult> complete();
}
