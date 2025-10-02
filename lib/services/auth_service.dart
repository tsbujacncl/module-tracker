import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Web OAuth Client ID from Firebase Console
    clientId: '273321735011-bj356j68f07ish64c7g5qct2l9tqtlb5.apps.googleusercontent.com',
  );

  // Auth state stream
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user != null) {
        print('DEBUG AUTH: User authenticated - UID: ${user.uid}, Email: ${user.email}');
      } else {
        print('DEBUG AUTH: User signed out');
      }
      return user;
    });
  }

  // Current user
  User? get currentUser {
    final user = _auth.currentUser;
    if (user != null) {
      print('DEBUG AUTH: Current user - UID: ${user.uid}, Email: ${user.email}');
    }
    return user;
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      print('DEBUG AUTH: Attempting sign in for email: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('DEBUG AUTH: Sign in successful - UID: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      print('DEBUG AUTH: Sign in failed - ${e.code}: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete account
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate user before deleting account
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in anonymously (for testing)
  Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('DEBUG AUTH: Starting Google Sign-In flow');

      // Trigger the authentication flow with timeout
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('DEBUG AUTH: Google Sign-In timed out');
          return null;
        },
      );

      if (googleUser == null) {
        print('DEBUG AUTH: Google Sign-In cancelled by user');
        return null; // User cancelled the sign-in
      }

      print('DEBUG AUTH: Google Sign-In successful - ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      print('DEBUG AUTH: Firebase sign-in successful - UID: ${userCredential.user?.uid}');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('DEBUG AUTH: Firebase error - ${e.code}: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('DEBUG AUTH: Google Sign-In error - $e');
      throw 'Failed to sign in with Google: ${e.toString()}';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}