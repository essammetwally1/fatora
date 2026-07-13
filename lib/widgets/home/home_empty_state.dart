import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  final Color color;
  final String title;
  final String message;

  const HomeEmptyState({
    super.key,
    required this.color,
    this.title = 'لا توجد فواتير في هذا الشهر',
    this.message = 'اضغط على زر “فاتورة جديدة” لإنشاء فاتورة لهذا الشهر.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
