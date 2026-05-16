// invoice_item_card.dart

import 'package:fatora/core/utils/formatters.dart';
import 'package:flutter/material.dart';

import '../data/models/invoice_item_model.dart';

class InvoiceItemCard extends StatelessWidget {
  final InvoiceItemModel item;

  const InvoiceItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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

              _row('العميل', item.customerName),

              _row('المنتج', item.itemName),

              _row('السعر', Formatters.formatMoney(item.price)),

              _row('ملاحظات', item.note),

              _statusRow(
                'الحالة',
                item.isPaid ? 'تم الدفع' : 'غير مدفوع',
                item.isPaid,
              ),
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

  Widget _statusRow(String title, String value, bool isPaid) {
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
              style: TextStyle(
                color: isPaid ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
