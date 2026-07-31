import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/auth_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/network/network_api_services.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  final bool isLoading;
  final String? errorMessage;
  final AuthResponse? user;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    AuthResponse? user,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      user: clearUser ? null : user ?? this.user,
    );
  }
}

class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => AuthRepository(ref.read(dioProvider));

  Future<AuthResponse?> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final json = await _repo.login(email: email, password: password);
      final response = AuthResponse.fromJson(json);
      state = state.copyWith(isLoading: false, user: response);
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _repo.logout(refreshToken);
    } catch (_) {}
    state = state.copyWith(clearUser: true);
  }
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
