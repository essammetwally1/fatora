import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/material.dart';

class HomeTotalsSection extends StatefulWidget {
  final InvoicesTotals totals;

  const HomeTotalsSection({super.key, required this.totals});

  @override
  State<HomeTotalsSection> createState() => _HomeTotalsSectionState();
}

class _HomeTotalsSectionState extends State<HomeTotalsSection> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totals = widget.totals;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isVerySmall = width < 340;
        final isSmall = width < 390;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmall ? 10 : 12,
                vertical: isVerySmall ? 9 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    colorScheme.primary,
                    Color.lerp(colorScheme.primary, Colors.black, .17)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: .18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _TotalsCollapsedHeader(
                    totals: totals,
                    expanded: _expanded,
                    isSmall: isSmall,
                    isVerySmall: isVerySmall,
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _ExpandedTotalsCards(
                        totals: totals,
                        isSmall: isSmall,
                      ),
                    ),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    firstCurve: Curves.easeOutCubic,
                    secondCurve: Curves.easeOutCubic,
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TotalsCollapsedHeader extends StatelessWidget {
  final InvoicesTotals totals;
  final bool expanded;
  final bool isSmall;
  final bool isVerySmall;

  const _TotalsCollapsedHeader({
    required this.totals,
    required this.expanded,
    required this.isSmall,
    required this.isVerySmall,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totals.collectionProgress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();

    return Row(
      children: [
        _AccurateCircleIndicator(
          progress: progress,
          percent: progressPercent,
          size: isVerySmall ? 45 : 49,
        ),
        SizedBox(width: isVerySmall ? 8 : 10),
        Expanded(
          child: _MainTotalValue(
            total: totals.total,
            invoiceCount: totals.invoiceCount,
            itemCount: totals.itemCount,
            isSmall: isSmall,
          ),
        ),
        SizedBox(width: isVerySmall ? 7 : 8),
        _ExpandButton(expanded: expanded),
      ],
    );
  }
}

class _AccurateCircleIndicator extends StatelessWidget {
  final double progress;
  final int percent;
  final double size;

  const _AccurateCircleIndicator({
    required this.progress,
    required this.percent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: safeProgress,
                strokeWidth: 4.2,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: .18),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Container(
              width: size - 14,
              height: size - 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$percent%',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainTotalValue extends StatelessWidget {
  final double total;
  final int invoiceCount;
  final int itemCount;
  final bool isSmall;

  const _MainTotalValue({
    required this.total,
    required this.invoiceCount,
    required this.itemCount,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجمالي الفواتير',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _formatMoney(total),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmall ? 20 : 23,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -.35,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _MiniBadge(
              icon: Icons.receipt_long_rounded,
              text: '$invoiceCount فاتورة',
            ),
            _MiniBadge(
              icon: Icons.inventory_2_rounded,
              text: '$itemCount عنصر',
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final bool expanded;

  const _ExpandButton({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? .5 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }
}

class _ExpandedTotalsCards extends StatelessWidget {
  final InvoicesTotals totals;
  final bool isSmall;

  const _ExpandedTotalsCards({required this.totals, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    final paidCard = _AmountCard(
      title: 'المدفوع',
      subtitle: 'تم تحصيله',
      value: _formatMoney(totals.paid),
      icon: Icons.check_circle_rounded,
    );

    final remainingCard = _AmountCard(
      title: 'المتبقي',
      subtitle: totals.hasRemaining ? 'لم يتم تحصيله' : 'لا يوجد متبقي',
      value: _formatMoney(totals.remaining),
      icon: totals.hasRemaining
          ? Icons.error_outline_rounded
          : Icons.verified_rounded,
    );

    if (isSmall) {
      return Column(
        children: [paidCard, const SizedBox(height: 8), remainingCard],
      );
    }

    return Row(
      children: [
        Expanded(child: paidCard),
        const SizedBox(width: 8),
        Expanded(child: remainingCard),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  const _AmountCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

String _formatMoney(num value) {
  final safeValue = value.isFinite ? value : 0;
  final roundedValue = safeValue.round();

  final raw = roundedValue.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < raw.length; i++) {
    final reversedIndex = raw.length - i;

    buffer.write(raw[i]);

    if (reversedIndex > 1 && reversedIndex % 3 == 1) {
      buffer.write(',');
    }
  }

  return '${buffer.toString()} ج.م';
}
