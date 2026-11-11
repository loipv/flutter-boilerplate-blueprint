import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

enum SignInMethod { apple, google }

String? authFailureMessage(
  Failure failure, {
  required SignInMethod method,
  required AppLocalizations l10n,
}) {
  return failure.maybeWhen(
    auth: (code) {
      if (code == 'canceled') return null;
      if (code == 'apple-unavailable') {
        return l10n.authAppleUnavailable;
      }
      if (code == 'missing-or-invalid-nonce') {
        return l10n.authAppleNonceError;
      }
      if (code == 'email-already-in-use') {
        return method == SignInMethod.google
            ? l10n.authEmailInUseTryApple
            : l10n.authEmailInUseTryGoogle;
      }
      return null;
    },
    orElse: () => null,
  );
}
