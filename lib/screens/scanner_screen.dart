import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  final String numeroMetro;
  final ApiService apiService;

  const ScannerScreen({super.key, required this.numeroMetro, required this.apiService,});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final List<Map<String, dynamic>> _productosEscaneados = [];
  final DatabaseService _dbService = DatabaseService();

  // Modal 1: Ingreso Manual (Imagen 4)
  void _mostrarModalIngresoManual() {
    final TextEditingController codigoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Colors.blue),
            SizedBox(width: 8),
            Text('Ingreso Manual', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Digita el código de barras o SKU:'),
            const SizedBox(height: 12),
            TextField(
              controller: codigoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ej: 780123456789',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _buscarProducto(codigoController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  // Lógica de búsqueda en SQLite
  void _buscarProducto(String codigo) async {
    if (codigo.isEmpty) return;

    final producto = await _dbService.buscarProducto(codigo);

    if (producto != null && mounted) {
      _mostrarModalCantidad(producto);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto no encontrado en la base local'), backgroundColor: Colors.red),
      );
    }
  }

  // Modal 2: Control de Inventario / Cantidad (Imagen 5)
  void _mostrarModalCantidad(Producto producto) {
    final TextEditingController cantidadController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Control de Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código SKU: ${producto.codigo}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  const SizedBox(height: 4),
                  const Text('Formato: Unidad', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Digita la Cantidad Física:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: cantidadController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Ingresa cantidad (ej: 1.5)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (cantidadController.text.isNotEmpty) {
                  setState(() {
                    _productosEscaneados.add({
                      'producto': producto,
                      'cantidad': double.parse(cantidadController.text),
                      'hora': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}"
                    });
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Agregar al Inventario'),
            ),
          ),
        ],
      ),
    );
  }

  // Modal 3: Sincronizar Metro 
  void _mostrarModalSincronizar() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('¿Sincronizar Metro?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Se consolidarán los ${_productosEscaneados.length} productos registrados en el Metro N° ${widget.numeroMetro}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text('Revisar Más', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); 

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando con el servidor...')),
              );

              bool exito = await widget.apiService.sincronizarMetro(widget.numeroMetro, _productosEscaneados);

              if (exito && mounted) {
                setState(() { _productosEscaneados.clear(); });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Metro sincronizado con éxito!'), backgroundColor: Colors.green),
                );
                await Future.delayed(const Duration(milliseconds: 1500));
                if (mounted) Navigator.pop(context); 
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error al guardar. Revisa el servidor.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmar y Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Metro N° ${widget.numeroMetro}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Zona superior oscura del escáner
          Container(
            width: double.infinity,
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Icons.keyboard, color: Colors.white),
                      onPressed: _mostrarModalIngresoManual,
                    ),
                  ),
                ),
                const Icon(Icons.image, color: Colors.white24, size: 80),
                const SizedBox(height: 16),
                const Text('Escáner en espera...', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Simular escaneo de prueba
                    _buscarProducto("9584898518720"); // Reemplaza esto con un código que sepas que existe en tu BD
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('PRESIONE PARA ESCANEAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de productos escaneados
          Expanded(
            child: _productosEscaneados.isEmpty
                ? const Center(
                    child: Text('Ningún producto escaneado en este metro.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _productosEscaneados.length,
                    itemBuilder: (context, index) {
                      final item = _productosEscaneados[index];
                      final prod = item['producto'] as Producto;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.inventory_2, color: Colors.white, size: 20)),
                          title: Text(prod.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('SKU: ${prod.codigo} • Hora: ${item['hora']}', style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                            child: Text('Cant: ${item['cantidad']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Botón inferior para guardar/sincronizar (solo visible si hay productos)
          if (_productosEscaneados.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _mostrarModalSincronizar,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Guardar Toma de Inventario', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}