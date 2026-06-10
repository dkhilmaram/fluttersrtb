import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TicketData {
  final String   pointDepart;
  final String   pointArrivee;
  final String   typeTarif;
  final int      quantite;
  final int      prixUnitaire;
  final int      montantTotal;
  final int      matriculeAgent;
  final DateTime date;
  final String   qrData;
  final int      venteId;
  final int      segmentId;

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

  static Future<String> generateId() async {
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();
    final today = '${now.year}'
                  '${now.month.toString().padLeft(2, '0')}'
                  '${now.day.toString().padLeft(2, '0')}';
    final seq    = (prefs.getInt('srtb_ticket_seq') ?? 0) + 1;
    await prefs.setInt('srtb_ticket_seq', seq);
    final seqStr = seq.toString().padLeft(6, '0');
    return 'SRTB-$today-$seqStr';
  }

  factory TicketData.fromVoyageMap({
    required Map<String, dynamic> voyage,
    required String dep,
    required String arr,
    required String tarif,
    required int    qte,
    required int    prixU,
    required int    total,
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