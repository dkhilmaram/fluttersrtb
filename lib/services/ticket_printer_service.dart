import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  PrinterService._();
  static final instance = PrinterService._();

  Future<List<Printer>> discoverPrinters() => Printing.listPrinters();

  Future<bool> testPrint({Printer? printer}) async {
    final pdf = await _buildTestPage();
    try {
      if (printer != null) {
        return await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => pdf,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (_) async => pdf,
          name: 'SRTB - Test Impression',
        );
      }
    } catch (_) {
      return false;
    }
  }

  /// [ticketUnits] must be the SAME list already generated in _saveTicket
  /// (keys: 'id' and 'qr'). We reuse them here — no new generateId() calls.
  Future<bool> printTicket({
    required TicketData ticket,
    required List<Map<String, String>> ticketUnits,
    Printer? printer,
    PaperFormat format = PaperFormat.ticket58mm,
  }) async {
    final pdf = await _buildTicketPdf(ticket, ticketUnits, format);
    try {
      if (printer != null) {
        return await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => pdf,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (_) async => pdf,
          name: 'Ticket SRTB - ${ticket.pointDepart} > ${ticket.pointArrivee}',
        );
      }
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _buildTestPage() async {
    final doc      = pw.Document();
    final font     = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                   pw.Row(
  mainAxisSize: pw.MainAxisSize.min,
  children: [
    pw.Text(
      'S R T B',
      style: pw.TextStyle(
        color: PdfColors.black,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 2,
      ),
    ),
    pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
      width: 0.5,
      height: 10,
      color: PdfColors.grey600,
    ),
    pw.Text(
      'BILLETTERIE',
      style: pw.TextStyle(
        color: PdfColors.grey700,
        fontSize: 6,
        letterSpacing: 1,
      ),
    ),
  ],
),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Connexion Lexmark reussie OK',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Date: ${DateTime.now().toLocal()}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _buildTicketPdf(
    TicketData t,
    List<Map<String, String>> ticketUnits,
    PaperFormat format,
  ) async {
    final doc        = pw.Document();
    final font       = await PdfGoogleFonts.nunitoRegular();
    final fontBold   = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // Try to load the SRTB logo from assets
    pw.MemoryImage? logoImage;
    try {
      final byteData = await rootBundle.load('assets/images/logo_srtb.png');
      logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    // Reuse the pre-generated IDs — do NOT call generateId() again
    final tickets = ticketUnits
        .map((u) => _SingleTicket(ticketId: u['id']!, qrPayload: u['qr']!))
        .toList();

    const double ticketHeightMm = 90.0;

    if (format == PaperFormat.ticket58mm) {
      final pageHeight = ticketHeightMm * t.quantite * PdfPageFormat.mm;
      final pdfFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        pageHeight,
        marginAll: 0,
      );

      doc.addPage(
        pw.Page(
          pageFormat: pdfFormat,
          theme: pw.ThemeData.withFont(
            base:   font,
            bold:   fontBold,
            italic: fontItalic,
          ),
          build: (_) => pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              for (final st in tickets) _ticketLayout(t, st, logoImage),
            ],
          ),
        ),
      );
    } else {
      for (final st in tickets) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(
              base:   font,
              bold:   fontBold,
              italic: fontItalic,
            ),
            build: (_) => pw.Center(
              child: pw.SizedBox(
                width: 58 * PdfPageFormat.mm,
                child: _ticketLayout(t, st, logoImage),
              ),
            ),
          ),
        );
      }
    }

    return doc.save();
  }

  pw.Widget _ticketLayout(TicketData t, _SingleTicket st, pw.MemoryImage? logo) {
    final isFree = t.montantTotal == 0;
    final String prixDisplay =
        isFree ? 'Gratuit' : '${t.prixUnitaire} millimes';

    final dateStr =
        '${t.date.day.toString().padLeft(2, '0')}/'
        '${t.date.month.toString().padLeft(2, '0')}/'
        '${t.date.year}  '
        '${t.date.hour.toString().padLeft(2, '0')}:'
        '${t.date.minute.toString().padLeft(2, '0')}';

    const double hPad = 6.0;

    return pw.SizedBox(
      width: 58 * PdfPageFormat.mm,
      height: 90 * PdfPageFormat.mm,
      child: pw.Padding(
        padding: pw.EdgeInsets.symmetric(
          horizontal: hPad * PdfPageFormat.mm,
          vertical: 4 * PdfPageFormat.mm,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [

            // ── Header: logo LEFT, "S R T B" RIGHT ──────────────────────
            pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.center,
  children: [
    logo != null
        ? pw.Image(logo, width: 28, height: 28, fit: pw.BoxFit.contain)
        : pw.Text(
            'SRTB',
            style: pw.TextStyle(
              color: PdfColors.black,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
    pw.SizedBox(width: 6),
    pw.Text(
      'S R T B',
      style: pw.TextStyle(
        color: PdfColors.black,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 2,
      ),
    ),
    pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
      width: 0.5,
      height: 10,
      color: PdfColors.grey600,
    ),
    pw.Text(
      'BILLETTERIE',
      style: pw.TextStyle(
        color: PdfColors.grey700,
        fontSize: 6,
        letterSpacing: 1,
      ),
    ),
  ],
),
            pw.SizedBox(height: 4),
            _fullDivider(),
            pw.SizedBox(height: 4),

            // ── Route box ────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.7),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    t.pointDepart,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                    child: pw.Text(
                      '>',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ),
                  pw.Text(
                    t.pointArrivee,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            _fullDivider(),
            pw.SizedBox(height: 2),

            // ── Detail rows ──────────────────────────────────────────────
            _detailRow('Tarif',         t.typeTarif),
            _detailRow('Prix unitaire', prixDisplay),
            pw.SizedBox(height: 4),
            _detailRow('Agent', '${t.matriculeAgent}'),
            _detailRow('Date',  dateStr),
            pw.SizedBox(height: 4),
            _fullDivider(),
            pw.SizedBox(height: 4),

            // ── Ticket ID ────────────────────────────────────────────────
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  st.ticketId,
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 4),

            // ── QR code ──────────────────────────────────────────────────
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: st.qrPayload,
                width: 46,
                height: 46,
                color: PdfColors.black,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 4),

            // ── Footer ───────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                'Merci pour votre voyage',
                style: pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                '- - - - - - - - - - - - - - - - - -',
                style: pw.TextStyle(color: PdfColors.grey500, fontSize: 5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _fullDivider() => pw.Container(
        width: double.infinity,
        height: 0.5,
        color: PdfColors.grey400,
      );

  pw.Widget _detailRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 0),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
      );
}


class _SingleTicket {
  final String ticketId;
  final String qrPayload;
  const _SingleTicket({required this.ticketId, required this.qrPayload});
}

enum PaperFormat { ticket58mm, a4 }

class TicketData {
  final String pointDepart;
  final String pointArrivee;
  final String typeTarif;
  final int quantite;
  final int prixUnitaire;
  final int montantTotal;
  final int matriculeAgent;
  final DateTime date;
  final String qrData;
  final int venteId;
  final int segmentId;

  const TicketData({
    required this.pointDepart,
    required this.pointArrivee,
    required this.typeTarif,
    required this.quantite,
    required this.prixUnitaire,
    required this.montantTotal,
    required this.matriculeAgent,
    required this.date,
    required this.qrData,
    this.venteId   = 0,
    this.segmentId = 0,
  });

  /// Sequence is GLOBAL — never resets across days.
  /// Date in the ID reflects today for readability only.
  static Future<String> generateId() async {
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();
    final today = '${now.year}'
                  '${now.month.toString().padLeft(2, '0')}'
                  '${now.day.toString().padLeft(2, '0')}';
    final seq = (prefs.getInt('srtb_ticket_seq') ?? 0) + 1;
    await prefs.setInt('srtb_ticket_seq', seq);
    final seqStr = seq.toString().padLeft(6, '0');
    return 'SRTB-$today-$seqStr';
  }

  factory TicketData.fromVoyageMap({
    required Map<String, dynamic> voyage,
    required String dep,
    required String arr,
    required String tarif,
    required int qte,
    required int prixU,
    required int total,
  }) {
    final now       = DateTime.now();
    final venteId   = voyage['id']              as int? ?? 0;
    final segmentId = voyage['id_segment']      as int? ?? 0;
    final agent     = voyage['matricule_agent'] as int? ?? 0;

    final qrPayload = jsonEncode({
      'vente': venteId,
      'seg':   segmentId,
      'dep':   dep,
      'arr':   arr,
      'tarif': tarif,
      'qty':   qte,
      'pu':    prixU,
      'total': total,
      'agent': agent,
      'date':  now.toIso8601String(),
    });

    return TicketData(
      pointDepart:    dep,
      pointArrivee:   arr,
      typeTarif:      tarif,
      quantite:       qte,
      prixUnitaire:   prixU,
      montantTotal:   total,
      matriculeAgent: agent,
      date:           now,
      qrData:         qrPayload,
      venteId:        venteId,
      segmentId:      segmentId,
    );
  }
}