import 'package:dio/dio.dart';

import '../../domain/entities/onboarding_draft.dart';
import '../../domain/entities/onboarding_results.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/remote/onboarding_api.dart';

/// REST-backed implementation of [OnboardingRepository]. Maps the API's JSON
/// maps onto domain entities.
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._api);

  final OnboardingApi _api;

  @override
  Future<ReferralResult> verifyReferral(String code) async =>
      ReferralResult.fromJson(await _api.verifyReferral(code));

  @override
  Future<AuthResult> signup({
    required String email,
    required String password,
    String? referralCode,
    String? confirmPassword,
  }) async => AuthResult.fromJson(
    await _api.signup(
      refNumber: referralCode ?? '',
      email: email,
      password: password,
      confirmPassword: confirmPassword ?? password,
    ),
  );

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      AuthResult.fromJson(await _api.login(email: email, password: password));

  @override
  Future<OnboardingSnapshot> loadOnboarding() async {
    try {
      return OnboardingSnapshot.fromJson(await _api.getOnboarding());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404 || status == 422) {
        return const OnboardingSnapshot(
          profile: UserProfile(),
          draft: OnboardingDraft(),
        );
      }
      rethrow;
    }
  }

  @override
  Future<OnboardingDraft> saveStep(
    Map<String, dynamic> answers, {
    required int stepIndex,
  }) async => OnboardingDraft.fromJson(
    await _api.patchOnboarding(answers, stepIndex: stepIndex),
  );

  @override
  Future<void> logout(String refreshToken) => _api.logout(refreshToken);

  @override
  Future<UserProfile?> loadPatientDetails() async {
    try {
      return UserProfile.fromJson(await _api.getPatientDetails());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 401 || status == 422) return null;
      rethrow;
    }
  }

  @override
  Future<UserProfile> savePatientDetails(Map<String, dynamic> data) async =>
      UserProfile.fromJson(await _api.patchPatientDetails(data));

  @override
  Future<CompletionResult> complete() async =>
      CompletionResult.fromJson(await _api.complete());
}
