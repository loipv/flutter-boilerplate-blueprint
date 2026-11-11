import 'dart:io';

enum Severity { error, warning }

typedef Finding = ({Severity severity, String message});

const _googleSamplePrefix = 'ca-app-pub-3940256099942544';

const _unitKeys = {
  'Android': [
    'ADMOB_BANNER_ANDROID',
    'ADMOB_INTERSTITIAL_ANDROID',
    'ADMOB_REWARDED_ANDROID',
    'ADMOB_APP_OPEN_ANDROID',
  ],
  'iOS': [
    'ADMOB_BANNER_IOS',
    'ADMOB_INTERSTITIAL_IOS',
    'ADMOB_REWARDED_IOS',
    'ADMOB_APP_OPEN_IOS',
  ],
};

/// The env file a production build reads: the same first-existing choice as
/// the Makefile (`.env.production`, then `.env`). Null when neither exists.
String? pickEnvFile(bool Function(String path) exists) {
  for (final path in const ['.env.production', '.env']) {
    if (exists(path)) return path;
  }
  return null;
}

/// Parses `KEY=VALUE` lines; `#` comments and blank lines are ignored and an
/// empty value is kept as `''`.
Map<String, String> parseEnv(String text) {
  final env = <String, String>{};
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    env[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return env;
}

/// The `admobAppId` manifest placeholder of the Gradle flavor [flavor], or
/// null when the flavor block or the placeholder is missing.
String? gradleAppId(String gradle, String flavor) {
  final start = gradle.indexOf('create("$flavor")');
  if (start < 0) return null;
  final next = gradle.indexOf('create("', start + 1);
  final block = gradle.substring(start, next < 0 ? gradle.length : next);
  final match = RegExp(
    r'manifestPlaceholders\["admobAppId"\]\s*=\s*"([^"]*)"',
  ).firstMatch(block);
  return match?.group(1);
}

/// The `ADMOB_APP_ID` values of the XCBuildConfiguration blocks whose name
/// ends with `-production`.
List<String> pbxprojProductionAppIds(String pbxproj) {
  final ids = <String>[];
  final blocks = pbxproj.split('isa = XCBuildConfiguration;').skip(1);
  for (final block in blocks) {
    // A block ends at its closing `};` line; ignore what follows it.
    final end = RegExp(r'^\t\t\};', multiLine: true).firstMatch(block);
    final body = end == null ? block : block.substring(0, end.start);
    final name = RegExp(
      r'^\t\t\tname = "?([^";\n]+)"?;',
      multiLine: true,
    ).firstMatch(body)?.group(1);
    if (name == null || !name.endsWith('-production')) continue;
    final id = RegExp(r'ADMOB_APP_ID = "?([^";\n]+)"?;').firstMatch(body);
    if (id != null) ids.add(id.group(1)!);
  }
  return ids;
}

/// Checks the production AdMob configuration. Does nothing unless
/// `ADS_ENABLED` is `true`.
List<Finding> checkAdsConfig({
  required Map<String, String> env,
  required String? androidAppId,
  required List<String> iosAppIds,
}) {
  if (env['ADS_ENABLED'] != 'true') return const [];
  final findings = <Finding>[];
  void error(String m) => findings.add((severity: Severity.error, message: m));
  void warn(String m) => findings.add((severity: Severity.warning, message: m));

  if (androidAppId == null) {
    error('No production Android AdMob App ID found in build.gradle.kts.');
  } else if (androidAppId.startsWith(_googleSamplePrefix)) {
    error(
      "Android production App ID is Google's sample ID ($androidAppId). "
      'Set your own in android/app/build.gradle.kts.',
    );
  }
  final uniqueIosIds = iosAppIds.toSet();
  if (uniqueIosIds.isEmpty) {
    error('No production iOS AdMob App ID found in project.pbxproj.');
  }
  for (final id in uniqueIosIds) {
    if (id.startsWith(_googleSamplePrefix)) {
      error(
        "iOS production App ID is Google's sample ID ($id). "
        'Set ADMOB_APP_ID in the production build configurations of '
        'ios/Runner.xcodeproj/project.pbxproj.',
      );
    }
  }

  for (final entry in _unitKeys.entries) {
    var blank = 0;
    for (final key in entry.value) {
      final value = env[key] ?? '';
      if (value.isEmpty) {
        blank++;
        warn('$key is blank; that ad format is off on ${entry.key}.');
      } else if (value.startsWith(_googleSamplePrefix)) {
        error('$key is a Google test ad unit ID ($value).');
      }
    }
    if (blank == entry.value.length) {
      warn(
        'All ${entry.key} ad unit IDs are blank; consider ADS_ENABLED=false '
        'for this build if you do not ship ads on ${entry.key}. A store app '
        'that never shows ads should be scaffolded with --no-ads.',
      );
    }
  }
  return findings;
}

void main() {
  final envPath = pickEnvFile((p) => File(p).existsSync());
  if (envPath == null) {
    stdout.writeln('No .env.production or .env found; skipping ads check.');
    return;
  }
  final gradleFile = File('android/app/build.gradle.kts');
  final pbxFile = File('ios/Runner.xcodeproj/project.pbxproj');
  if (!gradleFile.existsSync() || !pbxFile.existsSync()) {
    stderr.writeln(
      'Run this from the project root: android/app/build.gradle.kts or '
      'ios/Runner.xcodeproj/project.pbxproj not found.',
    );
    exit(1);
  }
  final env = parseEnv(File(envPath).readAsStringSync());
  if (env['ADS_ENABLED'] != 'true') {
    stdout.writeln('ADS_ENABLED is not true in $envPath; skipping ads check.');
    return;
  }
  stdout.writeln('Checking AdMob config from $envPath');
  final findings = checkAdsConfig(
    env: env,
    androidAppId: gradleAppId(gradleFile.readAsStringSync(), 'production'),
    iosAppIds: pbxprojProductionAppIds(pbxFile.readAsStringSync()),
  );
  for (final f in findings) {
    final label = f.severity == Severity.error ? 'ERROR' : 'WARNING';
    stdout.writeln('$label: ${f.message}');
  }
  if (findings.any((f) => f.severity == Severity.error)) exit(1);
}
