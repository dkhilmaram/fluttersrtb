import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'ticket_data.dart';
export 'ticket_data.dart';

import 'printer_service_stub.dart' as _stub;

import 'printer_service_android.dart' as _droid;

class PrinterService {
  PrinterService._();
  static final instance = PrinterService._();

  static bool get _ok {
    try {
      return !kIsWeb && Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (!_ok) return;
    await _droid.doInitPrinter();
  }

  Future<bool> testPrint() async {
    if (!_ok) {
      debugPrint('[Printer] skipped on non-Android');
      return true;
    }
    return _droid.doTestPrint();
  }

  Future<bool> printTicket({
    required TicketData ticket,
    required List<Map<String, String>> ticketUnits,
  }) async {
    if (!_ok) {
      debugPrint('[Printer] skipped on non-Android');
      return true;
    }
    return _droid.doPrintTicket(ticket: ticket, ticketUnits: ticketUnits);
  }
}