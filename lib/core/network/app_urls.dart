/// Single source of truth for every API base URL and endpoint path.
///
/// Usage:
///   _dio.get(AppUrls.referenceEmail, queryParameters: {'ref_number': code})
///   _dio.post(AppUrls.register, data: {...})
abstract final class AppUrls {
  // ── Base ───────────────────────────────────────────────────────────────────

  static const String baseUrl = 'https://api.dev.neuhealth.3exec.com';

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// GET  /users/reference-email?ref_number=NEU-XXXX
  /// Response: { "email": "user@example.com" }
  /// Error:    { "error": { "code": "not_found", "message": "..." } }
  static const String referenceEmail = '/users/reference-email';

  /// POST /patient/register
  /// Body:     { ref_number, email, password, confirm_password }
  /// Response: { id, name, email, role, created_at, updated_at }
  static const String register = '/patient/register';

  /// POST /auth/login
  /// Body:     { email, password }
  /// Response: { id, token, email, role, gender }
  static const String login = '/auth/login';

  /// POST /auth/logout — ends the session belonging to a refresh token.
  /// Body:     { refresh_token }
  /// Response: { message }          422 on a missing/invalid token.
  static const String logout = '/auth/logout';

  // ── Onboarding ─────────────────────────────────────────────────────────────

  /// Served locally by [MockApiInterceptor], not by the backend — steps 2-10
  /// keep their answers on the device. See mock_api_interceptor.dart.
  ///
  /// GET   /onboarding  → `{ profile: {}, draft: {...}, stepIndex: <int> }`
  /// PATCH /onboarding  ← `{ answers: {...}, step_index: <int> }` → draft
  static const String onboarding = '/onboarding';

  /// POST /onboarding/complete — also mock-served.
  /// Response: { coachName, userName, whatHappensNext: [...] }
  static const String onboardingComplete = '/onboarding/complete';

  // ── Patient medical profile ────────────────────────────────────────────────

  /// The Verify-your-information step reads and writes this one endpoint.
  ///
  /// GET   /patient/me/details
  /// PATCH /patient/me/details   ← fired by "Save & next" on step 1
  ///
  /// Body (PATCH) and response (both) share the same shape:
  ///   { id, patient_id, name, date_of_birth, gender, primary_diagnosis,
  ///     diagnosed_at, other_conditions, current_medications,
  ///     current_supplements, created_at, updated_at }
  static const String patientDetails = '/patient/me/details';

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Build a full URL for display/debug — not needed for Dio (uses baseUrl).
  static String full(String path) => '$baseUrl$path';
}
