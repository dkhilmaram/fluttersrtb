import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/ticket_repository.dart';
import '../../../l10n/app_localizations.dart';
// Add import
import '../../widgets/offline_toast_notification.dart';

// ── Local palette aliases ─────────────────────────────────────
const _navyDark  = AppTheme.navyDark;
const _navyMid   = AppTheme.navyMid;
const _navyLight = AppTheme.navyLight;
const _goldLight = AppTheme.goldLight;
const _surface   = AppTheme.offWhite;

// ── Category definitions (stable keys, no labels) ─────────────
const List<Map<String, dynamic>> kCategoryDefs = [
  {'key': 'armee_nationale',       'icon': Icons.shield_rounded,              'color': Color(0xFF1E40AF)},
  {'key': 'garde_nationale',       'icon': Icons.security_rounded,            'color': Color(0xFF1D4ED8)},
  {'key': 'police_nationale',      'icon': Icons.local_police_rounded,        'color': Color(0xFF1E3A5F)},
  {'key': 'douane',                'icon': Icons.account_balance_rounded,     'color': Color(0xFF374151)},
  {'key': 'ministere',             'icon': Icons.domain_rounded,              'color': Color(0xFF6B21A8)},
  {'key': 'municipalite',          'icon': Icons.location_city_rounded,       'color': Color(0xFF065F46)},
  {'key': 'etablissement_scolaire','icon': Icons.school_rounded,              'color': Color(0xFFB45309)},
  {'key': 'autre_institution',     'icon': Icons.groups_rounded,              'color': Color(0xFF9D174D)},
  {'key': 'abonnement',            'icon': Icons.confirmation_number_rounded, 'color': Color(0xFF0369A1)},
  {'key': 'agent',                 'icon': Icons.badge_rounded,               'color': Color(0xFF7C3AED)},
];

// ── Helpers ───────────────────────────────────────────────────

String categoryLabel(AppLocalizations t, String key) {
  switch (key) {
    case 'armee_nationale':        return t.categorieArmeeNationale;
    case 'garde_nationale':        return t.categorieGardeNationale;
    case 'police_nationale':       return t.categoriePoliceNationale;
    case 'douane':                 return t.categorieDouane;
    case 'ministere':              return t.categorieMinistere;
    case 'municipalite':           return t.categorieMunicipalite;
    case 'etablissement_scolaire': return t.categorieEtablissementScolaire;
    case 'autre_institution':      return t.categorieAutreInstitution;
    case 'abonnement':             return t.categorieAbonnement;
    case 'agent':                  return t.categorieAgent;
    default:                       return key;
  }
}

String buildTypeTarif(String key) {
  if (key == 'agent')       return 'Agent';
  if (key == 'abonnement')  return 'Abonnement';
  const frenchNames = {
    'armee_nationale':        'Armée nationale',
    'garde_nationale':        'Garde nationale',
    'police_nationale':       'Police nationale',
    'douane':                 'Douane',
    'ministere':              'Ministère',
    'municipalite':           'Municipalité',
    'etablissement_scolaire': 'Établissement scolaire',
    'autre_institution':      'Autre institution',
  };
  return 'Gratuit — ${frenchNames[key] ?? key}';
}

// ─────────────────────────────────────────────────────────────
class PassageSpecialPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final Map<String, dynamic> segment;
  final bool embeddedMode;
  final VoidCallback? onPassageSaved;

  const PassageSpecialPage({
    super.key,
    required this.voyage,
    required this.segment,
    this.embeddedMode = false,
    this.onPassageSaved,
  });

  @override
  State<PassageSpecialPage> createState() => _PassageSpecialPageState();
}

class _PassageSpecialPageState extends State<PassageSpecialPage> {
  String? selectedKey;
  static const int quantite = 1; // fixed at 1, no UI picker
  bool isSaving         = false;
  int totalEnregistres  = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    super.dispose();
  }

  // ── Toast ─────────────────────────────────────────────────

  void _showToast(String msg, {bool isError = false, bool isWarning = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
            ? Colors.orange.shade700
            : const Color(0xFF16A34A);
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.offline_bolt
            : Icons.check_circle_outline;

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(msg: msg, color: color, icon: icon),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  // ── Save ──────────────────────────────────────────────────

  Future<void> _enregistrer() async {
    if (selectedKey == null) return;
    final t = AppLocalizations.of(context)!;
    setState(() => isSaving = true);

    final result = await TicketRepository.saveTicket({
      'id_voyage':       widget.voyage['id'] as int? ?? 0,
      'id_segment':      0,
      'point_depart':    widget.segment['point_depart'] ?? widget.voyage['depart'] ?? '',
      'point_arrivee':   widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '',
      'type_tarif':      buildTypeTarif(selectedKey!),
      'quantite':        quantite,
      'prix_unitaire':   0,
      'montant_total':   0,
      'matricule_agent': widget.voyage['matricule_agent'] ?? 0,
    });

    if (result.success) {
      setState(() {
        totalEnregistres += quantite;
        selectedKey = null;
      });

      if (result.wasOffline) {
        OfflineToastNotification.show(context);
      } else {
        _showToast(t.passagesToast(quantite));
      }

      if (widget.embeddedMode && widget.onPassageSaved != null) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) widget.onPassageSaved!.call();
      }
    } else {
      _showToast(
        t.erreurPassage(result.error ?? t.erreurInconnue),
        isError: true,
      );
    }

    if (mounted) setState(() => isSaving = false);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final dep = widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '?';
    final arr = widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '?';

    final allCategories = kCategoryDefs.map((def) => {
      ...def,
      'label': categoryLabel(t, def['key'] as String),
    }).toList();

    final institutionCategories =
        allCategories.where((c) => c['key'] != 'abonnement' && c['key'] != 'agent').toList();

    final abonnementDef = allCategories.firstWhere((c) => c['key'] == 'abonnement');
    final agentDef      = allCategories.firstWhere((c) => c['key'] == 'agent');

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Session banner
          if (totalEnregistres > 0)
            _SessionBanner(
              icon: Icons.how_to_reg_rounded,
              text: t.passagesSession(totalEnregistres),
            ),

          // ── Institution grid
          _SectionLabel(t.institutionAgence, Icons.domain_rounded),
          const SizedBox(height: 10),
          _CategoryGrid(
            items: institutionCategories,
            selected: selectedKey,
            onSelect: (key) => setState(() => selectedKey = key),
          ),
          const SizedBox(height: 24),

          // ── Special types
          _SectionLabel(t.typeSpecial, Icons.confirmation_number_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CategoryButton(
                  item: abonnementDef,
                  selected: selectedKey == 'abonnement',
                  onTap: () => setState(() => selectedKey = 'abonnement'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CategoryButton(
                  item: agentDef,
                  selected: selectedKey == 'agent',
                  onTap: () => setState(() => selectedKey = 'agent'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Summary
          if (selectedKey != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB8C8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: _navyMid, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.resumePassage(quantite, categoryLabel(t, selectedKey!)),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _navyMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Save button
          _BigBtn(
            label: isSaving ? t.enregistrementEnCours : t.enregistrerLePassage,
            icon: Icons.how_to_reg_rounded,
            isLoading: isSaving,
            enabled: selectedKey != null && !isSaving,
            colors: const [Color(0xFF065F46), Color(0xFF059669)],
            onTap: _enregistrer,
          ),
        ],
      ),
    );

    if (widget.embeddedMode) return content;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(t, dep, arr),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations t, String dep, String arr) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navyDark, _navyMid, _navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 17),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.directions_bus, size: 36, color: _navyMid),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.srtbLetters,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            t.passagesGratuitsSpeciaux,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: _goldLight, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    dep,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      color: Colors.white.withOpacity(0.4), size: 12),
                ),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _goldLight, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    arr,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────

class _SessionBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SessionBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF16A34A), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: _navyMid.withOpacity(0.6)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navyDark,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      );
}

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
        ),
        itemBuilder: (_, i) => _CategoryButton(
          item: items[i],
          selected: selected == items[i]['key'],
          onTap: () => onSelect(items[i]['key'] as String),
        ),
      );
}

class _CategoryButton extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = item['color'] as Color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 0 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: _navyMid.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(
              item['icon'] as IconData,
              size: 16,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                item['label'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _navyDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading, enabled;
  final List<Color> colors;
  final VoidCallback onTap;
  const _BigBtn({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.enabled,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled
                    ? LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: enabled ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
                boxShadow: enabled
                    ? [BoxShadow(color: colors.first.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  else
                    Icon(icon, color: enabled ? Colors.white : Colors.grey.shade400, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                        color: enabled ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Toast ─────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _ToastWidget({required this.msg, required this.color, required this.icon});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        right: 16,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 16),
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
      );
}