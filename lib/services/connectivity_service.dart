import 'dart:async';
import 'dart:io';

/// Watches internet connectivity and notifies listeners when the device
/// comes back online.
///
/// SyncService calls [ConnectivityService.onReconnect] to trigger a sync
/// whenever connectivity is restored.
class ConnectivityService {
  ConnectivityService._();

  static StreamSubscription<bool>? _subscription;

  /// Starts polling for connectivity changes.
  /// [onReconnect] is called each time the device goes from offline → online.
  static void startListening({required void Function() onReconnect}) {
    if (_subscription != null) return; // already running

    bool _wasOnline = true; // optimistic start

    _subscription = Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _checkConnectivity())
        .distinct()
        .listen((isOnline) {
      if (isOnline && !_wasOnline) {
        print('📶 ConnectivityService: back online — triggering sync');
        onReconnect();
      }
      _wasOnline = isOnline;
    });

    print('✓ ConnectivityService: started');
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    print('✓ ConnectivityService: stopped');
  }

  static Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// One-shot check — useful for UI state.
  static Future<bool> isOnline() => _checkConnectivity();
}