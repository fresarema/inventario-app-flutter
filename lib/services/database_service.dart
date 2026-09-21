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
    await db.execute('''
      CREATE TABLE productos(
        codigo TEXT PRIMARY KEY,
        descripcion TEXT
      )
    ''');

    // Agrega la columna 'metro' para agrupar los escaneos
    await db.execute('''
      CREATE TABLE conteos_pendientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metro TEXT,
        codigo TEXT,
        cantidad REAL
      )
    ''');

    // Tabla para guardar las observaciones de los metros
    await db.execute('''
      CREATE TABLE metros_observaciones(
        metro TEXT PRIMARY KEY,
        observacion TEXT
      )
    ''');

    // TABLA PARA LOS METROS PERMITIDOS
    await db.execute('''
      CREATE TABLE metros_validos(
        numero TEXT PRIMARY KEY
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

  // Guarda todos los escaneos de un metro en la memoria local
  Future<void> guardarMetroOffline(String metro, List<Map<String, dynamic>> escaneos) async {
    final db = await database;
    Batch batch = db.batch();
    
    for (var item in escaneos) {
      final prod = item['producto'] as Producto;
      batch.insert('conteos_pendientes', {
        'metro': metro,
        'codigo': prod.codigo,
        'cantidad': item['cantidad']
      });
    }
    await batch.commit(noResult: true);
  }

  // Guardado de observaciones del metro en la memoria local
  Future<void> guardarObservacionMetro(String metro, String observacion) async {
    final db = await database;
    await db.insert('metros_observaciones', {
      'metro': metro,
      'observacion': observacion
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Recupera todos los datos guardados sin conexión
  Future<List<Map<String, dynamic>>> obtenerConteosPendientes() async {
    final db = await database;
    return await db.query('conteos_pendientes');
  }

  // Recupera la observación de un metro específico antes de enviarla al servidor
  Future<String?> obtenerObservacionMetro(String metro) async {
    final db = await database;
    final result = await db.query(
      'metros_observaciones',
      where: 'metro = ?',
      whereArgs: [metro],
    );
    
    if (result.isNotEmpty) {
      return result.first['observacion'] as String;
    }
    return null;
  }

  // Borra únicamente el metro que ya se envió con éxito al servidor
  Future<void> limpiarMetroSincronizado(String metro) async {
    final db = await database;
    await db.delete('conteos_pendientes', where: 'metro = ?', whereArgs: [metro]);
    await db.delete('metros_observaciones', where: 'metro = ?', whereArgs: [metro]);
  }

  // Guarda los metros descargados del servidor
  Future<void> insertarMetrosMasivo(List<dynamic> metros) async {
    final db = await database;
    await db.delete('metros_validos'); // Limpia la lista anterior
    
    Batch batch = db.batch();
    for (var m in metros) {
      batch.insert('metros_validos', {
        'numero': m['numeroMetro'].toString()
      });
    }
    await batch.commit(noResult: true);
  }

  // Verifica instantáneamente si el metro ingresado existe en la memoria
  Future<bool> validarMetroLocal(String numero) async {
    final db = await database;
    final result = await db.query(
      'metros_validos',
      where: 'numero = ?',
      whereArgs: [numero],
    );
    return result.isNotEmpty;
  }


}