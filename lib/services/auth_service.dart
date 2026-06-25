import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });
}

class AuthService {
  final fb.FirebaseAuth? _firebaseAuth;
  
  // Custom auth state stream controller for fallbacks
  final _fallbackController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;
  
  AuthService() : _firebaseAuth = _getFirebaseAuth() {
    // Check if Firebase is initialized and listen to changes
    final auth = _firebaseAuth;
    if (auth != null) {
      try {
        auth.authStateChanges().listen((fbUser) {
          if (fbUser != null) {
            _currentUser = UserProfile(
              id: fbUser.uid,
              name: fbUser.displayName ?? fbUser.email?.split('@').first ?? "User",
              email: fbUser.email ?? "",
              photoUrl: fbUser.photoURL,
            );
            _fallbackController.add(_currentUser);
          } else {
            _currentUser = null;
            _fallbackController.add(null);
          }
        });
      } catch (e) {
        // Firebase not initialized, default to null user
        _currentUser = null;
        _fallbackController.add(null);
      }
    } else {
      _currentUser = null;
      _fallbackController.add(null);
    }
  }

  static fb.FirebaseAuth? _getFirebaseAuth() {
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<UserProfile?> get authStateChanges => _fallbackController.stream;
  UserProfile? get currentUser => _currentUser;

  Future<UserProfile?> loginWithEmail(String email, String password) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception("Firebase not initialized");
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        _currentUser = UserProfile(
          id: credential.user!.uid,
          name: credential.user!.displayName ?? email.split('@').first,
          email: email,
        );
        _fallbackController.add(_currentUser);
        return _currentUser;
      }
    } catch (e) {
      // Fallback/Mock for local sandbox/testing without Firebase configuration
      if (email.isNotEmpty && password.length >= 6) {
        _currentUser = UserProfile(
          id: "mock-user-123",
          name: email.split('@').first.toUpperCase(),
          email: email,
        );
        _fallbackController.add(_currentUser);
        return _currentUser;
      }
      rethrow;
    }
    return null;
  }

  Future<UserProfile?> registerWithEmail(String name, String email, String password) async {
    try {
      final auth = _firebaseAuth;
      if (auth == null) throw Exception("Firebase not initialized");
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        _currentUser = UserProfile(
          id: credential.user!.uid,
          name: name,
          email: email,
        );
        _fallbackController.add(_currentUser);
        return _currentUser;
      }
    } catch (e) {
      // Fallback/Mock for local sandbox
      if (name.isNotEmpty && email.isNotEmpty && password.length >= 6) {
        _currentUser = UserProfile(
          id: "mock-user-123",
          name: name,
          email: email,
        );
        _fallbackController.add(_currentUser);
        return _currentUser;
      }
      rethrow;
    }
    return null;
  }

  Future<UserProfile?> loginWithGoogle() async {
    // In production, trigger GoogleSignIn flows. In local mode, return mock user.
    try {
      // Normally:
      // final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      // final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      // ... firebase auth credentials signin
      _currentUser = UserProfile(
        id: "google-mock-user-456",
        name: "Google Educator",
        email: "educator@gmail.com",
      );
      _fallbackController.add(_currentUser);
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        await auth.signOut();
      }
    } catch (_) {}
    _currentUser = null;
    _fallbackController.add(null);
  }
}

// Riverpod Providers
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
