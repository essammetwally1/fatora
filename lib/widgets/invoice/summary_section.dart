// import 'package:flutter/material.dart';

// import '../../data/models/invoice_model.dart';

// class SummarySection extends StatelessWidget {
//   final InvoiceModel invoice;

//   const SummarySection({super.key, required this.invoice});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             _summaryRow('اجمالي الفاتوره', invoice.total),
//             _summaryRow('المدفوع', invoice.paidTotal),
//             _summaryRow('الباقي', invoice.unpaidTotal),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _summaryRow(String title, double value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         children: [
//           Expanded(
//             child: Text(
//               title,
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//           Text('$value ج.م'),
//         ],
//       ),
//     );
//   }
// }
