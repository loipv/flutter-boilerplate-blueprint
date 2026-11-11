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
}
