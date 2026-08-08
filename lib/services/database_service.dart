import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/producto.dart';

class DatabaseService {
  // Configuración Singleton
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // Getter para obtener la base de datos (la abre si está cerrada)
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }

  // Inicialización y creación del archivo físico
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'inventario_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Creación de las tablas la primera vez que se instala la app
  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabla espejo del catálogo maestro (SQL Server)
    await db.execute('''
      CREATE TABLE productos(
        codigo TEXT PRIMARY KEY,
        descripcion TEXT
      )
    ''');

    // 2. Tabla temporal para el trabajo offline en bodega
    await db.execute('''
      CREATE TABLE conteos_pendientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo TEXT,
        cantidad REAL
      )
    ''');
  }

  // Inserta miles de productos en un solo movimiento bloqueando la BD brevemente
  Future<void> insertarProductosMasivo(List<Producto> productos) async {
    final db = await database;
    
    // Vacia la tabla por si ya había datos antiguos
    await db.delete('productos'); 

    // Inicia la transacción por lotes
    Batch batch = db.batch();

    for (var producto in productos) {
      batch.insert(
        'productos',
        producto.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Ejecuta el lote (noResult: true lo hace aún más rápido)
    await batch.commit(noResult: true);
  }

  // Busca un producto específico por su código de barras
  Future<Producto?> buscarProducto(String codigo) async {
    final db = await database;
    
    // Hace la consulta a SQLite
    final List<Map<String, dynamic>> mapas = await db.query(
      'productos',
      where: 'codigo = ?',
      whereArgs: [codigo],
    );

    // Si encuentra algo, lo convierte en un objeto Producto, si no, devuelve nulo
    if (mapas.isNotEmpty) {
      return Producto.fromJson(mapas.first);
    }
    return null;
  }


}