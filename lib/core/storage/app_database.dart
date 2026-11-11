import 'package:sqflite/sqflite.dart';

/// Membuka dan memigrasikan database SQLite aplikasi.
///
/// Factory dan path dapat diinjeksi untuk test (`sqflite_common_ffi`) atau
/// platform lain. Schema v1 mencakup recipe, plugin, setting, favorite, dan
/// plugin_permission.
final class AppDatabase {
  AppDatabase({this.factory, this.path});

  static const int schemaVersion = 1;
  static const String defaultFileName = 'bufferite.db';

  static const List<String> tables = <String>[
    'recipe',
    'plugin',
    'setting',
    'favorite',
    'plugin_permission',
  ];

  final DatabaseFactory? factory;
  final String? path;
  Database? _database;

  bool get isOpen => _database != null;

  Future<Database> open() async {
    final current = _database;
    if (current != null) {
      return current;
    }

    final activeFactory = factory ?? databaseFactory;
    final databasePath = path ?? '${await getDatabasesPath()}/$defaultFileName';
    final database = await activeFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => createSchemaV1(db),
        onUpgrade: migrate,
      ),
    );
    _database = database;
    return database;
  }

  Future<void> close() async {
    final current = _database;
    if (current == null) {
      return;
    }
    _database = null;
    await current.close();
  }

  /// Membuat schema awal. Dipakai `onCreate` dan migrasi dari v0.
  static Future<void> createSchemaV1(Database db) async {
    await db.execute('''
      CREATE TABLE recipe (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_recipe_updated_at ON recipe(updated_at DESC)',
    );

    await db.execute('''
      CREATE TABLE plugin (
        plugin_id TEXT PRIMARY KEY,
        version TEXT NOT NULL,
        source TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
        verified INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0, 1)),
        installed_at INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_plugin_enabled ON plugin(enabled)');

    await db.execute('''
      CREATE TABLE setting (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE favorite (
        operation_id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE plugin_permission (
        plugin_id TEXT NOT NULL,
        permission TEXT NOT NULL,
        granted INTEGER NOT NULL DEFAULT 0 CHECK (granted IN (0, 1)),
        PRIMARY KEY (plugin_id, permission),
        FOREIGN KEY (plugin_id) REFERENCES plugin(plugin_id)
          ON DELETE CASCADE
      )
    ''');
  }

  /// Migrasi berantai. Versi saat ini hanya v1.
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion; version < newVersion; version++) {
      switch (version) {
        case 0:
          await createSchemaV1(db);
          break;
        default:
          throw StateError(
            'Migrasi database dari versi $version belum tersedia.',
          );
      }
    }
  }
}
