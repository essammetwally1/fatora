import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  final Color color;

  const HomeEmptyState({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              'لا توجد فواتير حتى الآن',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على زر “فاتورة جديدة” لإنشاء فاتورة بقيمة ابتدائية 0 ج.م.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
