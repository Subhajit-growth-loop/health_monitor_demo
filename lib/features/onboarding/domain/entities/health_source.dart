/// A distinct app/device that has written health data (e.g. "Dexcom",
/// "Withings", "Fitbit"), detected from Health Connect / HealthKit on the
/// device-connection step.
class HealthSource {
  const HealthSource(this.name);
  final String name;

  @override
  bool operator ==(Object other) => other is HealthSource && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
