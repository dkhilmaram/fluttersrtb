import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A slim banner shown at the top of a page when the device is offline.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     if (!isOnline) const OfflineBanner(),
///     // rest of page...
///   ],
/// )
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.goldDark,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Mode hors-ligne — les données seront synchronisées dès la reconnexion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}