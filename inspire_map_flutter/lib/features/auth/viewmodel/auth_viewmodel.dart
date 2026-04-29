import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? user;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel() : super(const AuthState()) {
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final token = ApiService().getAuthToken();
    if (token != null && token.isNotEmpty) {
      final user = await ApiService().fetchCurrentUser();
      if (user != null) {
        state = state.copyWith(isLoggedIn: true, user: user);
      } else {
        await ApiService().clearAuthToken();
      }
    }
  }

  Future<bool> register({
    required String phone,
    required String password,
    String? nickname,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await ApiService().register(
      phone: phone,
      password: password,
      nickname: nickname,
    );

    if (result.containsKey('error')) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result['error'] as String,
      );
      return false;
    }

    state = state.copyWith(
      isLoggedIn: true,
      isLoading: false,
      user: result['user'] as Map<String, dynamic>?,
    );
    return true;
  }

  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await ApiService().login(
      phone: phone,
      password: password,
    );

    if (result.containsKey('error')) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result['error'] as String,
      );
      return false;
    }

    state = state.copyWith(
      isLoggedIn: true,
      isLoading: false,
      user: result['user'] as Map<String, dynamic>?,
    );
    return true;
  }

  Future<void> logout() async {
    await ApiService().clearAuthToken();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel();
});
