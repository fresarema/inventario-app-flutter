import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _usuarioVerificado = false;

  void _verificarCredenciales() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      // Llama al nuevo método que valida credenciales y existencia de inventario activo
      final resultado = await _apiService.loginYValidar(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() { _isLoading = false; });

      if (resultado['success'] == true) {
        setState(() { _usuarioVerificado = true; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Acceso concedido. Inventario activo en: ${_apiService.sucursalAsignada}'),
              backgroundColor: Colors.teal,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['mensaje']),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _ingresarApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          apiService: _apiService,
          sucursal: _apiService.sucursalAsignada!, // Toma la sucursal inyectada por Laravel
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Sistema UnicoAdmin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Control de Inventario Offline', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                
                TextFormField(
                  controller: _emailController,
                  enabled: !_usuarioVerificado,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_usuarioVerificado,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 24),
                
                if (!_usuarioVerificado)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verificarCredenciales,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('INICIAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else
                  Column(
                    children: [
                      if (_apiService.inventariosAsignados.length == 1)
                        // CASO 1: Tiene solo un inventario (Agrega la observación abajo)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.teal, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Proceso Activo: ${_apiService.inventarioSeleccionado!['nombre_local']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    // Muestra la observación si existe
                                    if (_apiService.inventarioSeleccionado!['observacion'] != null && _apiService.inventarioSeleccionado!['observacion'].toString().isNotEmpty)
                                      Text(
                                        'Obs: ${_apiService.inventarioSeleccionado!['observacion']}',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.teal.shade700, fontSize: 13),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // CASO 2: Múltiples inventarios (Selector + Observación abajo)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.teal),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.teal.shade50,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Map<String, dynamic>>(
                                  isExpanded: true,
                                  value: _apiService.inventarioSeleccionado,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                                  items: _apiService.inventariosAsignados.map((dynamic inv) {
                                    return DropdownMenuItem<Map<String, dynamic>>(
                                      value: inv,
                                      child: Text(
                                        '${inv['inventario']} - ${inv['nombre_local']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (Map<String, dynamic>? nuevoValor) {
                                    setState(() {
                                      _apiService.inventarioSeleccionado = nuevoValor;
                                    });
                                  },
                                ),
                              ),
                            ),
                            // Muestra la observación del inventario que esté seleccionado actualmente en el Dropdown
                            if (_apiService.inventarioSeleccionado!['observacion'] != null && _apiService.inventarioSeleccionado!['observacion'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0, left: 4.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, size: 18, color: Colors.teal),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Instrucciones: ${_apiService.inventarioSeleccionado!['observacion']}',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.teal.shade800, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DashboardScreen(
                                  apiService: _apiService,
                                  sucursal: _apiService.inventarioSeleccionado!['nombre_local'],
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('COMENZAR INVENTARIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}