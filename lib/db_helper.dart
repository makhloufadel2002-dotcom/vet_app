import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Eleveur {
  int? id;
  String nom;
  String pere;
  String cin;
  String dateCin;
  String daira;

  bool isSelected = false;
  String ovins = "";
  String brebis = "";

  // الخانات المخصصة (تتبدل من شخص لشخص)
  Map<String, String> customData = {};

  Eleveur({
    this.id,
    required this.nom,
    required this.pere,
    required this.cin,
    required this.dateCin,
    required this.daira,
    Map<String, String>? customData,
  }) {
    if (customData != null) {
      this.customData = customData;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'pere': pere,
      'cin': cin,
      'date_cin': dateCin,
      'daira': daira,
      'custom_data': jsonEncode(
        customData,
      ), // تحويل المتغيرات المخصصة لنص باش تتسجل
    };
  }

  factory Eleveur.fromMap(Map<String, dynamic> map) {
    return Eleveur(
      id: map['id'],
      nom: map['nom'],
      pere: map['pere'],
      cin: map['cin'],
      dateCin: map['date_cin'],
      daira: map['daira'],
      customData: map['custom_data'] != null
          ? Map<String, String>.from(jsonDecode(map['custom_data']))
          : {},
    );
  }
}

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'vet_database.db');
    return await openDatabase(
      path,
      version: 2, // رفعنا النسخة لتحديث قاعدة البيانات
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE eleveurs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT, pere TEXT, cin TEXT, date_cin TEXT, daira TEXT,
            custom_data TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE eleveurs ADD COLUMN custom_data TEXT DEFAULT '{}'",
          );
        }
      },
    );
  }

  static Future<void> insertEleveur(Eleveur eleveur) async {
    final db = await database;
    await db.insert(
      'eleveurs',
      eleveur.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateEleveur(Eleveur eleveur) async {
    final db = await database;
    await db.update(
      'eleveurs',
      eleveur.toMap(),
      where: 'id = ?',
      whereArgs: [eleveur.id],
    );
  }

  static Future<void> deleteEleveur(int id) async {
    final db = await database;
    await db.delete('eleveurs', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Eleveur>> getEleveurs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('eleveurs');
    return List.generate(maps.length, (i) => Eleveur.fromMap(maps[i]));
  }
}
