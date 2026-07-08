/// An aggregated value for a single day, used to render trend charts.
class DailyPoint {
  const DailyPoint({required this.day, required this.value});

  final DateTime day; // normalized to local midnight
  final double value;
}
