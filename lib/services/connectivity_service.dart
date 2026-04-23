import 'dart:async';
import 'dart:io';

class ConnectivityService {
  ConnectivityService._();

  static StreamSubscription<bool>? _subscription;
  static bool _isCurrentlyOnline = true;

  static void startListening({
    required void Function() onReconnect,
    void Function()? onDisconnect,
  }) {
    if (_subscription != null) return;

    _subscription = Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _checkConnectivity())
        .distinct()
        .listen((isOnline) {
      if (isOnline && !_isCurrentlyOnline) {
        print('📶 ConnectivityService: back online — triggering sync');
        onReconnect();
      } else if (!isOnline && _isCurrentlyOnline) {
        print('📵 ConnectivityService: went offline');
        onDisconnect?.call();
      }
      _isCurrentlyOnline = isOnline;
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

  static Future<bool> isOnline() => _checkConnectivity();

  /// Synchronous snapshot — safe to call from anywhere without awaiting.
  static bool get isConnected => _isCurrentlyOnline;
}