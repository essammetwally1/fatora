import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../menu/fixed_menu_sheet.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _toolbarHeight = 72;
  static const double _buttonSize = 44;
  static const double _iconSize = 22;
  static const double _buttonRadius = 14;

  final String monthLabel;
  final bool isCurrentMonth;
  final VoidCallback onOpenMonthHistory;
  final VoidCallback onShowCurrentMonth;

  const HomeAppBar({
    super.key,
    required this.monthLabel,
    required this.isCurrentMonth,
    required this.onOpenMonthHistory,
    required this.onShowCurrentMonth,
  });

  @override
  Size get preferredSize {
    return const Size.fromHeight(_toolbarHeight + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final buttonBackground = colorScheme.primary.withValues(alpha: .10);

    final buttonForeground = colorScheme.primary;

    final buttonBorder = colorScheme.primary.withValues(alpha: .16);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: _toolbarHeight,
      leadingWidth: 60,
      titleSpacing: 4,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 8),
        child: _AppBarIconButton(
          tooltip: isCurrentMonth
              ? 'سجل الفواتير الشهري'
              : 'العودة إلى الشهر الحالي',
          icon: isCurrentMonth
              ? Icons.calendar_month_rounded
              : Icons.today_rounded,
          backgroundColor: buttonBackground,
          foregroundColor: buttonForeground,
          borderColor: buttonBorder,
          onPressed: isCurrentMonth ? onOpenMonthHistory : onShowCurrentMonth,
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCurrentMonth ? 'فواتير الشهر الحالي' : 'سجل الفواتير',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
          child: _AppBarIconButton(
            tooltip: 'القائمة الثابتة',
            icon: Icons.menu_open_rounded,
            backgroundColor: buttonBackground,
            foregroundColor: buttonForeground,
            borderColor: buttonBorder,
            onPressed: () {
              FixedMenuSheet.show(context);
            },
          ),
        ),
        Selector<SettingsProvider, bool>(
          selector: (_, settings) => settings.isDark,
          builder: (context, isDark, _) {
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 8, 8),
              child: _AppBarIconButton(
                tooltip: isDark ? 'تفعيل الوضع الفاتح' : 'تفعيل الوضع الداكن',
                icon: isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                backgroundColor: buttonBackground,
                foregroundColor: buttonForeground,
                borderColor: buttonBorder,
                onPressed: () {
                  context.read<SettingsProvider>().toggleTheme();
                },
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: .55),
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  const _AppBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: HomeAppBar._buttonSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(HomeAppBar._buttonRadius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.expand(),
          icon: Icon(icon, size: HomeAppBar._iconSize),
          color: foregroundColor,
          disabledColor: foregroundColor.withValues(alpha: .35),
        ),
      ),
    );
  }
}
