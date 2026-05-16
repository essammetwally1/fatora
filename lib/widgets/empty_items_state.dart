import 'package:flutter/material.dart';

class EmptyItemsState extends StatelessWidget {
  final Color color;

  const EmptyItemsState({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_outlined, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              'لا توجد عناصر بعد',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'أضف اسم العميل والسعر، وباقي البيانات اختيارية وسيتم حفظ تاريخ اليوم تلقائياً.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
