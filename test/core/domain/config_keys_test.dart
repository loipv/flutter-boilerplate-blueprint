import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Given ConfigKeys.all, When keys are compared, Then they are unique',
    () {
      final names = ConfigKeys.all.map((k) => k.key).toList();
      expect(names.toSet().length, names.length);
    },
  );

  test('Given ConfigKeys.all, When read, Then it contains apiBaseUrl', () {
    expect(ConfigKeys.all, contains(ConfigKeys.apiBaseUrl));
    expect(ConfigKeys.apiBaseUrl.key, 'api_base_url');
  });
}
