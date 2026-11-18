import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

class AuthState {
  final bool isLoading;
  final User? firebaseUser;
  final UserModel? user;
  final OnboardingStatusResult? onboardingStatus;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.firebaseUser,
    this.user,
    this.onboardingStatus,
    this.errorMessage,
  });

  bool get isAuthenticated => firebaseUser != null;
  bool get isOnboardingCompleted =>
      onboardingStatus?.onboardingCompleted ?? user?.onboardingCompleted ?? false;

  AuthState copyWith({
    bool? isLoading,
    User? firebaseUser,
    UserModel? user,
    OnboardingStatusResult? onboardingStatus,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      user: user ?? this.user,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => checkAuthAndOnboarding());
    return const AuthState(isLoading: true);
  }

  FirebaseAuthService get _authService => ref.read(firebaseAuthServiceProvider);
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> checkAuthAndOnboarding() async {
    final currentFbUser = _authService.currentUser;
    if (currentFbUser == null) {
      state = const AuthState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, firebaseUser: currentFbUser, errorMessage: null);

    try {
      final status = await _repository.getOnboardingStatus();
      UserModel? userDetails;
      if (status.isInitialized) {
        userDetails = await _repository.getMe();
      }

      state = state.copyWith(
        isLoading: false,
        firebaseUser: currentFbUser,
        user: userDetails,
        onboardingStatus: status,
      );
    } catch (e) {
      // In development or if backend user isn't initialized yet
      state = state.copyWith(
        isLoading: false,
        firebaseUser: currentFbUser,
      );
    }
  }

  Future<String?> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final status = await _repository.getOnboardingStatus();
      UserModel? userDetails;
      if (status.isInitialized) {
        userDetails = await _repository.getMe();
      } else {
        userDetails = await _repository.initializeUser();
      }

      state = state.copyWith(
        isLoading: false,
        firebaseUser: cred.user,
        user: userDetails,
        onboardingStatus: status,
      );

      return status.nextStep;
    } on FirebaseAuthException catch (e) {
      String msg = 'Authentication failed. Please check your credentials.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
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
      debugPrint('[AuthNotifier] 🔑 Launching Google Sign-In flow...');
      final cred = await _authService.signInWithGoogle();
      debugPrint('[AuthNotifier] ✅ Firebase Google Auth succeeded: UID=${cred.user?.uid}, email=${cred.user?.email}');

      debugPrint('[AuthNotifier] 🌐 Initializing user in PostgreSQL via Express backend...');
      final user = await _repository.initializeUser();
      debugPrint('[AuthNotifier] ✅ PostgreSQL user initialized: id=${user.id}');

      debugPrint('[AuthNotifier] 🌐 Fetching onboarding status...');
      final status = await _repository.getOnboardingStatus();
      debugPrint('[AuthNotifier] 🏁 Onboarding status: nextStep=${status.nextStep}, completed=${status.onboardingCompleted}');

      state = state.copyWith(
        isLoading: false,
        firebaseUser: cred.user,
        user: user,
        onboardingStatus: status,
      );

      return status.nextStep;
    } catch (e, stack) {
      debugPrint('[AuthNotifier] ❌ Google login failed: $e\n$stack');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
      // 1. Create account with Firebase Authentication
      final cred = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Initialize PostgreSQL user record with Firebase UID and phone number
      final user = await _repository.initializeUser(phoneNumber: phoneNumber);
      final status = await _repository.getOnboardingStatus();

      state = state.copyWith(
        isLoading: false,
        firebaseUser: cred.user,
        user: user,
        onboardingStatus: status,
      );

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
      state = state.copyWith(errorMessage: e.message ?? 'Failed to send reset email.');
      return false;
    }
  }

  Future<PetModel?> addPet({
    required String name,
    String? profilePictureUrl,
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
    required String location,
    String? area,
    String? bio,
    String? phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updatedUser = await _repository.updateOwnerProfile(
        fullName: fullName,
        profilePictureUrl: profilePictureUrl,
        location: location,
        area: area,
        bio: bio,
        phoneNumber: phoneNumber,
        onboardingCompleted: true,
      );

      final status = await _repository.getOnboardingStatus();

      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
        onboardingStatus: status,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = const AuthState();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
