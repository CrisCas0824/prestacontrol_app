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
      capitalPrestado: (json['capitalPrestado'] as num?)?.toDouble() ?? 0,
      totalPorCobrar: (json['totalPorCobrar'] as num?)?.toDouble() ?? 0,
      gananciaEsperada: (json['gananciaEsperada'] as num?)?.toDouble() ?? 0,
      cantidadPrestamos: (json['cantidadPrestamos'] as num?)?.toInt() ?? 0,
      porCobrar: (json['porCobrar'] as num?)?.toInt() ?? 0,
      cobrados: (json['cobrados'] as num?)?.toInt() ?? 0,
      morosos: (json['morosos'] as num?)?.toInt() ?? 0,
    );
  }
}
