import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import 'decorative_circle.dart';
import 'mini_stat_card.dart';

class HomeTotalsSection extends StatelessWidget {
  final InvoicesTotals totals;

  const HomeTotalsSection({super.key, required this.totals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: .82),
            colorScheme.secondary.withValues(alpha: .72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            top: -24,
            child: DecorativeCircle(
              size: 76,
              color: Colors.white.withValues(alpha: .10),
            ),
          ),
          Positioned(
            right: -24,
            bottom: -34,
            child: DecorativeCircle(
              size: 92,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TotalsHeader(),
              const SizedBox(height: 12),
              Text(
                Formatters.formatMoney(totals.total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MiniStatCard(
                      title: 'الفواتير',
                      value: '${totals.invoiceCount}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MiniStatCard(
                      title: 'العناصر',
                      value: '${totals.itemCount}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إجمالي كل الفواتير',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'مجموع أسعار كل العناصر',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .78),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
