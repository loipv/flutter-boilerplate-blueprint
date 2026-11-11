import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/features/auth/presentation/auth_failure_message.dart';

void main() {
  group('authFailureMessage', () {
    test(
      'Given a canceled auth failure, When the message is built, Then it is null',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('canceled'),
            method: SignInMethod.apple,
          ),
          isNull,
        );
      },
    );

    test(
      'Given an apple-unavailable failure, When the message is built, Then it explains Apple is unavailable',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('apple-unavailable'),
            method: SignInMethod.apple,
          ),
          "Sign in with Apple isn't available on this device. Try Google instead, or continue as a guest.",
        );
      },
    );

    test(
      'Given a missing-or-invalid-nonce failure, When the message is built, Then it reports the Apple problem',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('missing-or-invalid-nonce'),
            method: SignInMethod.apple,
          ),
          'Apple sign-in ran into a problem. Try again, or use Google instead.',
        );
      },
    );

    test(
      'Given email-already-in-use during Google sign-in, When the message is built, Then it suggests Apple',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('email-already-in-use'),
            method: SignInMethod.google,
          ),
          'An account with this email already exists. Try Apple instead.',
        );
      },
    );

    test(
      'Given email-already-in-use during Apple sign-in, When the message is built, Then it suggests Google',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('email-already-in-use'),
            method: SignInMethod.apple,
          ),
          'An account with this email already exists. Try Google instead.',
        );
      },
    );

    test(
      'Given an unknown auth code, When the message is built, Then it is null',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('network-request-failed'),
            method: SignInMethod.google,
          ),
          isNull,
        );
      },
    );

    test(
      'Given a server failure, When the message is built, Then it is null',
      () {
        expect(
          authFailureMessage(
            const Failure.server(),
            method: SignInMethod.google,
          ),
          isNull,
        );
      },
    );
  });
}
