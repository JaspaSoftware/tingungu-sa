import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tingungu_app/utils/auth_error_messages.dart';

void main() {
  group('loginErrorMessage', () {
    test('maps invalid email and credential errors safely', () {
      expect(
        loginErrorMessage(FirebaseAuthException(code: 'invalid-email')),
        'Please enter a valid email address.',
      );

      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
      ]) {
        expect(
          loginErrorMessage(FirebaseAuthException(code: code)),
          'Invalid email or password.',
          reason: code,
        );
      }
    });

    test('maps known Firebase service errors', () {
      expect(
        loginErrorMessage(FirebaseAuthException(code: 'user-disabled')),
        'This user account has been disabled.',
      );
      expect(
        loginErrorMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'Check your internet connection and try again.',
      );
      expect(
        loginErrorMessage(FirebaseAuthException(code: 'too-many-requests')),
        'Too many sign-in attempts. Please wait a while and try again.',
      );
      expect(
        loginErrorMessage(FirebaseAuthException(code: 'operation-not-allowed')),
        'Email sign-in is temporarily unavailable. Please try again later.',
      );
    });

    test('maps Google cancellation and recognized failures', () {
      expect(
        loginErrorMessage(
          PlatformException(code: GoogleSignIn.kSignInCanceledError),
        ),
        isNull,
      );
      expect(
        loginErrorMessage(PlatformException(code: GoogleSignIn.kNetworkError)),
        'Check your internet connection and try again.',
      );
      for (final code in [
        GoogleSignIn.kSignInRequiredError,
        GoogleSignIn.kSignInFailedError,
      ]) {
        expect(
          loginErrorMessage(PlatformException(code: code)),
          'Google sign-in could not be completed. Please try again.',
          reason: code,
        );
      }
    });

    test(
      'unknown exceptions return a generic message, not provider details',
      () {
        const privateDetails = 'private provider response and token';
        final message = loginErrorMessage(StateError(privateDetails));

        expect(message, "We couldn't sign you in. Please try again later.");
        expect(message, isNot(contains(privateDetails)));
      },
    );

    test('unknown Firebase codes do not disclose the error message', () {
      final message = loginErrorMessage(
        FirebaseAuthException(
          code: 'new-auth-error',
          message: 'account-specific provider detail',
        ),
      );

      expect(message, "We couldn't sign you in. Please try again later.");
      expect(message, isNot(contains('account-specific provider detail')));
    });
  });

  group('passwordResetErrorMessage', () {
    test('maps network and rate limit failures', () {
      expect(
        passwordResetErrorMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'Check your internet connection and try again.',
      );
      expect(
        passwordResetErrorMessage(
          FirebaseAuthException(code: 'too-many-requests'),
        ),
        'Too many requests. Please wait a while and try again.',
      );
    });

    test('uses a safe fallback for unknown failures', () {
      const privateDetails = 'private provider response';
      final message = passwordResetErrorMessage(StateError(privateDetails));

      expect(
        message,
        "We couldn't send the password reset email. Please try again later.",
      );
      expect(message, isNot(contains(privateDetails)));
    });

    test('does not disclose whether the reset email has an account', () {
      expect(
        passwordResetErrorMessage(
          FirebaseAuthException(
            code: 'user-not-found',
            message: 'No user exists for this address',
          ),
        ),
        "We couldn't send the password reset email. Please try again later.",
      );
    });
  });
}
