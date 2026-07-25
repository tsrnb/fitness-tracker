import 'package:health/health.dart';

/// Thin wrapper around the `health` plugin (Apple HealthKit on iOS, Google
/// Health Connect on Android) — this is how virtually any watch (Apple
/// Watch, Wear OS, Fitbit, Garmin, Samsung, ...) gets its steps/calories into
/// this app: the watch already syncs into the platform health store, so we
/// only need one integration point rather than a per-brand SDK.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests read access for steps + active calories burned. Returns false
  /// if the user declines or the platform health store isn't available —
  /// callers should treat that as "skip the sync", not an error.
  Future<bool> requestAuthorization() async {
    await _ensureConfigured();
    try {
      final alreadyGranted = await _health.hasPermissions(_types) ?? false;
      if (alreadyGranted) return true;
      return await _health.requestAuthorization(_types);
    } catch (_) {
      return false;
    }
  }

  /// Fetches today's steps + active kcal burned. Returns null on any failure
  /// (permission denied, no health store on this device, etc.) so callers
  /// can silently skip the sync rather than crash or show an error.
  Future<({int steps, int kcal})?> fetchToday() async {
    try {
      final granted = await requestAuthorization();
      if (!granted) return null;

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      final steps = await _health.getTotalStepsInInterval(start, now) ?? 0;

      final energyPoints = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: now,
      );
      final kcal = energyPoints.fold<num>(0, (sum, p) {
        final value = p.value;
        return sum + (value is NumericHealthValue ? value.numericValue : 0);
      });

      return (steps: steps, kcal: kcal.round());
    } catch (_) {
      return null;
    }
  }
}
