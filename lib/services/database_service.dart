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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp_ms INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            is_manual INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_location_time ON location_points(timestamp_ms)',
        );
        await db.execute('''
          CREATE TABLE geotagged_assets (
            asset_id TEXT PRIMARY KEY,
            updated_at_ms INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE geotagged_assets ADD COLUMN track_before_ms INTEGER',
          );
          await db.execute(
            'ALTER TABLE geotagged_assets ADD COLUMN track_after_ms INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE location_points ADD COLUMN is_manual INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE geotagged_assets_new (
              asset_id TEXT PRIMARY KEY,
              updated_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            INSERT INTO geotagged_assets_new (asset_id, updated_at_ms)
            SELECT asset_id, updated_at_ms FROM geotagged_assets
          ''');
          await db.execute('DROP TABLE geotagged_assets');
          await db.execute(
            'ALTER TABLE geotagged_assets_new RENAME TO geotagged_assets',
          );
        }
      },
    );
    return _db!;
  }

  Future<void> insertLocation(LocationPoint point) async {
    final db = await database;
    final map = point.toMap()..remove('id');
    await db.insert('location_points', map);
  }

  Future<List<LocationPoint>> locationsBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'location_points',
      where: 'timestamp_ms >= ? AND timestamp_ms <= ?',
      whereArgs: [
        from.toUtc().millisecondsSinceEpoch,
        to.toUtc().millisecondsSinceEpoch
      ],
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<List<LocationPoint>> allLocations() async {
    final db = await database;
    final rows = await db.query(
      'location_points',
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<(DateTime?, DateTime?)> locationTimesAround(DateTime timestamp) async {
    final db = await database;
    final value = timestamp.toUtc().millisecondsSinceEpoch;
    final beforeRows = await db.query(
      'location_points',
      columns: ['timestamp_ms'],
      where: 'timestamp_ms <= ?',
      whereArgs: [value],
      orderBy: 'timestamp_ms DESC',
      limit: 1,
    );
    final afterRows = await db.query(
      'location_points',
      columns: ['timestamp_ms'],
      where: 'timestamp_ms >= ?',
      whereArgs: [value],
      orderBy: 'timestamp_ms ASC',
      limit: 1,
    );

    DateTime? pointTime(List<Map<String, Object?>> rows) {
      if (rows.isEmpty) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        rows.first['timestamp_ms'] as int,
        isUtc: true,
      );
    }

    return (pointTime(beforeRows), pointTime(afterRows));
  }

  Future<void> purgeLocationsOlderThan(Duration retention) async {
    final db = await database;
    final cutoff = DateTime.now().toUtc().subtract(retention);
    await db.delete('location_points',
        where: 'timestamp_ms < ?', whereArgs: [cutoff.millisecondsSinceEpoch]);
  }

  Future<void> saveUpdatedAsset(GeotaggedAsset asset) async {
    final db = await database;
    await db.insert('geotagged_assets', asset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GeotaggedAsset>> updatedAssets({
    required Duration retention,
    int limit = 250,
  }) async {
    final db = await database;
    final cutoff =
        DateTime.now().toUtc().subtract(retention).millisecondsSinceEpoch;
    await db.delete('geotagged_assets',
        where: 'updated_at_ms < ?', whereArgs: [cutoff]);
    final rows = await db.query('geotagged_assets',
        orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(GeotaggedAsset.fromMap).toList();
  }

  Future<int> locationCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM location_points');
    return (result.first['c'] as int?) ?? 0;
  }
}
