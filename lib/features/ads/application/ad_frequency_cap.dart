/// Paces full-screen ads: one every [minInterval] at most.
class AdFrequencyCap {
  AdFrequencyCap({
    required Duration Function() minInterval,
    DateTime Function() now = DateTime.now,
  }) : _minInterval = minInterval,
       _now = now;

  final Duration Function() _minInterval;
  final DateTime Function() _now;
  DateTime? _lastClosed;

  /// True when no full-screen ad has closed yet, or the minimum interval
  /// (never below zero) has passed since the last one closed.
  bool canShowFullScreen() {
    final last = _lastClosed;
    if (last == null) return true;
    final interval = _minInterval();
    final floor = interval.isNegative ? Duration.zero : interval;
    return _now().difference(last) >= floor;
  }

  /// True when a full-screen ad closed within the last [d].
  bool closedWithin(Duration d) {
    final last = _lastClosed;
    return last != null && _now().difference(last) < d;
  }

  void recordFullScreenClosed() => _lastClosed = _now();
}
