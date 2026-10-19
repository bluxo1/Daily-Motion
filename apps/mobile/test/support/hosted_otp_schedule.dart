/// Per-account pacing for hosted qualification; holds no recipients or codes.
class HostedOtpSchedule {
  final DateTime Function() now;
  final Future<void> Function(Duration) delay;
  final _acceptedAt = <String, DateTime>{};

  HostedOtpSchedule({
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : now = now ?? DateTime.now,
       delay = delay ?? ((duration) => Future<void>.delayed(duration));

  int get accountCount => _acceptedAt.length;

  Future<void> request(String account, Future<void> Function() send) async {
    final previous = _acceptedAt[account];
    if (previous != null) {
      final remaining = previous
          .add(const Duration(seconds: 61))
          .difference(now().toUtc());
      if (remaining > Duration.zero) await delay(remaining);
    }
    await send();
    // Include network/provider latency before starting this account's cooldown.
    _acceptedAt[account] = now().toUtc();
  }
}
