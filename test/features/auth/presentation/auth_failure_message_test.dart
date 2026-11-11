import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/features/auth/presentation/auth_failure_message.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final vi = lookupAppLocalizations(const Locale('vi'));

  group('authFailureMessage', () {
    test(
      'Given a canceled auth failure, When the message is built, Then it is null',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('canceled'),
            method: SignInMethod.apple,
            l10n: en,
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
            l10n: en,
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
            l10n: en,
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
            l10n: en,
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
            l10n: en,
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
            l10n: en,
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
            l10n: en,
          ),
          isNull,
        );
      },
    );

    test(
      'Given l10n vi and code apple-unavailable, When mapped, Then the Vietnamese authAppleUnavailable text',
      () {
        expect(
          authFailureMessage(
            const Failure.auth('apple-unavailable'),
            method: SignInMethod.apple,
            l10n: vi,
          ),
          vi.authAppleUnavailable,
        );
        expect(vi.authAppleUnavailable, contains('Apple'));
        expect(vi.authAppleUnavailable, isNot(en.authAppleUnavailable));
      },
    );
  });
}
