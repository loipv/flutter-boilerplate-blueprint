/// `--shared-app-id`: makes the staging flavor use the production
/// bundle/application id. Works on the blueprint's fixed values, before the
/// rename. `dart:` only.
library;

import 'rename.dart';

const gradlePath = 'android/app/build.gradle.kts';
const pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';

/// The platform file does not have the shape init expects.
class AppIdException implements Exception {
  AppIdException(this.message);

  final String message;

  @override
  String toString() => message;
}

final _suffixLine = RegExp(
  r'^[ \t]*applicationIdSuffix = "\.staging"[ \t]*\r?\n',
  multiLine: true,
);

/// Removes the staging `applicationIdSuffix` line from the app Gradle file.
/// Throws [AppIdException] unless exactly one such line exists.
String shareAppIdInGradle(String text) {
  final count = _suffixLine.allMatches(text).length;
  if (count != 1) {
    throw AppIdException(
      'expected one `applicationIdSuffix = ".staging"` line, found $count',
    );
  }
  return text.replaceFirst(_suffixLine, '');
}

const _stagingSetting = 'PRODUCT_BUNDLE_IDENTIFIER = $fixedId.staging;';
const _productionSetting = 'PRODUCT_BUNDLE_IDENTIFIER = $fixedId;';

/// Points every staging build configuration at the production bundle id.
/// Throws [AppIdException] when there is no staging bundle id to change.
String shareAppIdInPbxproj(String text) {
  if (!text.contains(_stagingSetting)) {
    throw AppIdException('no `$_stagingSetting` build setting found');
  }
  return text.replaceAll(_stagingSetting, _productionSetting);
}
