import 'invoice_model.dart';

/// One line of an invoice's payment breakdown, ready to display.
///
/// Both the printed receipt and the in-app history render this, so the two can
/// never disagree about what was paid, when, or how the numbers add up.
class InvoicePaymentLine {
  /// Magnitude of the movement. Never negative; [isReturn] carries direction.
  final double amount;

  final bool isReturn;

  /// When it happened, or null for money that predates payment history.
  final DateTime? occurredAt;

  /// True for the synthetic line covering a balance no stored entry explains.
  final bool isOpening;

  const InvoicePaymentLine({
    required this.amount,
    required this.isReturn,
    required this.occurredAt,
    this.isOpening = false,
  });

  double get signedAmount => isReturn ? -amount : amount;

  String get labelAr {
    if (isOpening) {
      return isReturn ? 'تسوية مسجلة مسبقًا' : 'دفعة مسجلة مسبقًا';
    }

    return isReturn ? 'مرتجع' : 'دفعة';
  }

  /// Flattens an invoice's stored history into printable/displayable lines.
  ///
  /// Invoices paid before payment history existed carry a balance that no
  /// entry accounts for. It becomes a dateless opening line rather than being
  /// dropped — which would make the breakdown disagree with the stored total —
  /// or stamped with a date nobody ever recorded. The same line, with the
  /// opposite sign, absorbs any downward adjustment of the paid total, so the
  /// lines always sum to [InvoiceModel.paidTotal].
  ///
  /// Returns an empty list when nothing has been paid: an all-zero breakdown
  /// on an unpaid invoice is noise.
  static List<InvoicePaymentLine> fromInvoice(InvoiceModel invoice) {
    final lines = <InvoicePaymentLine>[];

    final unrecorded = invoice.unrecordedPaidAmount;

    if (unrecorded != 0) {
      lines.add(
        InvoicePaymentLine(
          amount: unrecorded.abs(),
          isReturn: unrecorded < 0,
          occurredAt: null,
          isOpening: true,
        ),
      );
    }

    for (final entry in invoice.paymentsOldestFirst) {
      if (entry.amount <= 0) continue;

      lines.add(
        InvoicePaymentLine(
          amount: entry.amount,
          isReturn: entry.isReturn,
          occurredAt: entry.createdAt,
        ),
      );
    }

    return List<InvoicePaymentLine>.unmodifiable(lines);
  }

  static double sumOf(Iterable<InvoicePaymentLine> lines) {
    var value = 0.0;

    for (final line in lines) {
      value += line.amount;
    }

    return value;
  }
}
