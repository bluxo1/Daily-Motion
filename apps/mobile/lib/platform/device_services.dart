import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/rest_timer.dart';

/// Small native boundary: no credentials, network, notifications or workout data.
class DeviceServices implements RestClock {
  static const channel = MethodChannel('daily_motion/device');
  const DeviceServices();

  static Future<void> prepareStorage(Directory directory) async {
    if (!Platform.isIOS) return;
    final excluded = await channel.invokeMethod<bool>('excludeBackup', {
      'path': directory.path,
    });
    if (excluded != true) {
      throw const FileSystemException('Private storage unavailable');
    }
  }

  @override
  Future<ClockSample> sample() async {
    try {
      final value = await channel
          .invokeMethod<Object?>('clock')
          .timeout(const Duration(milliseconds: 20));
      if (value is Map &&
          value['wall_ms'] is int &&
          value['elapsed_us'] is int &&
          value['continuity_id'] is String &&
          (value['continuity_id'] as String).isNotEmpty &&
          (value['elapsed_us'] as int) >= 0) {
        return ClockSample(
          DateTime.fromMillisecondsSinceEpoch(
            value['wall_ms'] as int,
            isUtc: true,
          ),
          elapsedUs: value['elapsed_us'] as int,
          continuityId: value['continuity_id'] as String,
        );
      }
    } on PlatformException {
      // Native unavailability makes the display approximate, never the set unsaved.
    } on MissingPluginException {
      // Desktop qualification uses wall-only fallback, not a hardware claim.
    } on TimeoutException {
      // A stalled platform bridge cannot indefinitely delay local logging.
    } on RangeError {
      // Invalid native timestamps are never authoritative timer data.
    }
    return ClockSample(DateTime.now().toUtc());
  }

  Future<Map<String, dynamic>> information() async =>
      await channel.invokeMapMethod<String, dynamic>('device') ??
      (throw const FormatException('Device information unavailable'));
}
