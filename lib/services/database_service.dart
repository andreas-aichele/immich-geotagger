import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/geotagged_asset.dart';
import '../models/location_point.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'immich_geotagger.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp_ms INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_location_time ON location_points(timestamp_ms)',
        );
        await db.execute('''
          CREATE TABLE geotagged_assets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_id TEXT NOT NULL UNIQUE,
            file_name TEXT NOT NULL,
            capture_time_ms INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            updated_at_ms INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> insertLocation(LocationPoint point) async {
    final db = await database;
    final map = point.toMap()..remove('id');
    await db.insert('location_points', map);
  }

  Future<List<LocationPoint>> locationsBetween(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'location_points',
      where: 'timestamp_ms >= ? AND timestamp_ms <= ?',
      whereArgs: [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<void> purgeLocationsOlderThan(Duration retention) async {
    final db = await database;
    final cutoff = DateTime.now().toUtc().subtract(retention);
    await db.delete('location_points', where: 'timestamp_ms < ?', whereArgs: [cutoff.millisecondsSinceEpoch]);
  }

  Future<void> saveUpdatedAsset(GeotaggedAsset asset) async {
    final db = await database;
    final map = asset.toMap()..remove('id');
    await db.insert('geotagged_assets', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GeotaggedAsset>> updatedAssets({int limit = 250}) async {
    final db = await database;
    final rows = await db.query('geotagged_assets', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(GeotaggedAsset.fromMap).toList();
  }

  Future<int> locationCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM location_points');
    return (result.first['c'] as int?) ?? 0;
  }
}
