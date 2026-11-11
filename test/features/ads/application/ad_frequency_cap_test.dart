import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/ads/application/ad_frequency_cap.dart';

void main() {
  var now = DateTime(2026);
  var interval = const Duration(seconds: 90);
  late AdFrequencyCap cap;

  setUp(() {
    now = DateTime(2026);
    interval = const Duration(seconds: 90);
    cap = AdFrequencyCap(minInterval: () => interval, now: () => now);
  });

  test('Given nothing closed, When asked, Then full screen is allowed', () {
    expect(cap.canShowFullScreen(), isTrue);
    expect(cap.closedWithin(const Duration(days: 1)), isFalse);
  });

  test('Given a close, When 89s then 90s pass, Then false then true', () {
    cap.recordFullScreenClosed();

    now = now.add(const Duration(seconds: 89));
    expect(cap.canShowFullScreen(), isFalse);

    now = now.add(const Duration(seconds: 1));
    expect(cap.canShowFullScreen(), isTrue);
  });

  test('Given a negative interval, When asked right after a close, Then it '
      'behaves as zero', () {
    interval = const Duration(seconds: -10);
    cap.recordFullScreenClosed();

    expect(cap.canShowFullScreen(), isTrue);
  });

  test('Given a close, When asked closedWithin, Then it compares to the '
      'window', () {
    cap.recordFullScreenClosed();
    now = now.add(const Duration(seconds: 3));

    expect(cap.closedWithin(const Duration(seconds: 5)), isTrue);
    expect(cap.closedWithin(const Duration(seconds: 3)), isFalse);
  });
}
