import 'package:blueprint_app/core/domain/config_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Given a key and default, When constructed at runtime, Then both are kept',
    () {
      final n = int.parse('3');
      // Non-const on purpose: covers the constructor at runtime.
      final k = ConfigKey<int>('n', n);
      expect(k.key, 'n');
      expect(k.defaultValue, 3);
    },
  );

  test('Given two runtime keys with equal key and default, When compared, '
      'Then they are equal with equal hashCodes', () {
    final a = ConfigKey<int>('a', int.parse('1'));
    final b = ConfigKey<int>('a', int.parse('1'));

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('Given keys with different names, When compared, Then not equal', () {
    final a = ConfigKey<int>('a', int.parse('1'));
    final b = ConfigKey<int>('b', int.parse('1'));

    expect(a, isNot(b));
  });

  test('Given keys with different T, When compared, Then not equal', () {
    final a = ConfigKey<int>('a', int.parse('1'));
    final b = ConfigKey<double>('a', double.parse('1'));

    expect(a, isNot(b));
  });
}
