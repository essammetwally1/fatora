import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_item_model.dart';

class InvoiceItemCard extends StatelessWidget {
  final InvoiceItemModel item;

  const InvoiceItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final paidAmount = item.paidValue;
    final remainingAmount = item.remainingValue;

    final statusText = item.isPaid
        ? 'تم الدفع'
        : item.hasPartialPayment
        ? 'باقي'
        : 'غير مدفوع';

    final statusColor = item.isPaid
        ? Colors.green
        : item.hasPartialPayment
        ? Colors.orange
        : Colors.red;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row('التاريخ', Formatters.formatDate(item.date)),
              _row('العميل', item.displayCustomerName),
              _row('المنتج', item.displayItemName),
              _row('السعر', Formatters.formatMoney(item.price)),
              _row('المدفوع', Formatters.formatMoney(paidAmount)),
              _row('المتبقي', Formatters.formatMoney(remainingAmount)),
              _row('ملاحظات', item.displayNote),
              _statusRow('الحالة', statusText, statusColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title : ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _statusRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title : ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
