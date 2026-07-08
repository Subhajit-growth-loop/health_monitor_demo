import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus that also supports a manual override, so
/// the demo can toggle "offline mode" from the UI to show the offline-first
/// behaviour without physically disabling the network.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _connectivity.onConnectivityChanged.listen((results) {
      _systemOnline = !results.contains(ConnectivityResult.none);
      _emit();
    });
    _init();
  }

  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();

  bool _systemOnline = true;
  bool _manualOffline = false;

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _systemOnline = !results.contains(ConnectivityResult.none);
    _emit();
  }

  /// Effective online state — online only when the system reports connectivity
  /// AND the user hasn't forced offline mode.
  bool get isOnline => _systemOnline && !_manualOffline;

  bool get manualOffline => _manualOffline;

  Stream<bool> get onStatusChanged => _controller.stream;

  void setManualOffline(bool value) {
    _manualOffline = value;
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(isOnline);
  }

  void dispose() => _controller.close();
}
