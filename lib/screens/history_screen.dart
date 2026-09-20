import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/geotagged_asset.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Updated photos')),
      body: FutureBuilder<List<GeotaggedAsset>>(
        future: DatabaseService.instance.updatedAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('No photos updated yet.'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(item.fileName),
                subtitle: Text(
                  '${DateFormat.yMd().add_Hms().format(item.captureTime.toLocal())}\n'
                  '${item.latitude.toStringAsFixed(6)}, ${item.longitude.toStringAsFixed(6)}',
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
