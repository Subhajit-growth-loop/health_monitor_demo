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

  /// `GET /onboarding` — profile + saved answer draft (resume / back-nav).
  Future<OnboardingSnapshot> loadOnboarding();

  /// `PATCH /profile` — inline edits on the Verify-your-information step.
  Future<UserProfile> updateProfile(Map<String, dynamic> changes);

  /// `PATCH /onboarding` — persist a step's answers.
  Future<OnboardingDraft> saveStep(Map<String, dynamic> answers);

  /// `GET /patient/me/details` — fetch the patient's saved medical profile to
  /// prefill the verify-info step. Returns null if not yet created (404).
  Future<UserProfile?> loadPatientDetails();

  /// `POST /patient/profile` — save the verified medical profile on step 1.
  Future<void> savePatientProfile(Map<String, dynamic> data);

  /// `POST /onboarding/complete` — finalize and fetch the welcome payload.
  Future<CompletionResult> complete();
}
