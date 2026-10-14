class ClockSample {
  final DateTime wall;
  final int? elapsedUs;
  final String? continuityId;
  const ClockSample(this.wall, {this.elapsedUs, this.continuityId});
}

abstract interface class RestClock {
  Future<ClockSample> sample();
}

class WallRestClock implements RestClock {
  final DateTime Function() now;
  WallRestClock(this.now);
  @override
  Future<ClockSample> sample() async => ClockSample(now().toUtc());
}

/// A countdown estimate only. Never stored as measured historical rest.
class RestAnchor {
  final DateTime wall;
  final DateTime deadline;
  final int? elapsedUs;
  final String? continuityId;
  final bool uncertain;
  const RestAnchor(
    this.wall,
    this.deadline, {
    this.elapsedUs,
    this.continuityId,
    this.uncertain = false,
  });

  RestDisplay project(ClockSample sample) {
    final duration = deadline
        .difference(wall)
        .inMicroseconds
        .clamp(0, 86400000000);
    final wallDelta = sample.wall
        .toUtc()
        .difference(wall.toUtc())
        .inMicroseconds;
    final reliable =
        elapsedUs != null &&
        sample.elapsedUs != null &&
        continuityId != null &&
        continuityId == sample.continuityId &&
        sample.elapsedUs! >= elapsedUs!;
    final elapsed = reliable ? sample.elapsedUs! - elapsedUs! : wallDelta;
    final remaining = (duration - elapsed).clamp(0, duration);
    final changed = reliable && (wallDelta - elapsed).abs() > 2000000;
    return RestDisplay(
      (remaining / 1000000).ceil(),
      uncertain || !reliable || changed,
    );
  }
}

class RestDisplay {
  final int remainingSeconds;
  final bool uncertain;
  const RestDisplay(this.remainingSeconds, this.uncertain);
  String get label => remainingSeconds == 0
      ? 'Rest timer complete${uncertain ? ' · approximate' : ''}'
      : 'Rest timer${uncertain ? ' · approximate' : ''} · '
            '${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}';
}
