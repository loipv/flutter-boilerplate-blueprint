import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';

String describe(RewardedOutcome outcome) => switch (outcome) {
  RewardEarned(:final amount, :final type) => 'earned $amount $type',
  RewardDismissed() => 'dismissed',
  RewardUnavailable() => 'unavailable',
};

void main() {
  test('Given amount 5 and type coins, When RewardEarned is built, '
      'Then it exposes them', () {
    final outcome = RewardEarned(5, 'coins');

    expect(outcome.amount, 5);
    expect(outcome.type, 'coins');
  });

  test('Given each subclass, When switched over as RewardedOutcome, '
      'Then every case is handled', () {
    final outcomes = <RewardedOutcome>[
      RewardEarned(5, 'coins'),
      RewardDismissed(),
      RewardUnavailable(),
    ];

    expect(outcomes.map(describe).toList(), [
      'earned 5 coins',
      'dismissed',
      'unavailable',
    ]);
  });
}
