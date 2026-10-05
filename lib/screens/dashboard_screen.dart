import 'package:flutter/material.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/producto.dart';
import 'scanner_screen.dart';
import 'login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  final String sucursal;

  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.sucursal,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _metroController = TextEditingController();
  bool _isDownloading = false;
  
  // Controla el estado del botón mientras consulta la API
  bool _isValidating = false; 

  List<String> _sectoresDisponibles = ['Superficie'];
  String _nivelSeleccionado = 'Superficie';
  List<Map<String, String>> _metrosPendientes = [];
  bool _isSyncingMaster = false;

  @override
  void initState() {
    super.initState();
    _cargarMetrosPendientes();
    _cargarSectores();
  }

  void _cargarMetrosPendientes() async {
    final conteos = await DatabaseService().obtenerConteosPendientes();
    // Extrae combinaciones únicas de metro y nivel
    final Set<String> combinaciones = conteos.map((c) => "${c['metro']}|${c['nivel']}").toSet();

    List<Map<String, String>> listaPendientes = combinaciones.map((comb) {
      final partes = comb.split('|');
      return {'metro': partes[0], 'nivel': partes[1]};
    }).toList();

    setState(() {
      _metrosPendientes = listaPendientes;
    });
  }

  Future<bool> _verificarLatencia() async {
    try {
      // Usa un endpoint ligero (ej. la raíz de la API o uno específico)
      final url = Uri.parse('${widget.apiService.baseUrl}/ping'); 
      
      // Fuerza un timeout de 2 segundos. Si demora más, arrojará un error.
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      // Si hay un TimeoutException o el servidor no responde, la red es inestable
      return false; 
    }
  }

  void _sincronizarTodo() async {
    // 1. VALIDACIÓN DE RED: Bloqueo de datos móviles
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    
    if (!connectivityResult.contains(ConnectivityResult.wifi)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Conéctese a la red Wi-Fi del supermercado (Datos móviles bloqueados).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; 
    }

    setState(() { _isSyncingMaster = true; }); // Inicia el loader

    // 2. PRUEBA DE LATENCIA: Verificar calidad de la señal
    bool redEstable = await _verificarLatencia();
    
    if (!redEstable) {
      setState(() { _isSyncingMaster = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Señal inestable o muy débil. Acércate más al router antes de sincronizar.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return; // Detenemos el envío para proteger los datos
    }

    // 3. FLUJO ORIGINAL: Si todo está bien, envía los datos
    final todosLosConteos = await DatabaseService().obtenerConteosPendientes();
    
    for(var pendiente in _metrosPendientes) {
      String metro = pendiente['metro']!;
      String nivel = pendiente['nivel']!;
      
      final dataDelMetro = todosLosConteos.where((c) => c['metro'] == metro && c['nivel'] == nivel).toList();
      
      List<Map<String, dynamic>> payload = dataDelMetro.map((c) => {
        'producto': Producto(codigo: c['codigo'].toString(), descripcion: ''),
        'cantidad': c['cantidad']
      }).toList();

      String? nota = await DatabaseService().obtenerObservacionMetro(metro, nivel);

      bool exito = await widget.apiService.sincronizarMetro(metro, nivel, payload, observacion: nota);
      
      if (exito) {
        await DatabaseService().limpiarMetroSincronizado(metro, nivel);
      }
    }
    
    _cargarMetrosPendientes();
    setState(() { _isSyncingMaster = false; });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronización masiva completada.'), backgroundColor: Colors.blue),
      );
    }
  }

  void _cargarSectores() async {
    final sectores = await DatabaseService().obtenerSectoresUnicos();
    setState(() {
      _sectoresDisponibles = sectores;
      // Si el sector actual no está en la nueva lista, selecciona el primero
      if (!_sectoresDisponibles.contains(_nivelSeleccionado)) {
        _nivelSeleccionado = _sectoresDisponibles.first;
      }
    });
  }

  void _descargarCatalogo() async {
    setState(() { _isDownloading = true; });

    try {
      // 1. Descarga y guarda productos
      final productos = await widget.apiService.descargarCatalogo();
      await DatabaseService().insertarProductosMasivo(productos);

      // 2. Descarga y guarda metros de la sucursal actual
      final codLocal = widget.apiService.inventarioSeleccionado!['codLocal'];
      final metros = await widget.apiService.descargarMetros(codLocal);
      await DatabaseService().insertarMetrosMasivo(metros);

      _cargarSectores();

      setState(() { _isDownloading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Éxito! Catálogo y ${metros.length} metros actualizados.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() { _isDownloading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión al descargar datos.'), backgroundColor: Colors.red),
        );
      }
    }
  }


  // Validación de metro local y offline
  void _iniciarProcesoValidacion() async {
    final numeroMetro = _metroController.text.trim();
    if (numeroMetro.isEmpty) return;

    
    bool esValido = await DatabaseService().validarMetroLocal(numeroMetro, _nivelSeleccionado);

    if (esValido) {
      _confirmarInicioInventario(); 
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El Metro N° $numeroMetro en $_nivelSeleccionado no existe o está cerrado.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // MODAL PARA CONFIRMAR INICIO INVENTARIO
  void _confirmarInicioInventario() {
    final TextEditingController _observacionController = TextEditingController(); // Controlador para la nota

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('¿Iniciar Inventario?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, // Evita que ocupe toda la pantalla
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Comenzar conteo en el Metro N° ${_metroController.text}?', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _observacionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observación (Superficie, Subterráneo...)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScannerScreen(
                    numeroMetro: _metroController.text,
                    nivel: _nivelSeleccionado,
                    observacionMetro: _observacionController.text.trim(), 
                    apiService: widget.apiService,
                  ),
                ),
              );

              if (mounted) {
                _cargarMetrosPendientes();
                _metroController.clear();
                FocusScope.of(context).unfocus();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Comenzar', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Panel de Control',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              onPressed: () {
                widget.apiService.token = null;
                widget.apiService.inventarioSeleccionado = null;
                widget.apiService.inventariosAsignados = [];
                widget.apiService.nombreUsuario = '';

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: const Icon(Icons.store, color: Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sucursal: ${widget.sucursal}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal)),
                            Text(
                              'Operario(a): ${widget.apiService.nombreUsuario} | N° Local: ${widget.apiService.inventarioSeleccionado!['codLocal']}',
                              style: TextStyle(color: Colors.teal.shade700),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _descargarCatalogo,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download_outlined),
                    label: Text(_isDownloading
                        ? 'Descargando...'
                        : 'Sincronizar Catálogo Maestro'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Digita el sector o metro de conteo libre:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _metroController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
                    hintText: 'Número de Metro / Pasillo',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const Text('Selecciona el Sector/Zona:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _nivelSeleccionado,
                      // Mapea la lista dinámica extraída de SQLite
                      items: _sectoresDisponibles.map((String valor) {
                        return DropdownMenuItem<String>(
                          value: valor,
                          child: Text(valor),
                        );
                      }).toList(),
                      onChanged: (String? nuevoValor) {
                        setState(() { _nivelSeleccionado = nuevoValor!; });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // BOTÓN ACTUALIZADO PARA LA VALIDACIÓN
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    // Apunta a la nueva función
                    onPressed: _isValidating ? null : _iniciarProcesoValidacion,
                    // Cambia el ícono por un loader si está validando
                    icon: _isValidating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_isValidating ? 'Validando...' : 'Comenzar Inventario General', style: const TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                
                // SECCIÓN OFFLINE FIRST
                if (_metrosPendientes.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Conteos Pendientes por Sincronizar:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),

                  // Dibuja los recuadros de los metros
                  ..._metrosPendientes.map((pendiente) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Conteo Metro ${pendiente['metro']} (${pendiente['nivel']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.offline_pin, color: Colors.orange, size: 20),
                      ],
                    ),
                  )),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncingMaster ? null : _sincronizarTodo,
                      icon: _isSyncingMaster 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_isSyncingMaster ? 'Enviando...' : 'Registrar Lista de Conteos', style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      );
  }
}