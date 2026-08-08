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
  
  // Nuevas variables para el flujo de dos pasos
  bool _usuarioVerificado = false;
  String? _sucursalSeleccionada;
  final List<String> _sucursales = ['Los Ángeles', 'Mulchén', 'Angol', 'Laja', 'Santa Bárbara'];

  void _verificarCredenciales() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      bool exito = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() { _isLoading = false; });

      if (exito) {
        setState(() { _usuarioVerificado = true; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario correcto. Seleccione su sucursal.'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credenciales incorrectas o sin conexión'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _ingresarApp() {
    if (_sucursalSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar una sucursal'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          apiService: _apiService,
          sucursal: _sucursalSeleccionada!, // Pasa la sucursal elegida
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
                // Logo simulado 
                const Icon(Icons.eco, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Sistema UnicoAdmin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Control de Inventario', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                
                // Campos de credenciales (se deshabilitan si ya se verificó)
                TextFormField(
                  controller: _emailController,
                  enabled: !_usuarioVerificado,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  ),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 24),
                
                // Transición dinámica: Mostrar botón Verificar o Selector de Sucursal
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
                          : const Text('VERIFICAR USUARIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.teal),
                                SizedBox(width: 8),
                                Text('Seleccionar local...'),
                              ],
                            ),
                            value: _sucursalSeleccionada,
                            items: _sucursales.map((String sucursal) {
                              return DropdownMenuItem<String>(
                                value: sucursal,
                                child: Text(sucursal),
                              );
                            }).toList(),
                            onChanged: (String? nuevoValor) {
                              setState(() { _sucursalSeleccionada = nuevoValor; });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _ingresarApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('INGRESAR A LA APP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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