import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';
import 'total_box.dart';

class TotalsHeader extends StatelessWidget {
  final InvoiceModel invoice;

  const TotalsHeader({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: .78),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TotalBox(
              title: 'الإجمالي',
              value: Formatters.formatMoney(invoice.total),
              icon: Icons.receipt_long,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TotalBox(
              title: 'المدفوع',
              value: Formatters.formatMoney(invoice.paidTotal),
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TotalBox(
              title: 'المتبقي',
              value: Formatters.formatMoney(invoice.unpaidTotal),
              icon: Icons.pending_actions_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
