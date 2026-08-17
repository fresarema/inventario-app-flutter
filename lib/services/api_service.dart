import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto.dart';

class ApiService {
  final String baseUrl = 'http://10.0.2.2:8000/api';
  String? token;
  
  // Variables dinámicas asignadas por el servidor
  String? sucursalAsignada;
  int? idInventarioActivo;
  List<dynamic> inventariosAsignados = [];
  Map<String, dynamic>? inventarioSeleccionado;
  String nombreUsuario = '';

  // 1. Iniciar sesión y validar inventario activo estricto
  Future<Map<String, dynamic>> loginYValidar(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token']; 
        nombreUsuario = data['usuario'] ?? 'Operario';
        
        List<dynamic> inventarios = data['inventarios_activos'] ?? [];

        if (inventarios.isNotEmpty) {
          inventariosAsignados = inventarios;
          // Preselecciona el primer inventario de la lista por defecto
          inventarioSeleccionado = inventarios.first;
          return {'success': true, 'mensaje': 'Inventarios encontrados'};
        } else {
          // Bloqueo total si no tiene nada asignado
          return {'success': false, 'mensaje': 'No tiene inventarios activos asignados en este momento.'};
        }
      } else if (response.statusCode == 401) {
         return {'success': false, 'mensaje': 'Credenciales incorrectas'};
      }
      return {'success': false, 'mensaje': 'Error del servidor'};
    } catch (e) {
      print('Error en login: $e');
      return {'success': false, 'mensaje': 'Sin conexión con el servidor'};
    }
  }

  // 2. Descarga el catálogo usando el token
  Future<List<Producto>> descargarCatalogo() async {
    if (token == null) throw Exception('No hay token de autorización');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/productos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> productosJson = data['data'];
        return productosJson.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error al descargar productos');
      }
    } catch (e) {
      print('Error de red: $e');
      throw Exception('Falló la conexión con el servidor');
    }
  }

  // 3. Sincronizar (Solo conteo físico)
  Future<bool> sincronizarMetro(String metro, List<Map<String, dynamic>> registros) async {
    if (token == null) return false;

    try {
      // Mapeo estricto: la app no procesa el stock teórico, solo envía lo contado
      List<Map<String, dynamic>> conteosParaApi = registros.map((item) {
        final prod = item['producto'] as Producto;
        return {
          'codigo': prod.codigo,
          'cantidad': item['cantidad'], // Solo cantidad física
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/inventario/sincronizar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json', 
        },
        body: jsonEncode({
          'inventario_id': inventarioSeleccionado!['id'], // Asegura que se envía al proceso correcto
          'metro': metro, 
          'conteos': conteosParaApi,
        }),
      );
      print('STATUS CODE SINCRONIZACIÓN: ${response.statusCode}');
      print('RESPUESTA SERVIDOR: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error al sincronizar: $e');
      return false;
    }
  }
}