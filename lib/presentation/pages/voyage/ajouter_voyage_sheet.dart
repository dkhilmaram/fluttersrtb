import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/database/daos/voyage_dao.dart';
import '../../../data/database/daos/ligne_dao.dart';
import '../../../l10n/app_localizations.dart';

// ── Design tokens ─────────────────────────────────────────────
const _kGreen    = Color(0xFF0E7C5B);
const _kBg       = Color(0xFF091429);
const _kCard     = Color(0xFF112045);
const _kBorder   = Color(0xFF1E3566);
const _kNavyMid  = Color(0xFF1A3260);
const _kGold     = Color(0xFFFFB800);
const _kMuted    = Color(0xFF8B9DC3);

// ── Sentinel error keys ───────────────────────────────────────
const _kErrCodeAgence = '__ERR_CODE_AGENCE__';
const _kErrHorsLigne  = '__ERR_HORS_LIGNE__';

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────

class AjouterVoyageSheet extends StatefulWidget {
  final Map<String, dynamic> agent;
  const AjouterVoyageSheet({super.key, required this.agent});

  @override
  State<AjouterVoyageSheet> createState() => _AjouterVoyageSheetState();
}

class _AjouterVoyageSheetState extends State<AjouterVoyageSheet> {
  // ── State ──────────────────────────────────────────────────
  bool   _loadingLignes = true;
  List<Map<String, dynamic>> _lignes = [];
  String? _loadError;
  bool    _fromCache = false;
  String? _cachedAt;

  Map<String, dynamic>? _selectedLigne;
  DateTime _selectedDateTime = DateTime.now();

  bool    _submitting  = false;
  String? _submitError;

  // ── Getters ───────────────────────────────────────────────
  int? get _codeAgence {
    final raw = widget.agent['code_agence'];
    if (raw == null) return null;
    final v = raw is int ? raw : int.tryParse(raw.toString());
    return (v == null || v == 0) ? null : v;
  }

  int get _matricule =>
      widget.agent['matricule_agent'] ?? widget.agent['matricule'] ?? 0;

  int get _idAppareil {
    final raw = widget.agent['id_appareil'];
    if (raw == null) return 0;
    return (raw is int ? raw : int.tryParse(raw.toString())) ?? 0;
  }

  int  get _matriculeNonProg => -_matricule;
  bool get _isNow =>
      _selectedDateTime.difference(DateTime.now()).abs().inMinutes < 1;

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_codeAgence == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {
        _loadError     = _kErrCodeAgence;
        _loadingLignes = false;
      }));
      return;
    }
    _fetchLignes();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> _fetchLignes() async {
    setState(() {
      _loadingLignes = true;
      _loadError     = null;
      _fromCache     = false;
      _cachedAt      = null;
    });

    if (_codeAgence == null) {
      setState(() { _loadError = _kErrCodeAgence; _loadingLignes = false; });
      return;
    }

    try {
      final res = await http
          .get(
            Uri.parse('${ApiConstants.billetterie}/lignes/agence/$_codeAgence'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final list = (data['lignes'] as List)
              .map((l) => Map<String, dynamic>.from(l as Map))
              .toList();
          await LigneDao.cacheLignes(_codeAgence!, list);
          if (!mounted) return;
          setState(() { _lignes = list; _loadingLignes = false; });
          return;
        }
      }
    } catch (_) {}

    // Fallback → local cache
    final cached = await LigneDao.getCachedLignes(_codeAgence!);
    if (!mounted) return;

    if (cached.isNotEmpty) {
      final ts = await LigneDao.getCacheTimestamp(_codeAgence!);
      setState(() {
        _lignes = cached; _loadingLignes = false;
        _fromCache = true; _cachedAt = ts;
      });
    } else {
      setState(() { _loadError = _kErrHorsLigne; _loadingLignes = false; });
    }
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (_selectedLigne == null) {
      setState(() => _submitError = loc.veuillerSelectionnerLigne);
      return;
    }
    setState(() { _submitting = true; _submitError = null; });

    final lg   = _selectedLigne!;
    final body = <String, dynamic>{
      'id_ligne':        lg['id_ligne'],
      'depart':          lg['depart']    ?? lg['point_depart']  ?? '',
      'arrivee':         lg['arrivee']   ?? lg['point_arrive']  ?? '',
      'nom_ligne':       lg['nom_ligne'] ?? '',
      'type':            'spontané',
      'statut':          'actif',
      'matricule_agent': _matricule,
      'id_appareil':     _idAppareil,
      'code_agence':     _codeAgence,
      'date_heure':      _selectedDateTime.toIso8601String(),
    };
    final idBillet = widget.agent['id_billet'];
    if (idBillet != null) body['id_billet'] = idBillet;

    bool success = false;
    bool offline = false;

    try {
      final res = await http
          .post(
            Uri.parse(ApiConstants.createVoyage),
            headers: {'Content-Type': 'application/json'},
            body:    jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['success'] == true || data['id_voyage'] != null) {
          final vid = data['id_voyage'] as int?;
          if (vid != null) {
            await VoyageDao.saveVoyageStatut(vid, 'actif', serverStatut: 'actif');
          }
          success = true;
        } else { offline = true; }
      } else { offline = true; }
    } catch (_) { offline = true; }

    if (offline) {
      await VoyageDao.saveOfflineVoyageToCache(
        matriculeNonProg: _matriculeNonProg,
        voyageData: {
          ...body,
          'depart':    lg['depart']    ?? lg['point_depart'] ?? '',
          'arrivee':   lg['arrivee']   ?? lg['point_arrive'] ?? '',
          'nom_ligne': lg['nom_ligne'] ?? '',
        },
      );
      success = true;
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _submitting = false; _submitError = loc.impossibleCreerVoyage; });
    }
  }

  // ── Date picker ───────────────────────────────────────────
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    ThemeData greenTheme(BuildContext ctx) => Theme.of(ctx).copyWith(
      colorScheme: const ColorScheme.light(primary: _kGreen, onPrimary: Colors.white),
    );

    final date = await showDatePicker(
      context:     context,
      initialDate: _selectedDateTime,
      firstDate:   now,
      lastDate:    now.add(const Duration(days: 30)),
      builder:     (ctx, child) => Theme(data: greenTheme(ctx), child: child!),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder:     (ctx, child) => Theme(data: greenTheme(ctx), child: child!),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _selectedDateTime = picked.isBefore(now) ? now : picked);
  }

  // ── Formatters ────────────────────────────────────────────
  String _fmt(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year}  ${p(dt.hour)}:${p(dt.minute)}';
  }

  String _fmtCache(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String p(int n) => n.toString().padLeft(2, '0');
      return '${p(dt.day)}/${p(dt.month)}/${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
    } catch (_) { return iso; }
  }

  String _resolveError(String key, AppLocalizations loc) => switch (key) {
    _kErrCodeAgence => loc.codeAgenceIntrouvable,
    _kErrHorsLigne  => loc.horsLigneAucuneLigneCache,
    _                => key,
  };

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc    = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return ConstrainedBox(
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.52,
  ),
      child: Container(
        decoration: const BoxDecoration(
          color:        _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 32, height: 3,
                decoration: BoxDecoration(
                  color:        Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color:        _kGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: _kGreen.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.add_road_rounded, color: _kGreen, size: 14),
                  ),
                  const SizedBox(width: 10),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.nouveauVoyage,
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold,
                            color: Colors.white, letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _codeAgence != null
                              ? loc.voyageSpontaneAgence(_codeAgence!)
                              : loc.voyageSpontaneAgenceInconnue,
                          style: TextStyle(
                            fontSize: 11,
                            color: _codeAgence != null ? _kMuted : Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Agence badge
                  if (_codeAgence != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:        _kGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(color: _kGold.withOpacity(0.3)),
                      ),
                      child: Text(
                        '#$_codeAgence',
                        style: const TextStyle(
                          fontSize: 10, color: _kGold, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.white.withOpacity(0.07)),

            // ── Scrollable form ───────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(14, 8, 14, bottom + 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne
                    _fieldLabel(loc.ligneLabel),
                    const SizedBox(height: 6),
                    _buildLignePicker(loc),

                    if (_fromCache) ...[
                      const SizedBox(height: 5),
                      _cacheBadge(loc),
                    ],

                    const SizedBox(height: 8),

                    // Date/heure
                    _fieldLabel(loc.dateHeureDepart),
                    const SizedBox(height: 6),
                    _buildDateTimePicker(loc),

                    // Error
                    if (_submitError != null) ...[
                      const SizedBox(height: 10),
                      _errorBanner(_submitError!),
                    ],

                    const SizedBox(height: 2),

                    // Buttons
                    Row(
                      children: [
                        // Annuler
                        SizedBox(
                          height: 42, width: 76,
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kMuted,
                              side:    const BorderSide(color: _kBorder),
                              padding: EdgeInsets.zero,
                              shape:   RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              loc.annuler,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Créer
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed:
                                  (_submitting || _loadingLignes || _codeAgence == null)
                                      ? null
                                      : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:         _kGreen,
                                foregroundColor:         Colors.white,
                                disabledBackgroundColor: _kGreen.withOpacity(0.3),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize:      MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_rounded, size: 15),
                                        const SizedBox(width: 6),
                                        Text(
                                          loc.creerVoyage,
                                          style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Line picker ───────────────────────────────────────────
  Widget _buildLignePicker(AppLocalizations loc) {
    if (_codeAgence == null) return _errorBanner(loc.codeAgenceIntrouvable);

    if (_loadingLignes) {
      return _shell(
        child: const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _errorBanner(_resolveError(_loadError!, loc)),
          TextButton.icon(
            onPressed:  _fetchLignes,
            icon:       const Icon(Icons.refresh_rounded, size: 13),
            label:      Text(loc.reessayer,
                            style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: _kGreen,
              minimumSize:     Size.zero,
              padding:         const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      );
    }

    if (_lignes.isEmpty) {
      return _shell(
        color: Colors.amber.withOpacity(0.07),
        borderColor: Colors.amber.withOpacity(0.25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(loc.aucuneLigneAgence,
                    style: const TextStyle(color: Colors.amber, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedLigne != null;
    return _shell(
      highlighted: selected,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value:         _selectedLigne,
          isExpanded:    true,
          dropdownColor: const Color(0xFF1A3260),
          hint: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(loc.selectionnerLigne,
                style: const TextStyle(color: _kMuted, fontSize: 13)),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: selected ? _kGreen : _kMuted,
              size:  20,
            ),
          ),
          borderRadius: BorderRadius.circular(14),
          items: _lignes.map((ligne) {
            final dep = ligne['depart']    ?? ligne['point_depart'] ?? '';
            final arr = ligne['arrivee']   ?? ligne['point_arrive'] ?? '';
            final nom = ligne['nom_ligne'] ?? 'Ligne #${ligne['id_ligne']}';
            return DropdownMenuItem<Map<String, dynamic>>(
              value: ligne,
             child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize:       MainAxisSize.min,
    mainAxisAlignment:  MainAxisAlignment.center,
    children: [
      Text(nom,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: Colors.white,
          )),
      Text('$dep → $arr',
          overflow: TextOverflow.ellipsis, maxLines: 1,
          style: const TextStyle(fontSize: 10, color: _kMuted)),
    ],
  ),
),
            );
          }).toList(),
          onChanged: (val) => setState(() {
            _selectedLigne = val;
            _submitError   = null;
          }),
        ),
      ),
    );
  }

  // ── Date/time picker ──────────────────────────────────────
  Widget _buildDateTimePicker(AppLocalizations loc) {
    return GestureDetector(
      onTap: _pickDateTime,
      child: _shell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color:        _kGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded, size: 14, color: _kGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt(_selectedDateTime),
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isNow ? loc.maintenant : loc.heurePersonnalisee,
                      style: TextStyle(
                        fontSize:   10,
                        color:      _isNow ? _kMuted : _kGreen,
                        fontWeight: _isNow ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 13, color: _kMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cache badge ───────────────────────────────────────────
  Widget _cacheBadge(AppLocalizations loc) {
    final label = _cachedAt != null
        ? loc.donneesLocalesDate(_fmtCache(_cachedAt!))
        : loc.donneesLocales;

    return Row(
      children: [
        const Icon(Icons.offline_bolt_outlined, size: 11, color: Colors.amber),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.amber)),
        ),
        GestureDetector(
          onTap: _fetchLignes,
          child: const Text(
            'Actualiser', // replaced by loc.actualiser at runtime
            style: TextStyle(
              fontSize: 10, color: _kGreen,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: _kGreen,
            ),
          ),
        ),
      ],
    );
  }

  // ── Micro helpers ─────────────────────────────────────────

  /// Shared card shell for all input fields.
  Widget _shell({
    required Widget child,
    bool    highlighted  = false,
    Color?  color,
    Color?  borderColor,
  }) =>
      Container(
        decoration: BoxDecoration(
          color:        color ?? _kNavyMid.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
            color: borderColor ??
                (highlighted ? _kGreen.withOpacity(0.5) : _kBorder),
            width: highlighted ? 1.5 : 1.0,
          ),
        ),
        child: child,
      );

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: _kMuted, letterSpacing: 0.2,
    ),
  );

  Widget _errorBanner(String message) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color:        Colors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: Colors.red.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
        ),
      ],
    ),
  );
}