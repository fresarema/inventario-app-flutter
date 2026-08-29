import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/producto.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  final String numeroMetro;
  final ApiService apiService;

  const ScannerScreen({
    super.key,
    required this.numeroMetro,
    required this.apiService,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final List<Map<String, dynamic>> _productosEscaneados = [];
  final DatabaseService _dbService = DatabaseService();
  
  // Controlador de la cámara
  final MobileScannerController _scannerController = MobileScannerController();
  
  // Bandera para evitar que escanee 100 veces el mismo código en un segundo
  bool _isProcessingScan = false;

  @override
  void dispose() {
    // Apaga la cámara al salir de la pantalla para liberar memoria
    _scannerController.dispose();
    super.dispose();
  }

  // Modal 1: Ingreso Manual
  void _mostrarModalIngresoManual() {
    final TextEditingController codigoController = TextEditingController();
    bool esPesable = false; // Variable local para controlar el estado del Checkbox
    
    // Pausa la cámara mientras digita
    _scannerController.stop();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // StatefulBuilder permite redibujar el contenido interno del modal
        builder: (context, setStateModal) {
          return AlertDialog(
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
                const SizedBox(height: 12),
                
                // Checkbox para productos de balanza
                CheckboxListTile(
                  title: const Text('Es producto pesable (Balanza)'),
                  subtitle: const Text('Añade los ceros automáticamente'),
                  value: esPesable,
                  activeColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? valor) {
                    setStateModal(() {
                      esPesable = valor ?? false; // Actualiza el estado solo dentro del modal
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _scannerController.start(); // Reactivar cámara al cancelar
                },
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  String codigoFinal = codigoController.text.trim();

                  // Lógica de autocompletado si el checkbox está marcado
                  if (esPesable && codigoFinal.length == 6 && codigoFinal.startsWith('2')) {
                    codigoFinal += '0000000'; 
                  }

                  Navigator.pop(context);
                  // Envia el código (modificado o no) a la función de búsqueda original
                  _buscarProducto(codigoFinal); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Buscar'),
              ),
            ],
          );
        }
      ),
    ).then((_) {
      // Por si el usuario descarta el modal tocando fuera de él
      _scannerController.start();
    });
  }

  // Lógica de búsqueda en SQLite
  void _buscarProducto(String codigo) async {
    if (codigo.isEmpty) {
      _isProcessingScan = false;
      _scannerController.start();
      return;
    }

    final producto = await _dbService.buscarProducto(codigo);

    if (producto != null && mounted) {
      _mostrarModalCantidad(producto);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto no encontrado en la base local'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      // Un delay entre escaneos
      await Future.delayed(const Duration(seconds: 2));
      _isProcessingScan = false;
      _scannerController.start();
    }
  }

  // Modal 2: Control de Inventario / Cantidad
  void _mostrarModalCantidad(Producto producto) {
    final TextEditingController cantidadController = TextEditingController();
    
    // Asegura que la cámara esté pausada
    _scannerController.stop();

    showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando fuera para no perder el hilo
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
              autofocus: true, // Abre el teclado automáticamente
              decoration: InputDecoration(
                hintText: 'Ingresa cantidad (ej: 1.5)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isProcessingScan = false;
              _scannerController.start();
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (cantidadController.text.isNotEmpty) {
                double nuevaCantidad = double.parse(cantidadController.text);
                String horaActual = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";

                setState(() {
                  // LÓGICA DE ACUMULACIÓN: Busca si el producto ya fue escaneado antes
                  int indexExistente = _productosEscaneados.indexWhere(
                      (item) => (item['producto'] as Producto).codigo == producto.codigo);

                  if (indexExistente != -1) {
                    // Si existe, suma la cantidad a la que ya estaba
                    _productosEscaneados[indexExistente]['cantidad'] += nuevaCantidad;
                    _productosEscaneados[indexExistente]['hora'] = horaActual;
                  } else {
                    // Si es nuevo en este pasillo, se agrega a la lista
                    _productosEscaneados.add({
                      'producto': producto,
                      'cantidad': nuevaCantidad,
                      'hora': horaActual
                    });
                  }
                });
                
                Navigator.pop(context);
                _isProcessingScan = false;
                _scannerController.start(); // Reactiva cámara para el siguiente producto
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // Modal 3: Sincronizar Metro 
  void _mostrarModalSincronizar() {
    _scannerController.stop(); // Pausa por precaución
    
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
            onPressed: () {
              Navigator.pop(dialogContext);
              _scannerController.start();
            },
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
                setState(() {
                  _productosEscaneados.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Metro sincronizado con éxito!'), backgroundColor: Colors.green),
                );
                await Future.delayed(const Duration(milliseconds: 1500));
                if (mounted) Navigator.pop(context); // Volver al dashboard
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error al guardar. Revisa el servidor.'), backgroundColor: Colors.red),
                );
                _scannerController.start();
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
          // ZONA DE CÁMARA REAL
          SizedBox(
            height: 250, // Altura fija para el visor
            width: double.infinity,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    // Si ya esta procesando un código, ignora las nuevas lecturas
                    if (_isProcessingScan) return;

                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        final String code = barcode.rawValue!;
                        
                        setState(() {
                          _isProcessingScan = true;
                        });
                        
                        _scannerController.stop(); // Detiene la cámara
                        _buscarProducto(code); // Lanza la búsqueda
                        break; // Procesa solo un código a la vez
                      }
                    }
                  },
                ),
                
                // Botón de ingreso manual superpuesto sobre la cámara
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Icons.keyboard, color: Colors.white),
                      onPressed: _mostrarModalIngresoManual,
                      tooltip: 'Ingreso Manual',
                    ),
                  ),
                ),
                
                // Línea roja simulada para apuntar (Opcional, mejora la UX)
                Center(
                  child: Container(
                    width: 200,
                    height: 2,
                    color: Colors.red.withOpacity(0.5),
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
          
          // Botón inferior para guardar/sincronizar
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