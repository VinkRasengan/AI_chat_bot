abstract class AuthProviderInterface {
  dynamic get currentUser;
  
  Stream<dynamic> authStateChanges();
  
  Future<bool> isLoggedIn();
  
  Future<void> signInWithEmailAndPassword(String email, String password);
  
  // Update to support additional user data
  Future<void> signUpWithEmailAndPassword(String email, String password, {String? name});
  
  Future<void> signOut();
  
  Future<void> sendPasswordResetEmail(String email);
  
  bool isEmailVerified();
  
  Future<void> reloadUser();
  
  Future<void> signInWithGoogle();
  
  Future<void> resendVerificationEmail();
}