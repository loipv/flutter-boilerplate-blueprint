/// The result of showing a rewarded ad.
sealed class RewardedOutcome {
  const RewardedOutcome();
}

/// The user watched the ad and earned a reward.
class RewardEarned extends RewardedOutcome {
  const RewardEarned(this.amount, this.type);

  final int amount;
  final String type;
}

/// The ad was shown but dismissed before the reward was earned.
class RewardDismissed extends RewardedOutcome {
  const RewardDismissed();
}

/// No ad could be shown.
class RewardUnavailable extends RewardedOutcome {
  const RewardUnavailable();
}
