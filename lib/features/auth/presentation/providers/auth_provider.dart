import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../home/presentation/providers/discovery_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final User? firebaseUser;
  final UserModel? user;
  final OnboardingStatusResult? onboardingStatus;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.firebaseUser,
    this.user,
    this.onboardingStatus,
    this.errorMessage,
  });

  bool get isUnknown => status == AuthStatus.unknown;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && firebaseUser != null;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get isOnboardingCompleted =>
      onboardingStatus?.onboardingCompleted ??
      user?.onboardingCompleted ??
      false;

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    User? firebaseUser,
    UserModel? user,
    OnboardingStatusResult? onboardingStatus,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      user: user ?? this.user,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;
  bool _isCleaningUp = false;

  @override
  AuthState build() {
    WidgetsBinding.instance.addObserver(this);

    _authSubscription?.cancel();
    _authSubscription = _authService.idTokenChanges.listen(
      _handleAuthUserChanged,
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[AuthNotifier] Auth stream encountered error: $error');
        }
        _performCleanupAndResetState();
      },
    );

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _authSubscription?.cancel();
    });

    return const AuthState(status: AuthStatus.unknown, isLoading: true);
  }

  FirebaseAuthService get _authService => ref.read(firebaseAuthServiceProvider);
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _authService.currentUser != null) {
      _checkSessionFreshness();
    }
  }

  Future<void> _checkSessionFreshness() async {
    try {
      await _authService.reloadUser();
      final currentFbUser = _authService.currentUser;
      if (currentFbUser != null) {
        await _syncBackendProfile(currentFbUser);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthNotifier] Session reload on resume detected invalid session: $e',
        );
      }
      await _performCleanupAndResetState();
    }
  }

  Future<void> _handleAuthUserChanged(User? fbUser) async {
    if (fbUser == null) {
      await _performCleanupAndResetState();
      return;
    }

    // Always fetch latest backend profile on auth change/start so roles and statuses stay fresh
    await _syncBackendProfile(fbUser);
  }

  Future<void> _syncBackendProfile(User fbUser) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final status = await _repository.getOnboardingStatus();
      UserModel? userDetails;
      if (status.isInitialized) {
        userDetails = await _repository.getMe();
      } else {
        userDetails = await _repository.initializeUser();
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
        firebaseUser: fbUser,
        user: userDetails,
        onboardingStatus: status,
        errorMessage: null,
      );
    } on AuthException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] 401 Unauthorized during profile sync: $e');
      }
      await _performCleanupAndResetState();
    } on ForbiddenException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] 403 Forbidden during profile sync: $e');
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
        firebaseUser: fbUser,
        errorMessage: e.message,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] Backend profile sync failed: $e');
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
        firebaseUser: fbUser,
        errorMessage: 'Backend synchronization failed. Please check network.',
      );
    }
  }

  Future<void> _performCleanupAndResetState() async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      // 1. Sign out of Firebase & Google
      try {
        await _authService.signOut();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[AuthNotifier] Sign-out service error (ignored for complete cleanup): $e',
          );
        }
      }

      // 2. Clear legacy storage / SharedPreferences tokens
      try {
        await ref.read(storageServiceProvider).clearAuth();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthNotifier] Storage clear error: $e');
        }
      }

      // 3. Reset user-specific Riverpod providers
      try {
        ref.read(discoveryProvider.notifier).resetDeck();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthNotifier] Provider reset error: $e');
        }
      }

      // 4. Move state to unauthenticated
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: false,
      );
    } finally {
      _isCleaningUp = false;
    }
  }

  Future<String?> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Profile is synced via stream or fallback
      await _syncBackendProfile(cred.user!);
      return state.onboardingStatus?.nextStep ?? 'PET_INFO';
    } on FirebaseAuthException catch (e) {
      String msg = 'Authentication failed. Please check your credentials.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'Invalid email or password.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Network error. Please check your connection.';
      } else if (e.message != null) {
        msg = e.message!;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<String?> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await _authService.signInWithGoogle();
      await _syncBackendProfile(cred.user!);
      return state.onboardingStatus?.nextStep ?? 'PET_INFO';
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('ApiException: 7') || msg.contains('network_error')) {
        msg = 'Google network error (Code 7). Please ensure your phone has an active internet connection (Wi-Fi or Mobile Data) to reach Google services.';
      } else if (msg.contains('ApiException: 10') ||
          msg.contains('developer_error')) {
        msg = 'Google configuration error (Code 10). Please verify SHA-1 fingerprint in Firebase Console.';
      } else if (msg.contains('ApiException: 12500')) {
        msg = 'Google Sign-In failed (Code 12500). Please check Google Play Services on your device.';
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return null;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _repository.initializeUser(phoneNumber: phoneNumber);
      await _syncBackendProfile(cred.user!);
      return true;
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered. Please log in.';
      } else if (e.code == 'weak-password') {
        msg = 'Password is too weak. Please use a stronger password.';
      } else if (e.message != null) {
        msg = e.message!;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: e.message ?? 'Failed to send reset email.',
      );
      return false;
    }
  }

  Future<PetModel?> addPet({
    required String name,
    String? profilePictureUrl,
    String? imageUrl,
    String? imagePublicId,
    required String animalType,
    required String breed,
    required String gender,
    required DateTime dateOfBirth,
    String? color,
    List<String> personality = const [],
    required String vaccinationStatus,
    String? allergies,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final pet = await _repository.createPet(
        name: name,
        profilePictureUrl: profilePictureUrl,
        imageUrl: imageUrl,
        imagePublicId: imagePublicId,
        animalType: animalType,
        breed: breed,
        gender: gender,
        dateOfBirth: dateOfBirth,
        color: color,
        personality: personality,
        vaccinationStatus: vaccinationStatus,
        allergies: allergies,
        description: description,
      );

      final status = await _repository.getOnboardingStatus();
      final updatedUser = await _repository.getMe();

      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
        onboardingStatus: status,
      );

      return pet;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> completeOwnerProfile({
    required String fullName,
    String? profilePictureUrl,
    String? imageUrl,
    String? imagePublicId,
    required String location,
    String? area,
    String? bio,
    String? phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateOwnerProfile(
        fullName: fullName,
        profilePictureUrl: profilePictureUrl,
        imageUrl: imageUrl,
        imagePublicId: imagePublicId,
        location: location,
        area: area,
        bio: bio,
        phoneNumber: phoneNumber,
        onboardingCompleted: true,
      );

      final status = await _repository.getOnboardingStatus();
      final freshUser = await _repository.getMe();

      state = state.copyWith(
        isLoading: false,
        user: freshUser,
        onboardingStatus: status,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Re-fetches the user profile from the backend and updates auth state.
  /// Call this after mutations (e.g. pet activation) so the UI sees fresh data.
  Future<void> refreshUserProfile() async {
    final fbUser = _authService.currentUser;
    if (fbUser == null) return;
    try {
      final userDetails = await _repository.getMe();
      state = state.copyWith(user: userDetails);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] refreshUserProfile failed: $e');
      }
    }
  }

  Future<void> logout() async {
    await _performCleanupAndResetState();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final authNotifierProvider = authStateProvider;

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).firebaseUser?.uid;
});
