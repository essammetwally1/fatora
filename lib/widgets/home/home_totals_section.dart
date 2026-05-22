import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../core/utils/formatters.dart';
import 'decorative_circle.dart';
import 'mini_stat_card.dart';

class HomeTotalsSection extends StatelessWidget {
  final InvoicesTotals totals;

  const HomeTotalsSection({super.key, required this.totals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    final isSmallPhone = width < 360;

    return Container(
      padding: EdgeInsets.all(isSmallPhone ? 10 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary.withValues(alpha: .86),
            colorScheme.primary.withValues(alpha: .92),
            colorScheme.primary.withValues(alpha: .68),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: .14),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            top: -24,
            child: DecorativeCircle(
              size: isSmallPhone ? 56 : 64,
              color: Colors.white.withValues(alpha: .10),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -28,
            child: DecorativeCircle(
              size: isSmallPhone ? 70 : 78,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TotalsHeader(),

              SizedBox(height: isSmallPhone ? 7 : 9),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _ResponsiveMoneyText(
                      value: Formatters.formatMoney(totals.total),
                      maxFontSize: isSmallPhone ? 18 : 20,
                      minFontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ProgressBadge(progress: totals.collectionProgress),
                ],
              ),

              SizedBox(height: isSmallPhone ? 7 : 9),

              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: totals.collectionProgress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),

              SizedBox(height: isSmallPhone ? 7 : 9),

              LayoutBuilder(
                builder: (context, constraints) {
                  final useVerticalCards = constraints.maxWidth < 330;

                  if (useVerticalCards) {
                    return Column(
                      children: [
                        MiniStatCard(
                          title: 'المدفوع',
                          value: Formatters.formatMoney(totals.paid),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        const SizedBox(height: 6),
                        MiniStatCard(
                          title: 'المتبقي',
                          value: Formatters.formatMoney(totals.remaining),
                          icon: Icons.error_outline_rounded,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: MiniStatCard(
                          title: 'المدفوع',
                          value: Formatters.formatMoney(totals.paid),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: MiniStatCard(
                          title: 'المتبقي',
                          value: Formatters.formatMoney(totals.remaining),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),

              SizedBox(height: isSmallPhone ? 6 : 7),

              Row(
                children: [
                  Expanded(
                    child: MiniStatCard(
                      title: 'الفواتير',
                      value: '${totals.invoiceCount}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: MiniStatCard(
                      title: 'العناصر',
                      value: '${totals.itemCount}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/wallet.svg',
              width: 21,
              height: 21,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'ملخص كل الفواتير',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final double progress;

  const _ProgressBadge({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ResponsiveMoneyText extends StatelessWidget {
  final String value;
  final double maxFontSize;
  final double minFontSize;
  final Color color;

  const _ResponsiveMoneyText({
    required this.value,
    required this.maxFontSize,
    required this.minFontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: maxFontSize,
                height: 1,
              ),
            ),
          ),
        );
      },
    );
  }
}
