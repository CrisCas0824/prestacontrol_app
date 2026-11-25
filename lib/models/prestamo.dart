/// Prestamo tal como lo devuelve la API (PrestamoResponse).
class Prestamo {
  final int id;
  final String cliente;
  final String dni;
  final double monto;
  final double interes;
  final DateTime? fechaPrestamo;
  final DateTime fechaVencimiento;
  final bool pagado;
  final double totalACobrar;
  final bool moroso;

  Prestamo({
    required this.id,
    required this.cliente,
    required this.dni,
    required this.monto,
    required this.interes,
    required this.fechaPrestamo,
    required this.fechaVencimiento,
    required this.pagado,
    required this.totalACobrar,
    required this.moroso,
  });

  factory Prestamo.fromJson(Map<String, dynamic> json) {
    final vencimiento = DateTime.parse(json['fechaVencimiento'] as String);
    final pagado = json['pagado'] as bool? ?? false;
    final total = (json['totalACobrar'] as num?)?.toDouble()
        ?? (json['monto'] as num).toDouble();
    // Si la API no manda 'moroso', se calcula aqui: vencido y sin pagar.
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final moroso = json['moroso'] as bool?
        ?? (!pagado && vencimiento.isBefore(soloHoy));
    return Prestamo(
      id: (json['id'] as num).toInt(),
      cliente: json['cliente'] as String,
      dni: json['dni'] as String,
      monto: (json['monto'] as num).toDouble(),
      interes: (json['interes'] as num).toDouble(),
      fechaPrestamo: json['fechaPrestamo'] == null
          ? null
          : DateTime.parse(json['fechaPrestamo'] as String),
      fechaVencimiento: vencimiento,
      pagado: pagado,
      totalACobrar: total,
      moroso: moroso,
    );
  }

  /// Cuerpo que se envia al crear o editar (PrestamoRequest).
  Map<String, dynamic> toRequestJson({bool? pagadoOverride}) {
    return {
      'cliente': cliente,
      'dni': dni,
      'monto': monto,
      'interes': interes,
      'fechaVencimiento':
          '${fechaVencimiento.year.toString().padLeft(4, '0')}-'
          '${fechaVencimiento.month.toString().padLeft(2, '0')}-'
          '${fechaVencimiento.day.toString().padLeft(2, '0')}',
      'pagado': pagadoOverride ?? pagado,
    };
  }

  String get fechaVencimientoTexto =>
      '${fechaVencimiento.day.toString().padLeft(2, '0')}/'
      '${fechaVencimiento.month.toString().padLeft(2, '0')}/'
      '${fechaVencimiento.year}';

  String get montoTexto => 'S/ ${monto.toStringAsFixed(2)}';
  String get totalTexto => 'S/ ${totalACobrar.toStringAsFixed(2)}';
  String get interesTexto => '${interes.toStringAsFixed(2)} %';
}
