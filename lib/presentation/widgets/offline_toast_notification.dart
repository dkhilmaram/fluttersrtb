import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class OfflineToastNotification {
  static OverlayEntry? _entry;
  static Timer?        _timer;

  static void show(BuildContext context) {
    _timer?.cancel();
    try { _entry?.remove(); } catch (_) {}
    _entry = null;

    final t = AppLocalizations.of(context)!;

    final entry = OverlayEntry(
      builder: (_) => _OfflineToastWidget(msg: t.horsLigneActionsSync),
    );
    _entry = entry;
    Overlay.of(context).insert(entry);

    _timer = Timer(const Duration(milliseconds: 2000), () {
      try { entry.remove(); } catch (_) {}
      if (_entry == entry) _entry = null;
    });
  }
}

class _OfflineToastWidget extends StatefulWidget {
  final String msg;
  const _OfflineToastWidget({required this.msg});

  @override
  State<_OfflineToastWidget> createState() => _OfflineToastWidgetState();
}

class _OfflineToastWidgetState extends State<_OfflineToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, right: 16),
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade700.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.offline_bolt,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.msg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}