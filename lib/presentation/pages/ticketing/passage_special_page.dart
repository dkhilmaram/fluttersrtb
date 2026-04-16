import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/ticket_repository.dart';

// ── Local palette aliases ─────────────────────────────────────
const _navyDark = AppTheme.navyDark;
const _navyMid = AppTheme.navyMid;
const _navyLight = AppTheme.navyLight;
const _goldLight = AppTheme.goldLight;
const _surface = AppTheme.offWhite;

const List<
  Map<
    String,
    dynamic
  >
>
kCategories = [
  {
    'label': 'Armée nationale',
    'icon': Icons.shield_rounded,
    'color': Color(
      0xFF1E40AF,
    ),
  },
  {
    'label': 'Garde nationale',
    'icon': Icons.security_rounded,
    'color': Color(
      0xFF1D4ED8,
    ),
  },
  {
    'label': 'Police nationale',
    'icon': Icons.local_police_rounded,
    'color': Color(
      0xFF1E3A5F,
    ),
  },
  {
    'label': 'Douane',
    'icon': Icons.account_balance_rounded,
    'color': Color(
      0xFF374151,
    ),
  },
  {
    'label': 'Ministère',
    'icon': Icons.domain_rounded,
    'color': Color(
      0xFF6B21A8,
    ),
  },
  {
    'label': 'Municipalité',
    'icon': Icons.location_city_rounded,
    'color': Color(
      0xFF065F46,
    ),
  },
  {
    'label': 'Établissement scolaire',
    'icon': Icons.school_rounded,
    'color': Color(
      0xFFB45309,
    ),
  },
  {
    'label': 'Autre institution',
    'icon': Icons.groups_rounded,
    'color': Color(
      0xFF9D174D,
    ),
  },
  {
    'label': 'Abonnement',
    'icon': Icons.confirmation_number_rounded,
    'color': Color(
      0xFF0369A1,
    ),
  },
  {
    'label': 'Agent',
    'icon': Icons.badge_rounded,
    'color': Color(
      0xFF7C3AED,
    ),
  },
];

class PassageSpecialPage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  voyage;
  final Map<
    String,
    dynamic
  >
  segment;
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
  State<
    PassageSpecialPage
  >
  createState() => _PassageSpecialPageState();
}

class _PassageSpecialPageState
    extends
        State<
          PassageSpecialPage
        > {
  String? selectedCategory;
  int quantite = 1;
  bool isSaving = false;
  int totalEnregistres = 0;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    super.dispose();
  }

  // ── Toast ─────────────────────────────────────────────────

  void _showToast(
    String msg, {
    bool isError = false,
    bool isWarning = false,
  }) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
        ? Colors.orange.shade700
        : const Color(
            0xFF16A34A,
          );
    final icon = isError
        ? Icons.error_outline
        : isWarning
        ? Icons.offline_bolt
        : Icons.check_circle_outline;

    final entry = OverlayEntry(
      builder:
          (
            _,
          ) => _ToastWidget(
            msg: msg,
            color: color,
            icon: icon,
          ),
    );
    _toastEntry = entry;
    Overlay.of(
      context,
    ).insert(
      entry,
    );
    _toastTimer = Timer(
      const Duration(
        milliseconds: 2500,
      ),
      () {
        entry.remove();
        if (_toastEntry ==
            entry)
          _toastEntry = null;
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  bool get _canSave =>
      selectedCategory !=
      null;

  String _buildTypeTarif(
    String category,
  ) {
    if (category ==
            'Agent' ||
        category ==
            'Abonnement')
      return category;
    return 'Gratuit — $category';
  }

  // ── Save ──────────────────────────────────────────────────

  Future<
    void
  >
  _enregistrer() async {
    if (!_canSave) return;
    setState(
      () => isSaving = true,
    );

    final result = await TicketRepository.saveTicket(
      {
        'id_voyage':
            widget.voyage['id']
                as int? ??
            0,
        'id_segment':
            widget.segment['id_segment']
                as int? ??
            0,
        'point_depart':
            widget.segment['point_depart'] ??
            widget.voyage['depart'] ??
            '',
        'point_arrivee':
            widget.segment['point_arrivee'] ??
            widget.voyage['arrivee'] ??
            '',
        'type_tarif': _buildTypeTarif(
          selectedCategory!,
        ),
        'quantite': quantite,
        'prix_unitaire': 0,
        'montant_total': 0,
        'matricule_agent':
            widget.voyage['matricule_agent'] ??
            0,
      },
    );

    if (result.success) {
      final saved = quantite;
      setState(
        () {
          totalEnregistres += saved;
          selectedCategory = null;
          quantite = 1;
        },
      );
      _showToast(
        '$saved passage(s) enregistré(s)',
      );

      if (widget.embeddedMode &&
          widget.onPassageSaved !=
              null) {
        await Future.delayed(
          const Duration(
            milliseconds: 600,
          ),
        );
        if (mounted) widget.onPassageSaved!.call();
      }
    } else {
      _showToast(
        'Erreur : ${result.error ?? "inconnue"}',
        isError: true,
      );
    }

    if (mounted)
      setState(
        () => isSaving = false,
      );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(
    BuildContext context,
  ) {
    final dep =
        widget.segment['point_depart'] ??
        widget.voyage['depart'] ??
        '?';
    final arr =
        widget.segment['point_arrivee'] ??
        widget.voyage['arrivee'] ??
        '?';

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalEnregistres >
              0)
            _SessionBanner(
              icon: Icons.how_to_reg_rounded,
              text: '$totalEnregistres passage(s) enregistré(s) cette session',
            ),

          _SectionLabel(
            'Institution / Agence',
            Icons.domain_rounded,
          ),
          const SizedBox(
            height: 10,
          ),
          _CategoryGrid(
            items: kCategories
                .where(
                  (
                    c,
                  ) =>
                      !(c['label']
                              as String)
                          .startsWith(
                            RegExp(
                              r'Abonnement|Agent',
                            ),
                          ),
                )
                .toList(),
            selected: selectedCategory,
            onSelect:
                (
                  v,
                ) => setState(
                  () => selectedCategory = v,
                ),
          ),
          const SizedBox(
            height: 24,
          ),

          _SectionLabel(
            'Type spécial',
            Icons.confirmation_number_rounded,
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Expanded(
                child: _CategoryButton(
                  item: {
                    'label': 'Abonnement',
                    'icon': Icons.confirmation_number_rounded,
                    'color': const Color(
                      0xFF0369A1,
                    ),
                  },
                  selected:
                      selectedCategory ==
                      'Abonnement',
                  onTap: () => setState(
                    () => selectedCategory = 'Abonnement',
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _CategoryButton(
                  item: {
                    'label': 'Agent',
                    'icon': Icons.badge_rounded,
                    'color': const Color(
                      0xFF7C3AED,
                    ),
                  },
                  selected:
                      selectedCategory ==
                      'Agent',
                  onTap: () => setState(
                    () => selectedCategory = 'Agent',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 24,
          ),

          _SectionLabel(
            'Nombre de personnes',
            Icons.people_rounded,
          ),
          const SizedBox(
            height: 10,
          ),
          _QuantiteCard(
            quantite: quantite,
            onDec:
                quantite >
                    1
                ? () => setState(
                    () => quantite--,
                  )
                : null,
            onInc: () => setState(
              () => quantite++,
            ),
          ),
          const SizedBox(
            height: 16,
          ),

          if (_canSave) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                14,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFEFF3FF,
                ),
                borderRadius: BorderRadius.circular(
                  12,
                ),
                border: Border.all(
                  color: const Color(
                    0xFFB8C8F0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _navyMid,
                    size: 16,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      '$quantite personne(s) · '
                      '${_buildTypeTarif(selectedCategory!)}',
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
            const SizedBox(
              height: 16,
            ),
          ],

          _BigBtn(
            label: isSaving
                ? 'Enregistrement...'
                : 'Enregistrer le passage',
            icon: Icons.how_to_reg_rounded,
            isLoading: isSaving,
            enabled:
                _canSave &&
                !isSaving,
            colors: const [
              Color(
                0xFF065F46,
              ),
              Color(
                0xFF059669,
              ),
            ],
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
          _buildHeader(
            dep,
            arr,
          ),
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    String dep,
    String arr,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _navyDark,
            _navyMid,
            _navyLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        52,
        20,
        24,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(
                context,
              ),
              child: Container(
                padding: const EdgeInsets.all(
                  8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                16,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    0.25,
                  ),
                  blurRadius: 14,
                  offset: const Offset(
                    0,
                    5,
                  ),
                ),
              ],
            ),
            padding: const EdgeInsets.all(
              8,
            ),
            child: Image.asset(
              'assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder:
                  (
                    _,
                    __,
                    ___,
                  ) => const Icon(
                    Icons.directions_bus,
                    size: 36,
                    color: _navyMid,
                  ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'S R T B',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            'Passages Gratuits & Spéciaux',
            style: TextStyle(
              color: Colors.white.withOpacity(
                0.7,
              ),
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(
                30,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(
                  0.2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _goldLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Flexible(
                  child: Text(
                    dep,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white.withOpacity(
                      0.4,
                    ),
                    size: 12,
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _goldLight,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Flexible(
                  child: Text(
                    arr,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _SessionBanner
    extends
        StatelessWidget {
  final IconData icon;
  final String text;
  const _SessionBanner({
    required this.icon,
    required this.text,
  });

  @override
  Widget
  build(
    BuildContext context,
  ) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(
      bottom: 18,
    ),
    padding: const EdgeInsets.symmetric(
      vertical: 12,
      horizontal: 16,
    ),
    decoration: BoxDecoration(
      color: const Color(
        0xFFDCFCE7,
      ),
      borderRadius: BorderRadius.circular(
        12,
      ),
      border: Border.all(
        color: const Color(
          0xFF86EFAC,
        ),
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: const Color(
            0xFF16A34A,
          ),
          size: 18,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(
                0xFF15803D,
              ),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel
    extends
        StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(
    this.text,
    this.icon,
  );

  @override
  Widget
  build(
    BuildContext context,
  ) => Row(
    children: [
      Icon(
        icon,
        size: 13,
        color: _navyMid.withOpacity(
          0.6,
        ),
      ),
      const SizedBox(
        width: 7,
      ),
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

class _CategoryGrid
    extends
        StatelessWidget {
  final List<
    Map<
      String,
      dynamic
    >
  >
  items;
  final String? selected;
  final ValueChanged<
    String
  >
  onSelect;
  const _CategoryGrid({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget
  build(
    BuildContext context,
  ) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
    ),
    itemBuilder:
        (
          _,
          i,
        ) => _CategoryButton(
          item: items[i],
          selected:
              selected ==
              items[i]['label'],
          onTap: () => onSelect(
            items[i]['label']
                as String,
          ),
        ),
  );
}

class _CategoryButton
    extends
        StatelessWidget {
  final Map<
    String,
    dynamic
  >
  item;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final color =
        item['color']
            as Color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color
              : Colors.white,
          borderRadius: BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color: selected
                ? color
                : Colors.grey.shade200,
            width: selected
                ? 0
                : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(
                      0.3,
                    ),
                    blurRadius: 8,
                    offset: const Offset(
                      0,
                      3,
                    ),
                  ),
                ]
              : [
                  BoxShadow(
                    color: _navyMid.withOpacity(
                      0.05,
                    ),
                    blurRadius: 6,
                    offset: const Offset(
                      0,
                      2,
                    ),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              item['icon']
                  as IconData,
              size: 16,
              color: selected
                  ? Colors.white
                  : color,
            ),
            const SizedBox(
              width: 7,
            ),
            Expanded(
              child: Text(
                item['label']
                    as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : _navyDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantiteCard
    extends
        StatelessWidget {
  final int quantite;
  final VoidCallback? onDec;
  final VoidCallback onInc;
  const _QuantiteCard({
    required this.quantite,
    this.onDec,
    required this.onInc,
  });

  @override
  Widget
  build(
    BuildContext context,
  ) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(
        14,
      ),
      boxShadow: [
        BoxShadow(
          color: _navyMid.withOpacity(
            0.06,
          ),
          blurRadius: 10,
          offset: const Offset(
            0,
            3,
          ),
        ),
      ],
    ),
    child: Row(
      children: [
        _QtyBtn(
          icon: Icons.remove,
          enabled:
              onDec !=
              null,
          onTap:
              onDec ??
              () {},
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '$quantite',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _navyDark,
                ),
              ),
              Text(
                quantite ==
                        1
                    ? 'personne'
                    : 'personnes',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        _QtyBtn(
          icon: Icons.add,
          enabled: true,
          onTap: onInc,
        ),
      ],
    ),
  );
}

class _QtyBtn
    extends
        StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget
  build(
    BuildContext context,
  ) => GestureDetector(
    onTap: enabled
        ? onTap
        : null,
    child: AnimatedContainer(
      duration: const Duration(
        milliseconds: 150,
      ),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: enabled
            ? _navyMid
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(
          12,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _navyMid.withOpacity(
                    0.3,
                  ),
                  blurRadius: 6,
                  offset: const Offset(
                    0,
                    2,
                  ),
                ),
              ]
            : [],
      ),
      child: Icon(
        icon,
        color: enabled
            ? Colors.white
            : Colors.grey.shade300,
        size: 18,
      ),
    ),
  );
}

class _BigBtn
    extends
        StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading, enabled;
  final List<
    Color
  >
  colors;
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
  Widget
  build(
    BuildContext context,
  ) => SizedBox(
    width: double.infinity,
    height: 54,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(
        14,
      ),
      child: InkWell(
        onTap: enabled
            ? onTap
            : null,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled
                ? null
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(
              14,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.first.withOpacity(
                        0.35,
                      ),
                      blurRadius: 12,
                      offset: const Offset(
                        0,
                        4,
                      ),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  icon,
                  color: enabled
                      ? Colors.white
                      : Colors.grey.shade400,
                  size: 20,
                ),
              const SizedBox(
                width: 8,
              ),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: enabled
                        ? Colors.white
                        : Colors.grey.shade400,
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

// ── Toast widget ──────────────────────────────────────────────

class _ToastWidget
    extends
        StatefulWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _ToastWidget({
    required this.msg,
    required this.color,
    required this.icon,
  });

  @override
  State<
    _ToastWidget
  >
  createState() => _ToastWidgetState();
}

class _ToastWidgetState
    extends
        State<
          _ToastWidget
        >
    with
        SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<
    double
  >
  _opacity;
  late final Animation<
    Offset
  >
  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 220,
      ),
    );
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    );
    _slide =
        Tween<
              Offset
            >(
              begin: const Offset(
                1.0,
                0,
              ),
              end: Offset.zero,
            )
            .animate(
              CurvedAnimation(
                parent: _ctrl,
                curve: Curves.easeOut,
              ),
            );
    _ctrl.forward();
    Future.delayed(
      const Duration(
        milliseconds: 2100,
      ),
      () {
        if (mounted) _ctrl.reverse();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget
  build(
    BuildContext context,
  ) => Positioned(
    top:
        MediaQuery.of(
          context,
        ).padding.top +
        16,
    right: 16,
    child: FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 300,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(
                12,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(
                    0.35,
                  ),
                  blurRadius: 16,
                  offset: const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(
                  width: 8,
                ),
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
