import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto.dart';

class ApiService {
  // IP del emulador de android
  final String baseUrl = 'http://10.0.2.2:8000/api';
  String? token;

  // 1. Iniciar sesión y guardar el token
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        body: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token']; // Guarda el token en memoria
        return true;
      }
      return false;
    } catch (e) {
      print('Error en login: $e');
      return false;
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
        
        // Convierte el JSON masivo a una lista de objetos Producto
        return productosJson.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error al descargar productos');
      }
    } catch (e) {
      print('Error de red: $e');
      throw Exception('Fallo la conexión con el servidor');
    }
  }

  // Función para subir los conteos al servidor
  Future<bool> sincronizarMetro(String metro, List<Map<String, dynamic>> registros) async {
    if (token == null) return false;

    try {
      // Formatea la lista tal como la espera el validador de Laravel
      List<Map<String, dynamic>> conteosParaApi = registros.map((item) {
        final prod = item['producto'] as Producto;
        return {
          'codigo': prod.codigo,
          'cantidad': item['cantidad'],
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/inventario/sincronizar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json', // Informa a Laravel que enviamos un JSON
        },
        body: jsonEncode({
          'metro': metro, // Envia el metro pensando en el futuro panel web
          'conteos': conteosParaApi,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error al sincronizar: $e');
      return false;
    }
  }
}