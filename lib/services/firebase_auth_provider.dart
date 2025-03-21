import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_provider_interface.dart';
import 'firestore_service.dart';

class FirebaseAuthProvider implements AuthProviderInterface {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  @override
  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase Auth error: ${e.code} - ${e.message}');
      
      // Provide more user-friendly error messages
      switch (e.code) {
        case 'user-not-found':
          throw 'Tài khoản không tồn tại';
        case 'wrong-password':
          throw 'Mật khẩu không đúng';
        case 'invalid-email':
          throw 'Email không hợp lệ';
        case 'user-disabled':
          throw 'Tài khoản đã bị vô hiệu hóa';
        case 'too-many-requests':
          throw 'Quá nhiều yêu cầu, vui lòng thử lại sau';
        default:
          throw e.message ?? 'Lỗi xác thực không xác định';
      }
    } catch (e) {
      _logger.e('Non-Firebase Auth error: $e');
      throw 'Đã xảy ra lỗi khi đăng nhập';
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword(String email, String password, {String? name}) async {
    try {
      // Create user in Firebase Authentication
      UserCredential result = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Save additional user data to Firestore
      if (result.user != null) {
        UserModel userModel = UserModel(
          uid: result.user!.uid,
          email: email,
          name: name,
          createdAt: DateTime.now(),
          isEmailVerified: false,
        );
        
        await _firestoreService.saveUserData(userModel);
      }
      
      // Send email verification
      await result.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase Auth error during signup: ${e.code} - ${e.message}');
      
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Email already exists';
        case 'invalid-email':
          throw 'Email không hợp lệ';
        case 'weak-password':
          throw 'Mật khẩu quá yếu';
        case 'operation-not-allowed':
          throw 'Đăng ký bằng email và mật khẩu không được bật';
        default:
          throw e.message ?? 'Lỗi đăng ký không xác định';
      }
    } catch (e) {
      _logger.e('Error signing up: $e');
      throw 'Đã xảy ra lỗi khi đăng ký';
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      _logger.e('Error signing out: $e');
      throw 'Lỗi khi đăng xuất';
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _logger.e('Error sending password reset: ${e.code} - ${e.message}');
      
      switch (e.code) {
        case 'user-not-found':
          throw 'Không tìm thấy người dùng với email này';
        case 'invalid-email':
          throw 'Email không hợp lệ';
        default:
          throw e.message ?? 'Lỗi đặt lại mật khẩu không xác định';
      }
    } catch (e) {
      _logger.e('Error sending password reset: $e');
      throw 'Lỗi gửi email đặt lại mật khẩu';
    }
  }

  @override
  bool isEmailVerified() {
    User? user = _firebaseAuth.currentUser;
    return user?.emailVerified ?? false;
  }

  @override
  Future<void> reloadUser() async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.reload();
        
        // Update email verification status in Firestore if needed
        if (user.emailVerified) {
          await _firestoreService.updateEmailVerificationStatus(user.uid, true);
        }
      }
    } catch (e) {
      _logger.e('Error reloading user: $e');
      throw 'Lỗi cập nhật thông tin người dùng';
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    // Firebase doesn't have this implementation yet
    _logger.w('Google sign-in not fully implemented for Firebase');
    throw 'Đăng nhập với Google chưa được hỗ trợ đầy đủ';
  }

  @override
  Future<void> resendVerificationEmail() async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        _logger.i('Verification email resent to ${user.email}');
      } else {
        _logger.w('Attempted to resend verification email but no user is logged in');
        throw 'Người dùng chưa đăng nhập, không thể gửi lại email xác minh';
      }
    } catch (e) {
      _logger.e('Error resending verification email: $e');
      throw 'Lỗi gửi lại email xác minh';
    }
  }
  
  bool isInitialized() {
    try {
      // Just access the instance to verify it exists
      FirebaseAuth.instance;
      return true;
    } catch (e) {
      return false;
    }
  }
}
