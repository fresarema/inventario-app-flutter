class Producto {
  final String codigo;
  final String descripcion;

  Producto({
    required this.codigo,
    required this.descripcion,
  });

  // Transforma el JSON de la API (o SQLite) a un Objeto Dart
  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      codigo: json['codigo'],
      descripcion: json['descripcion'],
    );
  }

  // Transforma el Objeto Dart a un formato que SQLite entienda
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
    };
  }
}