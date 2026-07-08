/// Synchronization state of a locally-stored health record.
///
/// The local database doubles as a durable outbound queue: a record stays
/// [pending] until the backend explicitly confirms the write, at which point
/// it becomes [synced]. A failed upload leaves it [pending] (retried later);
/// [failed] is reserved for records the backend permanently rejected.
enum SyncStatus {
  pending('pending'),
  synced('synced'),
  failed('failed');

  const SyncStatus(this.value);
  final String value;

  static SyncStatus fromValue(String value) =>
      SyncStatus.values.firstWhere((s) => s.value == value);
}
