import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sync_status_badge.dart';
import '../../data/models/ticket_model.dart';

/// A card displaying the summary of a [TicketModel].
///
/// Usage:
/// ```dart
/// TicketCard(ticket: myTicket, onTap: () { ... })
/// ```
class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.ticket, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Route row ──────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.directions_bus,
                      size: 18, color: AppTheme.navyDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ticket.pointDepart}  →  ${ticket.pointArrivee}',
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        color:      AppTheme.navyDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SyncStatusBadge.fromString(ticket.statutSync),
                ],
              ),
              const SizedBox(height: 8),

              // ── Detail row ─────────────────────────────────
              Row(
                children: [
                  _chip(Icons.confirmation_number,
                      '${ticket.quantite} billet${ticket.quantite > 1 ? 's' : ''}'),
                  const SizedBox(width: 10),
                  _chip(Icons.sell, '${ticket.typeTarif}'),
                  const Spacer(),
                  Text(
                    '${ticket.montantTotal.toStringAsFixed(0)} DT',
                    style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      color:      AppTheme.goldDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Timestamp ──────────────────────────────────
              Text(
                _formatDate(ticket.dateHeure),
                style: const TextStyle(
                  fontSize: 11,
                  color:    AppTheme.greyMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.greyMid),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.greyMid),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}