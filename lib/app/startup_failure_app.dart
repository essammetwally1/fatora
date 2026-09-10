import 'package:flutter/material.dart';

import '../data/services/storage/hive_service.dart';
import 'app_theme.dart';

/// Shown when local storage could not be opened at launch.
///
/// The invoices live only on this device, so a failure to open the database is
/// the worst thing that can happen to the user. Crashing to a black screen
/// tells them nothing and hides whether their data is gone; this says what
/// failed, offers a retry, and gives them the error text to pass on when they
/// ask for help.
class StartupFailureApp extends StatefulWidget {
  final Object error;

  const StartupFailureApp({super.key, required this.error});

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  late Object _error = widget.error;

  bool _isRetrying = false;
  bool _recovered = false;

  Future<void> _retry() async {
    if (_isRetrying) return;

    setState(() => _isRetrying = true);

    try {
      await HiveService.init();

      if (!mounted) return;

      setState(() => _recovered = true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fatora',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _recovered
                      ? const _RecoveredCard()
                      : _FailureCard(
                          error: _error,
                          isRetrying: _isRetrying,
                          onRetry: _retry,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  final Object error;
  final bool isRetrying;
  final VoidCallback onRetry;

  const _FailureCard({
    required this.error,
    required this.isRetrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.storage_rounded, size: 56, color: colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'تعذر فتح بيانات التطبيق',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'لم يتم حذف أي فاتورة. أعد المحاولة، وإذا استمرت المشكلة أعد تشغيل '
          'الجهاز أو تواصل مع الدعم الفني.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: isRetrying ? null : onRetry,
          icon: isRetrying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(isRetrying ? 'جاري المحاولة...' : 'إعادة المحاولة'),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            // Selectable so the user can copy it into a support message.
            '$error',
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecoveredCard extends StatelessWidget {
  const _RecoveredCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'تم فتح البيانات بنجاح',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'أغلق التطبيق وافتحه مرة أخرى لمتابعة العمل.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
