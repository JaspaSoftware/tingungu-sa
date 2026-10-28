import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

String? loginErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Please enter a valid email address.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' => 'Invalid email or password.',
      'user-disabled' => 'This user account has been disabled.',
      'network-request-failed' => 'Check your internet connection and try again.',
      'too-many-requests' =>
        'Too many sign-in attempts. Please wait a while and try again.',
      'operation-not-allowed' =>
        'Email sign-in is temporarily unavailable. Please try again later.',
      _ => "We couldn't sign you in. Please try again later.",
    };
  }

  if (error is PlatformException) {
    return switch (error.code) {
      GoogleSignIn.kSignInCanceledError => null,
      GoogleSignIn.kNetworkError =>
        'Check your internet connection and try again.',
      GoogleSignIn.kSignInRequiredError =>
        'Google sign-in could not be completed. Please try again.',
      GoogleSignIn.kSignInFailedError =>
        'Google sign-in could not be completed. Please try again.',
      _ => "We couldn't sign you in. Please try again later.",
    };
  }

  return "We couldn't sign you in. Please try again later.";
}

String passwordResetErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Please enter a valid email address.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'too-many-requests' =>
        'Too many requests. Please wait a while and try again.',
      _ => "We couldn't send the password reset email. Please try again later.",
    };
  }

  return "We couldn't send the password reset email. Please try again later.";
}

String registrationErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Please enter a valid email address.',
    'weak-password' => 'The password provided is too weak.',
    'network-request-failed' =>
      'Check your internet connection and try again.',
    'too-many-requests' =>
      'Too many registration attempts. Please wait a while and try again.',
    _ => 'Registration could not be completed. Please try again.',
  };
}
