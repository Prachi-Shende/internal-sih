import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/resilience_state.dart';

class ConnectivitySensor {
  final Connectivity _connectivity = Connectivity();

  /// Checks whether the device currently has a network connection.
  Future<ConnectivityStatus> getStatus() async {
    final result = await _connectivity.checkConnectivity();

    if (result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.ethernet)) {
      return ConnectivityStatus.online;
    }

    if (result.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }

    return ConnectivityStatus.unknown;
  }
}
