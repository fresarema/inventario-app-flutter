class Conteo {
  final int? id; // Es nulo antes de guardarlo en SQLite porque se autoincrementa
  final String codigo;
  final double cantidad;

  Conteo({
    this.id,
    required this.codigo,
    required this.cantidad,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'cantidad': cantidad,
    };
  }

  // Para enviar a Laravel, descartamos el ID local
  Map<String, dynamic> toJsonApi() {
    return {
      'codigo': codigo,
      'cantidad': cantidad,
    };
  }
}