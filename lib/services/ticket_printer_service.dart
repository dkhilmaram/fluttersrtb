import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Lexmark Printer Service ──────────────────────────────────────────────────
//
// Dependencies (pubspec.yaml):
//   printing: ^5.13.1
//   pdf: ^3.10.8
//
// Ticket layout (both printed PDF and in-app dialog):
//   • Header:       SRTB / BILLETTERIE
//   • Route box:    Départ > Arrivée
//   • Detail rows:  Tarif | <value>
//                   Prix unitaire | <value> millimes   ← replaces big total
//   • Agent + Date rows
//   • Unique ticket ID badge
//   • QR code (unique per unit)
//   • Footer: "Merci pour votre voyage"
//
// When quantite > 1:
//   PDF  → one continuous page, height = quantite × 120 mm, stacked units
//   App  → dialog scrolls through stacked _PrintedTicketWidget instances
// ─────────────────────────────────────────────────────────────────────────────

class PrinterService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  PrinterService._();
  static final instance = PrinterService._();

  // ── Discover printers on the local network ─────────────────────────────────
  Future<List<Printer>> discoverPrinters() => Printing.listPrinters();

  // ── Test connection by printing a test page ────────────────────────────────
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

  // ── Print a ticket (handles qty > 1 internally) ────────────────────────────
  Future<bool> printTicket({
    required TicketData ticket,
    Printer? printer,
    PaperFormat format = PaperFormat.ticket58mm,
  }) async {
    final pdf = await _buildTicketPdf(ticket, format);
    try {
      if (printer != null) {
        return await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => pdf,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (_) async => pdf,
          name:
              'Ticket SRTB - ${ticket.pointDepart} > ${ticket.pointArrivee}',
        );
      }
    } catch (_) {
      return false;
    }
  }

  // ── Build test page PDF ────────────────────────────────────────────────────
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
                  border: pw.Border.all(
                      color: PdfColors.blueGrey800, width: 2),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SRTB - Test Imprimante',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Connexion Lexmark reussie OK',
                      style: pw.TextStyle(
                          fontSize: 14, color: PdfColors.green700),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Date: ${DateTime.now().toLocal()}',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600),
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

  // ── Build ticket PDF ───────────────────────────────────────────────────────
  //
  // qty = 1  → single 120 mm ticket page.
  // qty > 1  → one continuous page, height = qty × 120 mm, each unit stacked
  //            vertically with its own unique ID and QR code.
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List> _buildTicketPdf(
      TicketData t, PaperFormat format) async {
    final doc        = pw.Document();
    final font       = await PdfGoogleFonts.nunitoRegular();
    final fontBold   = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // One entry per physical ticket unit
    final List<_SingleTicket> tickets = List.generate(t.quantite, (i) {
      final id = TicketData.generateId();
      final qrPayload = jsonEncode({
        'id':    id,
        'vente': t.venteId,
        'seg':   t.segmentId,
        'dep':   t.pointDepart,
        'arr':   t.pointArrivee,
        'tarif': t.typeTarif,
        'pu':    t.prixUnitaire,
        'agent': t.matriculeAgent,
        'date':  t.date.toIso8601String(),
        'idx':   i + 1,
        'total': t.quantite,
      });
      return _SingleTicket(ticketId: id, qrPayload: qrPayload);
    });

    const double ticketHeightMm = 120;

    if (format == PaperFormat.ticket58mm) {
      final pageHeight = ticketHeightMm * t.quantite * PdfPageFormat.mm;

      final pdfFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        pageHeight,
        marginAll: 3 * PdfPageFormat.mm,
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
            children: [
              for (int i = 0; i < tickets.length; i++) ...[
                _ticketLayout(t, tickets[i]),
                if (i < tickets.length - 1)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text(
                      '- - - - - - - - - - - - - - - - - -',
                      style: pw.TextStyle(
                          color: PdfColors.grey400, fontSize: 6),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    } else {
      // A4: one ticket per page
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
                child: _ticketLayout(t, st),
              ),
            ),
          ),
        );
      }
    }

    return doc.save();
  }

  // ── Single ticket layout ───────────────────────────────────────────────────
  //
  // Rows:
  //   Tarif          | <value>
  //   Prix unitaire  | <value> millimes   ← compact detail row, no big number
  //   Agent          | <value>
  //   Date           | <value>
  // ─────────────────────────────────────────────────────────────────────────
  pw.Widget _ticketLayout(TicketData t, _SingleTicket st) {
    final navy   = PdfColor.fromHex('#0D1B3E');
    final gold   = PdfColor.fromHex('#D4A017');
    final isFree = t.montantTotal == 0;

    final String prixDisplay =
        isFree ? 'Gratuit' : '${t.prixUnitaire} millimes';
    final PdfColor prixColor =
        isFree ? PdfColors.green700 : navy;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: navy,
          padding:
              const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: pw.Column(
            children: [
              pw.Text(
                'S R T B',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'BILLETTERIE',
                style:
                    pw.TextStyle(color: gold, fontSize: 6, letterSpacing: 2),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 5),

        // ── Route ────────────────────────────────────────────────────────────
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: navy, width: 0.8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                t.pointDepart,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: navy,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Text(
                  '>',
                  style:
                      pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
              pw.Text(
                t.pointArrivee,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: navy,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 5),

        // ── Detail rows ───────────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey300),
        _detailRow('Tarif', t.typeTarif, navy),
        pw.Divider(color: PdfColors.grey300),
        _detailRowColored('Prix unitaire', prixDisplay, navy, prixColor),
        pw.Divider(color: PdfColors.grey300),

        pw.SizedBox(height: 3),

        // ── Agent + date ───────────────────────────────────────────────────────
        _detailRow('Agent', '${t.matriculeAgent}', navy),
        _detailRow(
          'Date',
          '${t.date.day.toString().padLeft(2, '0')}/'
          '${t.date.month.toString().padLeft(2, '0')}/'
          '${t.date.year}  '
          '${t.date.hour.toString().padLeft(2, '0')}:'
          '${t.date.minute.toString().padLeft(2, '0')}',
          navy,
        ),
        pw.SizedBox(height: 5),

        // ── Unique ticket ID ───────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 3),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EFF3FF'),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            st.ticketId,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: navy,
              letterSpacing: 0.8,
            ),
          ),
        ),
        pw.SizedBox(height: 5),

        // ── QR Code (unique per ticket unit) ───────────────────────────────────
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: st.qrPayload,
            width: 60,
            height: 60,
            color: navy,
            drawText: false,
          ),
        ),
        pw.SizedBox(height: 5),

        // ── Footer ─────────────────────────────────────────────────────────────
        pw.Text(
          '- - - - - - - - - - - -',
          style: pw.TextStyle(color: PdfColors.grey400),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Merci pour votre voyage',
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ── Detail row helpers ─────────────────────────────────────────────────────

  pw.Widget _detailRow(String label, String value, PdfColor navy) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
          ],
        ),
      );

  /// Same layout as [_detailRow] but value uses a custom [valueColor].
  pw.Widget _detailRowColored(
          String label, String value, PdfColor navy, PdfColor valueColor) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      );
}

// ── Internal helper: per-unit ticket identity ─────────────────────────────────
class _SingleTicket {
  final String ticketId;
  final String qrPayload;
  const _SingleTicket({required this.ticketId, required this.qrPayload});
}

// ── Paper format enum ─────────────────────────────────────────────────────────
enum PaperFormat { ticket58mm, a4 }

// ── Ticket data model ─────────────────────────────────────────────────────────
class TicketData {
  final String pointDepart;
  final String pointArrivee;
  final String typeTarif;
  final int quantite;
  final int prixUnitaire;
  final int montantTotal;
  final int matriculeAgent;
  final DateTime date;

  /// Used only by the in-app confirmation dialog QR widget.
  /// The printer generates per-ticket QR codes internally.
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

  // ── Unique ticket ID generator ─────────────────────────────────────────────
  //
  // Format: SRTB-YYYYMMDD-XXXXXX
  // ~1 M distinct values per day via 6-digit random suffix.
  // ─────────────────────────────────────────────────────────────────────────
  static String generateId() {
    final now    = DateTime.now();
    final rand   = math.Random();
    final y      = now.year.toString();
    final m      = now.month.toString().padLeft(2, '0');
    final d      = now.day.toString().padLeft(2, '0');
    final suffix = rand.nextInt(999999).toString().padLeft(6, '0');
    return 'SRTB-$y$m$d-$suffix';
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