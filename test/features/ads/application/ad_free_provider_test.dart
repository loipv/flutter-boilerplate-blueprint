import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';

void main() {
  test('Given no override, When read, Then adFree is false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(adFreeProvider), isFalse);
  });
}
