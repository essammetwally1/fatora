import 'package:flutter/material.dart';

import 'formatters.dart';

class UiFeedbackUtils {
  const UiFeedbackUtils._();

  /// Confirms deleting one recorded payment or return.
  ///
  /// Deleting an entry moves money, so the dialog states the paid total the
  /// invoice will be left with rather than only naming what is being removed:
  /// the consequence is the part the user needs to agree to.
  static Future<bool> showDeletePaymentEntryConfirmation({
    required BuildContext context,
    required double amount,
    required bool isReturn,
    required DateTime? occurredAt,
    required double paidTotalAfter,
  }) async {
    final label = isReturn ? 'المرتجع' : 'الدفعة';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            icon: Icon(
              Icons.delete_forever_outlined,
              color: colorScheme.error,
              size: 36,
            ),
            title: Text('تأكيد حذف $label'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: .20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label: ${Formatters.formatMoney(amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        occurredAt == null
                            ? 'بدون تاريخ مسجل'
                            : Formatters.formatPaymentDateTime(occurredAt),
                        textDirection: occurredAt == null
                            ? null
                            : TextDirection.ltr,
                        textAlign: TextAlign.start,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سيصبح إجمالي المدفوع '
                  '${Formatters.formatMoney(paidTotalAfter)}. '
                  'لا يمكن التراجع عن هذه العملية.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: Text('حذف $label'),
              ),
            ],
          ),
        );
      },
    );

    return confirmed ?? false;
  }

  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required int itemCount,
  }) async {
    if (itemCount <= 0) return false;

    final isSingleItem = itemCount == 1;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            icon: Icon(
              Icons.delete_forever_outlined,
              color: colorScheme.error,
              size: 36,
            ),
            title: Text(
              isSingleItem ? 'تأكيد حذف العنصر' : 'تأكيد حذف $itemCount عناصر',
            ),
            content: Text(
              isSingleItem
                  ? 'سيتم حذف العنصر المحدد نهائيًا. هل تريد المتابعة؟'
                  : 'سيتم حذف العناصر المحددة وعددها '
                        '$itemCount نهائيًا. هل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    return confirmed ?? false;
  }

  static Future<bool> showDeleteInvoiceConfirmation({
    required BuildContext context,
    required String invoiceTitle,
    required int itemCount,
  }) async {
    final cleanTitle = invoiceTitle.trim().isEmpty
        ? 'فاتورة بدون عنوان'
        : invoiceTitle.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            icon: Icon(
              Icons.delete_forever_outlined,
              color: colorScheme.error,
              size: 36,
            ),
            title: const Text('تأكيد حذف الفاتورة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم حذف الفاتورة التالية نهائيًا:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: .20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        itemCount == 0
                            ? 'لا تحتوي على عناصر'
                            : itemCount == 1
                            ? 'تحتوي على عنصر واحد'
                            : 'تحتوي على $itemCount عناصر',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  itemCount == 0
                      ? 'لا يمكن التراجع عن هذه العملية.'
                      : 'سيتم أيضًا حذف جميع العناصر الموجودة داخل الفاتورة. '
                            'لا يمكن التراجع عن هذه العملية.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('حذف الفاتورة'),
              ),
            ],
          ),
        );
      },
    );

    return confirmed ?? false;
  }
}
