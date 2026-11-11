import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/fs.dart';
import '../../tool/src/manifest.dart';
import '../../tool/src/markers.dart';
import '../../tool/src/options.dart';

void main() {
  test('Given every text file in the repo, When markers are scanned, '
      'Then each has a known name', () {
    final unknown = <String>[];
    for (final path in listFiles(skipDirs)) {
      if (!isTextFile(path)) continue;
      final text = readUtf8OrNull(path);
      if (text == null) continue;
      for (final m in markerNames(text)) {
        if (!knownMarkers.contains(m.name)) {
          unknown.add('$path:${m.line}: ${m.name}');
        }
      }
    }
    expect(unknown, isEmpty);
  });

  test('Given the feature rules, When knownMarkers is read, '
      'Then it holds every feature marker plus BLUEPRINT', () {
    expect(knownMarkers, containsAll(['BLUEPRINT', 'SENTRY', 'ANON']));
    for (final rule in featureRules.values) {
      expect(knownMarkers, containsAll(rule.markers));
    }
  });

  test('Given ads, When its rule is read, Then it strips ADS', () {
    expect(featureRules[Feature.ads]!.markers, contains('ADS'));
  });

  test('Given ads, When its rule is read, Then it removes lib/features/ads, '
      'the guard script and its test, and docs/ads_setup.md', () {
    expect(
      featureRules[Feature.ads]!.paths,
      containsAll([
        'lib/features/ads',
        'scripts/check_ads_config.dart',
        'test/scripts/check_ads_config_test.dart',
        'docs/ads_setup.md',
      ]),
    );
  });

  test('Given remoteConfig, When its rule is read, '
      'Then it strips REMOTE_CONFIG only', () {
    expect(featureRules[Feature.remoteConfig]!.markers, ['REMOTE_CONFIG']);
    expect(featureRules[Feature.remoteConfig]!.paths, isEmpty);
  });

  test('Given an .arb path, When isTextFile, Then true', () {
    expect(isTextFile('lib/l10n/app_en.arb'), isTrue);
  });

  test('Given featureRules, When read, Then ads has arbKeyPrefixes [ads] '
      'and posthog has none', () {
    expect(featureRules[Feature.ads]!.arbKeyPrefixes, ['ads']);
    expect(featureRules[Feature.posthog]!.arbKeyPrefixes, isEmpty);
  });
}
