// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'ticket_data.dart';

Future<void> doInitPrinter() async {
  await SunmiPrinter.bindingPrinter();
}

Future<bool> doTestPrint() async {
  try {
    await SunmiPrinter.startTransactionPrint(true);
    await SunmiPrinter.printText(
      'S R T B',
      style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.printText(
      'BILLETTERIE',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.line();
    await SunmiPrinter.printText(
      'Imprimante OK',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(3);
    await SunmiPrinter.exitTransactionPrint(true);
    return true;
  } catch (e) {
    debugPrint('SUNMI testPrint error: $e');
    return false;
  }
}

Future<bool> doPrintTicket({
  required TicketData ticket,
  required List<Map<String, String>> ticketUnits,
}) async {
  try {
    await SunmiPrinter.startTransactionPrint(true);
    for (final unit in ticketUnits) {
      await _printSingle(ticket, unit['id']!, unit['qr']!);
    }
    await SunmiPrinter.exitTransactionPrint(true);
    return true;
  } catch (e) {
    debugPrint('SUNMI printTicket error: $e');
    return false;
  }
}

const int _lineWidth = 32;

Future<void> _printDetailRow(String label, String value) async {
  final maxValue = _lineWidth - label.length - 1;
  final safeValue =
      value.length > maxValue ? value.substring(0, maxValue) : value;
  final spaces = _lineWidth - label.length - safeValue.length;
  final line = label + (' ' * (spaces > 0 ? spaces : 1)) + safeValue;
  await SunmiPrinter.printText(
    line,
    style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
  );
}

Future<void> _printSingle(TicketData t, String ticketId, String qr) async {
  final isFree  = t.montantTotal == 0;
  final prixStr = isFree ? 'Gratuit' : '${t.prixUnitaire} millimes';
  final dateStr = _fmt(t.date);

  // ── Header ────────────────────────────────────────────────────────────────
  await SunmiPrinter.printText(
    'S R T B',
    style: SunmiTextStyle(
      bold: true,
      fontSize: 24,
      align: SunmiPrintAlign.CENTER,
    ),
  );
  await SunmiPrinter.printText(
    'BILLETTERIE',
    style: SunmiTextStyle(
      fontSize: 18,
      align: SunmiPrintAlign.CENTER,
    ),
  );

  // ── Route — full names, smaller font so long names wrap naturally ─────────
  await SunmiPrinter.line();
  await SunmiPrinter.printText(
    '${t.pointDepart}  >  ${t.pointArrivee}',
    style: SunmiTextStyle(
      bold: true,
      fontSize: 16,
      align: SunmiPrintAlign.CENTER,
    ),
  );
  await SunmiPrinter.line();

  // ── Detail rows ───────────────────────────────────────────────────────────
  await _printDetailRow('Tarif',         t.typeTarif);
  await _printDetailRow('Prix unitaire', prixStr);
  await SunmiPrinter.lineWrap(1);
  await _printDetailRow('Agent',         '${t.matriculeAgent}');
  await _printDetailRow('Date',          dateStr);

  // ── Separator ─────────────────────────────────────────────────────────────
  await SunmiPrinter.line();

  // ── Ticket ID ─────────────────────────────────────────────────────────────
  await SunmiPrinter.printText(
    ticketId,
    style: SunmiTextStyle(
      bold: true,
      fontSize: 18,
      align: SunmiPrintAlign.CENTER,
    ),
  );
  await SunmiPrinter.lineWrap(1);

  // ── QR code ───────────────────────────────────────────────────────────────
  await SunmiPrinter.printQRCode(
    qr,
    style: SunmiQrcodeStyle(
      qrcodeSize: 3,
      errorLevel: SunmiQrcodeLevel.LEVEL_M,
    ),
  );
  await SunmiPrinter.lineWrap(1);

  // ── Footer ────────────────────────────────────────────────────────────────
  await SunmiPrinter.printText(
    'bon voyage',
    style: SunmiTextStyle(
      fontSize: 16,
      align: SunmiPrintAlign.CENTER,
    ),
  );
  await SunmiPrinter.printText(
    '- - - - - - - - - - - - - - - -',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  await SunmiPrinter.lineWrap(4);
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}  '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';