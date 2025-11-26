import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity Service
/// Monitors network status and provides callbacks for connection changes
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isConnected = true;
  bool _wasConnected = true;
  ConnectivityResult _connectionType = ConnectivityResult.none;

  // Callbacks
  Function()? onConnectionLost;
  Function()? onConnectionRestored;
  Function(ConnectivityResult)? onConnectionTypeChanged;

  /// Get current connection status
  bool get isConnected => _isConnected;
  ConnectivityResult get connectionType => _connectionType;

  /// Initialize the connectivity service
  Future<void> initialize({
    Function()? onLost,
    Function()? onRestored,
    Function(ConnectivityResult)? onTypeChanged,
  }) async {
    onConnectionLost = onLost;
    onConnectionRestored = onRestored;
    onConnectionTypeChanged = onTypeChanged;

    // Check initial connection status
    await _checkConnection();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

    debugPrint('ConnectivityService initialized. Connected: $_isConnected, Type: $_connectionType');
  }

  /// Check current connection
  Future<bool> _checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Take the first (primary) connection result
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

    _wasConnected = _isConnected;
    _connectionType = result;
    _isConnected = result != ConnectivityResult.none;

    // Notify of connection type change
    onConnectionTypeChanged?.call(result);

    // Check for connection state transitions
    if (_wasConnected && !_isConnected) {
      debugPrint('Connection lost!');
      onConnectionLost?.call();
    } else if (!_wasConnected && _isConnected) {
      debugPrint('Connection restored! Type: $result');
      onConnectionRestored?.call();
    }
  }

  /// Check if we have a connection (can be called anytime)
  Future<bool> checkConnectivity() async {
    return await _checkConnection();
  }

  /// Get a user-friendly connection status message
  String getConnectionStatusMessage() {
    if (!_isConnected) {
      return 'No internet connection';
    }

    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return 'Connected via WiFi';
      case ConnectivityResult.mobile:
        return 'Connected via Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Connected via Ethernet';
      case ConnectivityResult.vpn:
        return 'Connected via VPN';
      case ConnectivityResult.bluetooth:
        return 'Connected via Bluetooth';
      case ConnectivityResult.other:
        return 'Connected';
      case ConnectivityResult.none:
        return 'No internet connection';
    }
  }

  /// Get connection quality hint
  String getConnectionQualityHint() {
    switch (_connectionType) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return 'Good connection - alerts will be instant';
      case ConnectivityResult.mobile:
        return 'Mobile data - alerts may be slightly delayed';
      case ConnectivityResult.vpn:
        return 'VPN connection - alerts may be slightly delayed';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth connection - alerts may be unreliable';
      case ConnectivityResult.other:
        return 'Limited connection';
      case ConnectivityResult.none:
        return 'You will not receive alerts without internet';
    }
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Extension to check for healthy connection
extension ConnectivityCheck on ConnectivityService {
  /// Returns true if connection is suitable for real-time alerts
  bool get hasHealthyConnection {
    if (!isConnected) return false;
    // WiFi, Ethernet, Mobile, and VPN are considered healthy
    return connectionType == ConnectivityResult.wifi ||
           connectionType == ConnectivityResult.ethernet ||
           connectionType == ConnectivityResult.mobile ||
           connectionType == ConnectivityResult.vpn;
  }
}
