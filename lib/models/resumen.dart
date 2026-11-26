/// Resumen de cartera: GET /prestamos/resumen.
class Resumen {
  final double capitalPrestado;
  final double totalPorCobrar;
  final double gananciaEsperada;
  final int cantidadPrestamos;
  final int porCobrar;
  final int cobrados;
  final int morosos;

  Resumen({
    required this.capitalPrestado,
    required this.totalPorCobrar,
    required this.gananciaEsperada,
    required this.cantidadPrestamos,
    required this.porCobrar,
    required this.cobrados,
    required this.morosos,
  });

  factory Resumen.fromJson(Map<String, dynamic> json) {
    return Resumen(
      capitalPrestado: (json['capitalPrestado'] as num?)?.toDouble() ??
          (json['montoTotal'] as num?)?.toDouble() ??
          0.0,
      totalPorCobrar: (json['totalPorCobrar'] as num?)?.toDouble() ??
          (json['totalCobrar'] as num?)?.toDouble() ??
          0.0,
      gananciaEsperada: (json['gananciaEsperada'] as num?)?.toDouble() ??
          (json['ganancia'] as num?)?.toDouble() ??
          0.0,
      cantidadPrestamos: (json['cantidadPrestamos'] as num?)?.toInt() ??
          (json['totalPrestamos'] as num?)?.toInt() ??
          0,
      porCobrar: (json['porCobrar'] as num?)?.toInt() ??
          (json['pendientes'] as num?)?.toInt() ??
          0,
      cobrados: (json['cobrados'] as num?)?.toInt() ??
          (json['pagados'] as num?)?.toInt() ??
          0,
      morosos: (json['morosos'] as num?)?.toInt() ?? 0,
    );
  }

  String get capitalPrestadoTexto => 'S/ ${capitalPrestado.toStringAsFixed(2)}';
  String get totalPorCobrarTexto => 'S/ ${totalPorCobrar.toStringAsFixed(2)}';
  String get gananciaEsperadaTexto => 'S/ ${gananciaEsperada.toStringAsFixed(2)}';
}
