import 'package:__APP_PACKAGE__/core/errors/failure.dart';

enum SignInMethod { apple, google }

String? authFailureMessage(Failure failure, {required SignInMethod method}) {
  return failure.maybeWhen(
    auth: (code) {
      if (code == 'canceled') return null;
      if (code == 'apple-unavailable') {
        return "Sign in with Apple isn't available on this device. Try Google instead, or continue as a guest.";
      }
      if (code == 'missing-or-invalid-nonce') {
        return 'Apple sign-in ran into a problem. Try again, or use Google instead.';
      }
      if (code == 'email-already-in-use') {
        return method == SignInMethod.google
            ? 'An account with this email already exists. Try Apple instead.'
            : 'An account with this email already exists. Try Google instead.';
      }
      return null;
    },
    orElse: () => null,
  );
}
