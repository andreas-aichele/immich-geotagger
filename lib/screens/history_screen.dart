import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/geotagged_asset.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final material = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('updatedPhotos'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<GeotaggedAsset>>(
        future: DatabaseService.instance.updatedAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(child: Text(l.t('noPhotosUpdated')));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final local = item.captureTime.toLocal();
              final date = material.formatMediumDate(local);
              final time = material.formatTimeOfDay(
                TimeOfDay.fromDateTime(local),
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              );

              return ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(item.fileName),
                subtitle: Text(
                  '$date, $time\n'
                  '${item.latitude.toStringAsFixed(6)}, '
                  '${item.longitude.toStringAsFixed(6)}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
