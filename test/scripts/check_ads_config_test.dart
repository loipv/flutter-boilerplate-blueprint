import 'package:flutter_test/flutter_test.dart';

import '../../scripts/check_ads_config.dart';

const _sampleAndroid = 'ca-app-pub-3940256099942544~3347511713';
const _sampleIos = 'ca-app-pub-3940256099942544~1458002511';
const _liveAndroid = 'ca-app-pub-1111111111111111~2222222222';
const _liveIos = 'ca-app-pub-1111111111111111~3333333333';

const _unitKeys = [
  'ADMOB_BANNER_ANDROID',
  'ADMOB_BANNER_IOS',
  'ADMOB_INTERSTITIAL_ANDROID',
  'ADMOB_INTERSTITIAL_IOS',
  'ADMOB_REWARDED_ANDROID',
  'ADMOB_REWARDED_IOS',
  'ADMOB_APP_OPEN_ANDROID',
  'ADMOB_APP_OPEN_IOS',
];

Map<String, String> _liveEnv([Map<String, String> overrides = const {}]) => {
  'ADS_ENABLED': 'true',
  for (final k in _unitKeys) k: 'ca-app-pub-1111111111111111/4444444444',
  ...overrides,
};

List<Finding> _check(
  Map<String, String> env, {
  String? android = _liveAndroid,
  List<String> ios = const [_liveIos],
}) => checkAdsConfig(env: env, androidAppId: android, iosAppIds: ios);

Iterable<Finding> _errors(List<Finding> f) =>
    f.where((x) => x.severity == Severity.error);
Iterable<Finding> _warnings(List<Finding> f) =>
    f.where((x) => x.severity == Severity.warning);

void main() {
  group('checkAdsConfig', () {
    test('Given ADS_ENABLED missing, When checked, Then no findings', () {
      expect(_check({}, android: _sampleAndroid, ios: [_sampleIos]), isEmpty);
    });

    test('Given ADS_ENABLED=false, When checked, Then no findings', () {
      expect(
        _check(
          {'ADS_ENABLED': 'false'},
          android: _sampleAndroid,
          ios: [_sampleIos],
        ),
        isEmpty,
      );
    });

    test(
      'Given a sample Android App ID, When checked, Then an Android error',
      () {
        final f = _errors(_check(_liveEnv(), android: _sampleAndroid)).toList();
        expect(f, hasLength(1));
        expect(f.single.message, contains('Android'));
      },
    );

    test('Given a sample iOS App ID, When checked, Then an iOS error', () {
      final f = _errors(_check(_liveEnv(), ios: [_liveIos, _sampleIos]));
      expect(f, hasLength(1));
      expect(f.single.message, contains('iOS'));
    });

    test('Given a test interstitial unit ID, When checked, Then an error '
        'naming the variable', () {
      final f = _errors(
        _check(
          _liveEnv({
            'ADMOB_INTERSTITIAL_IOS': 'ca-app-pub-3940256099942544/4411468910',
          }),
        ),
      ).toList();
      expect(f, hasLength(1));
      expect(f.single.message, contains('ADMOB_INTERSTITIAL_IOS'));
    });

    test('Given a blank rewarded unit ID, When checked, Then a warning '
        'naming the variable and no error', () {
      final f = _check(_liveEnv({'ADMOB_REWARDED_ANDROID': ''}));
      expect(_errors(f), isEmpty);
      expect(_warnings(f), hasLength(1));
      expect(_warnings(f).single.message, contains('ADMOB_REWARDED_ANDROID'));
    });

    test('Given all four iOS unit IDs blank, When checked, Then one extra '
        'warning suggests ADS_ENABLED=false', () {
      final f = _check(
        _liveEnv({
          'ADMOB_BANNER_IOS': '',
          'ADMOB_INTERSTITIAL_IOS': '',
          'ADMOB_REWARDED_IOS': '',
          'ADMOB_APP_OPEN_IOS': '',
        }),
      );
      expect(_errors(f), isEmpty);
      expect(_warnings(f), hasLength(5));
      expect(
        _warnings(f).where((w) => w.message.contains('ADS_ENABLED=false')),
        hasLength(1),
      );
    });

    test('Given only ADS_ENABLED=true and sample IDs, When checked, Then '
        '2 errors and 10 warnings', () {
      final f = _check(
        {'ADS_ENABLED': 'true'},
        android: _sampleAndroid,
        ios: [_sampleIos],
      );
      expect(_errors(f), hasLength(2));
      expect(_warnings(f), hasLength(10));
    });

    test('Given live IDs everywhere, When checked, Then no findings', () {
      expect(_check(_liveEnv()), isEmpty);
    });

    test('Given the same sample iOS ID in three configs, When checked, Then '
        'one error', () {
      final f = _errors(
        _check(_liveEnv(), ios: [_sampleIos, _sampleIos, _sampleIos]),
      );
      expect(f, hasLength(1));
    });

    test('Given no Android App ID found, When checked, Then an error', () {
      final f = _errors(_check(_liveEnv(), android: null)).toList();
      expect(f, hasLength(1));
      expect(f.single.message, contains('Android'));
    });

    test(
      'Given no iOS production App ID found, When checked, Then an error',
      () {
        final f = _errors(_check(_liveEnv(), ios: const [])).toList();
        expect(f, hasLength(1));
        expect(f.single.message, contains('iOS'));
      },
    );
  });

  group('parseEnv', () {
    test('Given comments, blanks and an empty value, When parsed, Then only '
        'real keys remain and empty stays empty', () {
      final env = parseEnv('# c\n\nA=1\nB=\n  # indented\nC=x=y\r\n');
      expect(env, {'A': '1', 'B': '', 'C': 'x=y'});
    });
  });

  group('gradleAppId', () {
    const gradle = '''
        create("staging") {
            dimension = "env"
            // BEGIN_ADS
            manifestPlaceholders["admobAppId"] = "ca-app-pub-1~1"
            // END_ADS
        }
        create("production") {
            dimension = "env"
            // BEGIN_ADS
            manifestPlaceholders["admobAppId"] = "ca-app-pub-2~2"
            // END_ADS
        }
''';

    test('Given two flavors, When production is read, Then its own ID', () {
      expect(gradleAppId(gradle, 'production'), 'ca-app-pub-2~2');
      expect(gradleAppId(gradle, 'staging'), 'ca-app-pub-1~1');
    });

    test('Given an unknown flavor, When read, Then null', () {
      expect(gradleAppId(gradle, 'qa'), isNull);
    });
  });

  group('pbxprojProductionAppIds', () {
    const pbx = '''
		A /* Debug-staging */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ADMOB_APP_ID = "ca-app-pub-s~1";
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = "Debug-staging";
		};
		B /* Release-production */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ADMOB_APP_ID = "ca-app-pub-p~2";
			};
			name = "Release-production";
		};
		C /* Profile-production */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ADMOB_APP_ID = "ca-app-pub-p~3";
			};
			name = "Profile-production";
		};
''';

    test(
      'Given three configurations, When read, Then only *-production IDs',
      () {
        expect(pbxprojProductionAppIds(pbx), [
          'ca-app-pub-p~2',
          'ca-app-pub-p~3',
        ]);
      },
    );
  });

  group('pickEnvFile', () {
    test('Given both files, When picked, Then .env.production wins', () {
      expect(pickEnvFile((_) => true), '.env.production');
    });

    test('Given only .env, When picked, Then .env', () {
      expect(pickEnvFile((p) => p == '.env'), '.env');
    });

    test('Given neither, When picked, Then null', () {
      expect(pickEnvFile((_) => false), isNull);
    });
  });
}
