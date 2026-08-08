import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  final String sucursal;

  const DashboardScreen({super.key, required this.apiService, required this.sucursal,});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _metroController = TextEditingController();
  bool _isDownloading = false;

  void _descargarCatalogo() async {
    setState(() { _isDownloading = true; });

    try {
      final productos = await widget.apiService.descargarCatalogo();
      await DatabaseService().insertarProductosMasivo(productos);

      setState(() { _isDownloading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Éxito! ${productos.length} productos guardados.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() { _isDownloading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al descargar el catálogo.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmarInicioInventario() {
    if (_metroController.text.isEmpty) return;

    // Modal Conteo inventario
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
        content: Text(
          '¿Está seguro de comenzar el conteo libre en el Metro N° ${_metroController.text}?',
          style: const TextStyle(fontSize: 16),
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
                    apiService: widget.apiService,
                  ),
                ),
              );


              if (mounted) {
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Panel de Control', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              onPressed: () => Navigator.pop(context),
            )
          ],
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(icon: Icon(Icons.grid_view), text: 'Inventario General'),
              Tab(icon: Icon(Icons.sync), text: 'Inventario Cíclico'),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de Sucursal 
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.teal, child: const Icon(Icons.store, color: Colors.white)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sucursal: ${widget.sucursal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                          Text('Operario(a): SuperAdmin | N° Local: 1', style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Botón de Sincronización Integrado
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isDownloading ? null : _descargarCatalogo,
                  icon: _isDownloading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download_outlined),
                  label: Text(_isDownloading ? 'Descargando...' : 'Sincronizar Catálogo Maestro'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Input del Metro
              const Text('Digita el sector o metro de conteo libre:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              TextField(
                controller: _metroController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
                  hintText: 'Número de Metro / Pasillo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Botón Comenzar
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _confirmarInicioInventario,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Comenzar Inventario General', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}