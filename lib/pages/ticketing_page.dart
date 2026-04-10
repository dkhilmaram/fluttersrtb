import 'package:flutter/material.dart';
import 'NouveauticketPage.dart';
import 'passage_special_page.dart';

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
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() => _activeTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _dep =>
      widget.segment['point_depart'] ?? widget.voyage['depart'] ?? '?';
  String get _arr =>
      widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '?';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: NestedScrollView(
        // ── The header scrolls away; tab bar sticks ──
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildHeader()),
        ],
        body: Column(
          children: [
            // ── Pinned tab bar ──
            Container(
              color: cardWhite,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TabBar(
                controller: _tabCtrl,
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(colors: [navyDark, navyLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  _buildTab(Icons.confirmation_number_rounded, 'Nouveau Ticket', 0),
                  _buildTab(Icons.card_membership_rounded, 'Passage Gratuit', 1),
                ],
              ),
            ),

            // ── Tab views fill remaining space ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  NouveauTicketPage(
                    voyage: {
                      ...widget.voyage,
                      'depart':     _dep,
                      'arrivee':    _arr,
                      'id_segment': widget.segment['id_segment'],
                    },
                    embeddedMode: true,
                  ),
                  PassageSpecialPage(
                    voyage:       widget.voyage,
                    segment:      widget.segment,
                    embeddedMode: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab chip
  // ─────────────────────────────────────────────────────────────

  Widget _buildTab(IconData icon, String label, int idx) {
    final sel = _activeTab == idx;
    return Tab(
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: sel ? Colors.white : Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Scrollable header
  // ─────────────────────────────────────────────────────────────

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
      child: Column(
        children: [
          // ── Back button ──
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
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 17),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Logo ──
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
                  const Icon(Icons.directions_bus, size: 36, color: navyMid),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'S R T B',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 7,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'Billetterie — Secteur actif',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 14),

          // ── Route pill — FIX: Flexible on both station names ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: goldLight, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _dep,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward, color: Colors.white.withOpacity(0.45), size: 13),
                ),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: goldLight, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _arr,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Active badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC).withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  'SECTEUR ACTIF',
                  style: TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
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