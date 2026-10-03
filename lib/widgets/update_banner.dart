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
    this.preview = false,
  });

  final AppRelease release;
  final VoidCallback onDismiss;
  final bool preview;

  Future<void> _openRelease(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        preview
            ? Uri.https('github.com',
                '/andreas-aichele/immich-geotagger/releases/latest')
            : release.url,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  preview
                      ? l.t('updateTest')
                      : l.t('updateAvailable', {'version': release.version.toString()}),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: l.t('updateDismiss'),
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(l.t('updateManagerHint')),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _openRelease(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l.t('updateOpenRelease')),
          ),
        ],
      ),
    );
  }
}
