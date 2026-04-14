import 'package:flutter/material.dart';
import 'NouveauticketPage.dart';
import 'passage_special_page.dart';
import 'scan_tab_page.dart';

const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

class TicketingPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final Map<String, dynamic> segment;

  const TicketingPage({
    super.key,
    required this.voyage,
    required this.segment,
  });

  @override
  State<TicketingPage> createState() => _TicketingPageState();
}

class _TicketingPageState extends State<TicketingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int  _activeTab       = 0;
  bool _gratuitUnlocked = false;
  int  _gratuitKey      = 0;

  // GlobalKey lets us call resetAfterGratuit() directly on the
  // NouveauTicketPage state after a gratuit passage is saved.
  final GlobalKey<NouveauTicketPageState> _nouveauKey =
      GlobalKey<NouveauTicketPageState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      // Block direct swipe/tap to the gratuit tab if not unlocked
      if (_tabCtrl.index == 1 && !_gratuitUnlocked) {
        _tabCtrl.animateTo(_activeTab);
        return;
      }
      setState(() => _activeTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Called by NouveauTicketPage when the user taps "Passage Gratuit / Spécial"
  void _switchToGratuitTab() {
    setState(() {
      _gratuitUnlocked = true;
      _activeTab       = 1;
    });
    _tabCtrl.animateTo(1);
  }

  // Called by NouveauTicketPage after a normal ticket is sold
  void _onTicketSold() {
    setState(() {
      _gratuitUnlocked = false;
      _gratuitKey++;
      _activeTab = 0;
    });
    _tabCtrl.animateTo(0);
  }

  // Called by PassageSpecialPage after a gratuit passage is saved:
  //   1. Tell NouveauTicketPage to keep pointDepart but reset pointArrivee + quantite
  //   2. Switch back to tab 0
  //   3. Reset gratuit lock so the flow is clean for the next stop
  void _onPassageSaved() {
    // Reset NouveauTicketPage state via GlobalKey — mirrors _saveTicket behaviour
    _nouveauKey.currentState?.resetAfterGratuit();

    setState(() {
      _gratuitUnlocked = false;
      _gratuitKey++;
      _activeTab = 0;
    });
    _tabCtrl.animateTo(0);
  }

  String get _dep =>
      widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '?';
  String get _arr =>
      widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '?';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(children: [
        // Fixed header
        _buildHeader(),

        // Pinned tab bar
        Container(
          color: cardWhite,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TabBar(
            controller: _tabCtrl,
            labelPadding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [navyDark, navyLight]),
              borderRadius: BorderRadius.circular(10),
            ),
            dividerColor: Colors.transparent,
            tabs: [
              _buildTab(Icons.confirmation_number_rounded,
                  'Nouveau Ticket', 0),
              _buildTab(
                  _gratuitUnlocked
                      ? Icons.card_membership_rounded
                      : Icons.lock_rounded,
                  'Passage Gratuit', 1,
                  locked: !_gratuitUnlocked),
              _buildTab(Icons.qr_code_scanner_rounded, 'NFC / Scan', 2),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Tab 0 — Nouveau Ticket
              // GlobalKey wires us to resetAfterGratuit()
              NouveauTicketPage(
                key:           _nouveauKey,
                voyage: {
                  ...widget.voyage,
                  'depart':     _dep,
                  'arrivee':    _arr,
                  'id_segment': widget.segment['id_segment'],
                },
                embeddedMode:  true,
                onOpenGratuit: _switchToGratuitTab,
                onTicketSold:  _onTicketSold,
              ),

              // Tab 1 — Passage Gratuit / Spécial
              _gratuitUnlocked
                  ? PassageSpecialPage(
                      key:            ValueKey(_gratuitKey),
                      voyage:         widget.voyage,
                      segment:        widget.segment,
                      embeddedMode:   true,
                      onPassageSaved: _onPassageSaved, // ← new callback
                    )
                  : const _LockedTabPlaceholder(),

              // Tab 2 — NFC / Scan
              ScanTabPage(
                voyage:  widget.voyage,
                segment: widget.segment,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Tab chip ───────────────────────────────────────────────

  Widget _buildTab(IconData icon, String label, int idx,
      {bool locked = false}) {
    final sel = _activeTab == idx;
    return Tab(
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: locked
                    ? Colors.grey.shade300
                    : sel
                        ? Colors.white
                        : Colors.grey.shade400),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: locked
                          ? Colors.grey.shade300
                          : sel
                              ? Colors.white
                              : Colors.grey.shade400)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navyDark, navyMid, navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(children: [
        Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 17),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 5))],
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.directions_bus,
                      size: 36, color: navyMid)),
        ),
        const SizedBox(height: 10),
        const Text('S R T B',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 7)),
        const SizedBox(height: 3),
        Text('Billetterie — Secteur actif',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                letterSpacing: 1.5)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: goldLight, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_dep,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward,
                  color: Colors.white.withOpacity(0.45), size: 13),
            ),
            Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: goldLight, width: 2))),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_arr,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF86EFAC).withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('SECTEUR ACTIF',
                style: TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
          ]),
        ),
      ]),
    );
  }
}

// ── Locked placeholder ─────────────────────────────────────────

class _LockedTabPlaceholder extends StatelessWidget {
  const _LockedTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.lock_rounded,
                size: 34, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 18),
          Text('Accès verrouillé',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Sélectionnez montée & descente dans\n'
              '"Nouveau Ticket" puis appuyez sur\n'
              '"Passage Gratuit / Spécial"',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}