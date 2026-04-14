import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/daos/voyage_dao.dart';
import '../../core/constants/api_constants.dart';

class VoyageRepository {
  VoyageRepository._();

  // ── Fetch voyages programmés from server, fall back to cache ──
  static Future<List<dynamic>> getVoyagesProgrammes(int matricule) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConstants.voyagesProgrammes}?matricule=$matricule',
            ),
          )
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body);
        final voyages = data['voyages'] as List<dynamic>? ?? [];
        await VoyageDao.saveVoyages(matricule, voyages);
        await VoyageDao.clearStaleVoyageStatuts(voyages);
        return voyages;
      }
    } catch (_) {
      // fall through to cache
    }

    return await VoyageDao.getVoyages(matricule) ?? [];
  }

  // ── Fetch voyages non-programmés, fall back to cache ──
  static Future<List<dynamic>> getVoyagesNonProgrammes(int matricule) async {
    // Use negative matricule as cache key to avoid collision.
    final cacheKey = -matricule;

    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConstants.voyagesNonProgrammes}?matricule=$matricule',
            ),
          )
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body);
        final voyages = data['voyages'] as List<dynamic>? ?? [];
        await VoyageDao.saveVoyages(cacheKey, voyages);
        return voyages;
      }
    } catch (_) {
      // fall through to cache
    }

    return await VoyageDao.getVoyages(cacheKey) ?? [];
  }
}