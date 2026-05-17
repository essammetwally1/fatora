import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('فواتيري'),
      actions: [
        IconButton(
          tooltip: 'تغيير المظهر',
          onPressed: () {
            context.read<SettingsProvider>().toggleTheme();
          },
          icon: Selector<SettingsProvider, bool>(
            selector: (_, settings) => settings.isDark,
            builder: (_, isDark, _) {
              return Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              );
            },
          ),
        ),
      ],
    );
  }
}
