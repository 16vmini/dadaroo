import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:dadaroo/models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register a parent (Dad/Mum) with full credentials.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String phoneNumber = '',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;
    await user.updateDisplayName(name);

    final profile = UserProfile(
      uid: user.uid,
      name: name,
      email: email,
      role: role,
      phoneNumber: phoneNumber,
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  /// Sign in a family member anonymously with just a name.
  /// They get a device-based token so they stay logged in.
  Future<UserProfile> signUpAnonymous({required String name}) async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user!;
    await user.updateDisplayName(name);

    final profile = UserProfile(
      uid: user.uid,
      name: name,
      email: '',
      role: UserRole.familyMember,
      isAnonymous: true,
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final doc =
        await _firestore.collection('users').doc(credential.user!.uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found');
    }
    return UserProfile.fromMap(doc.data()!);
  }

  Future<UserProfile> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();
    final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Check if user profile already exists
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }

    // Create new profile for first-time Google sign-in
    final profile = UserProfile(
      uid: user.uid,
      name: user.displayName ?? 'User',
      email: user.email ?? '',
      role: UserRole.dad,
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<UserProfile> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final user = userCredential.user!;

    // Check if user profile already exists
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }

    // Apple only provides name on first sign-in
    final name = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].where((n) => n != null).join(' ');

    final profile = UserProfile(
      uid: user.uid,
      name: name.isNotEmpty ? name : user.displayName ?? 'User',
      email: appleCredential.email ?? user.email ?? '',
      role: UserRole.dad,
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Stream<UserProfile?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!);
    });
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .update(profile.toMap());
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
