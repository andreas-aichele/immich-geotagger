import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.release,
    required this.onDismiss,
  });

  final AppRelease release;
  final VoidCallback onDismiss;

  Future<void> _openRelease(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        release.url,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // A device may have no browser available.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('updateOpenFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Icon(Icons.system_update_rounded,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('updateAvailable',
                      {'version': release.version.toString()}),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(l.t('updateManagerHint'),
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: l.t('updateOpenRelease'),
            onPressed: () => _openRelease(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
          ),
          IconButton(
            tooltip: l.t('updateDismiss'),
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
