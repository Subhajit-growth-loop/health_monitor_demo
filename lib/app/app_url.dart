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

  /// POST /auth/login — exchanges email + password for a **token pair**.
  /// Body:     { email, password }
  /// Response: { access_token, refresh_token, token_type, expires_in }
  ///
  /// The `refresh_token` is what keeps the session alive; without it every
  /// session dies when the access token expires (see [AuthInterceptor]).
  static const String login = '/auth/login';

  /// POST /auth/refresh — exchanges a refresh token for a **new pair**. The old
  /// refresh token is rotated out, so the response must be persisted whole.
  /// Body:     { refresh_token }
  /// Response: { access_token, refresh_token, token_type, expires_in }
  static const String refresh = '/auth/refresh';

  /// POST /auth/logout — ends the session belonging to a refresh token.
  /// Body:     { refresh_token }
  /// Response: { message }          422 on a missing/invalid token.
  static const String logout = '/auth/logout';

  /// POST /auth/logout-all — ends every session for the current user.
  static const String logoutAll = '/auth/logout-all';

  /// GET /auth/me — the user behind the access token.
  static const String me = '/auth/me';

  /// GET /auth/sessions — live refresh tokens for the current user.
  static const String sessions = '/auth/sessions';

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

  // ── AI onboarding chat (real API) ──────────────────────────────────────────

  /// POST /onboarding-chat/start — analyses the structured answers and returns
  /// `session_id` plus the opening question.
  /// Body:     { patient_id, onboarding: {...} }
  /// Response: ChatResponse — see [onboardingChatTurn].
  static const String onboardingChatStart = '/onboarding-chat/start';

  /// POST /onboarding-chat/turn — submits the patient's answer.
  /// Body:     { session_id, answer }   (answer: 1-4000 chars)
  /// Response: { session_id, done, acknowledgment, question, summary }
  ///           `done: false` → render acknowledgment + question.
  ///           `done: true`  → conversation over, summary populated.
  /// 404 when the session is unknown or already finished (server holds the
  /// state in memory in v1, so a server restart invalidates it).
  static const String onboardingChatTurn = '/onboarding-chat/turn';

  /// POST /onboarding-chat/skip — finalizes early and still returns a summary.
  /// Not wired up yet.
  static const String onboardingChatSkip = '/onboarding-chat/skip';

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
