/// A distinct app/device that has written health data (e.g. "Dexcom",
/// "Withings", "Fitbit"), detected from Health Connect / HealthKit.
///
/// [rawTypesByCategory] maps each display category key ('vitals', 'activity',
/// 'wellness') to the set of raw platform type strings found for this source,
/// e.g. `{'vitals': {'BLOOD_GLUCOSE', 'HEART_RATE'}}`.
class HealthSource {
  HealthSource(
    this.name, {
    Map<String, Set<String>>? rawTypesByCategory,
  }) : rawTypesByCategory = rawTypesByCategory ?? {};

  final String name;
  final Map<String, Set<String>> rawTypesByCategory;

  /// The display category keys this source covers.
  Set<String> get categories => rawTypesByCategory.keys.toSet();

  bool hasCategory(String catKey) => rawTypesByCategory.containsKey(catKey);

  @override
  bool operator ==(Object other) => other is HealthSource && other.name == name;

  @override
  int get hashCode => name.hashCode;
}