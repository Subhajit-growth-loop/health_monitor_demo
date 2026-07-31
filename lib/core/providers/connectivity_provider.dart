import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../connectivity/connectivity_service.dart';

final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});
