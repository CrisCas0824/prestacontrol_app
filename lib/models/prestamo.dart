import 'package:flutter/material.dart';

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
    final total = (json['totalACobrar'] as num?)?.toDouble() ??
        (json['monto'] as num).toDouble();
    // Si la API no manda 'moroso', se calcula aqui: vencido y sin pagar.
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final moroso = json['moroso'] as bool? ??
        (!pagado && vencimiento.isBefore(soloHoy));

    return Prestamo(
      id: (json['id'] as num).toInt(),
      cliente: json['cliente'] as String? ?? 'Sin nombre',
      dni: json['dni'] as String? ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      interes: (json['interes'] as num?)?.toDouble() ?? 0.0,
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
  String get interesTexto => '${interes.toStringAsFixed(1)}%';

  /// Dias restantes hasta el vencimiento (negativo si esta vencido)
  int get diasRestantes {
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final soloVenc = DateTime(
        fechaVencimiento.year, fechaVencimiento.month, fechaVencimiento.day);
    return soloVenc.difference(soloHoy).inDays;
  }

  /// Texto explicativo del tiempo de vencimiento
  String get tiempoRestanteTexto {
    if (pagado) return 'Pagado';
    final dias = diasRestantes;
    if (dias < 0) {
      final pasados = dias.abs();
      return 'Venció hace $pasados ${pasados == 1 ? "día" : "días"}';
    } else if (dias == 0) {
      return 'Vence hoy';
    } else if (dias == 1) {
      return 'Vence mañana';
    } else {
      return 'Vence en $dias días';
    }
  }

  /// Iniciales del cliente para el avatar
  String get iniciales {
    final partes = cliente.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'P';
    if (partes.length == 1) {
      return partes.first.substring(0, partes.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }

  /// Color semántico según el estado
  Color get estadoColor {
    if (pagado) return const Color(0xFF10B981); // Emerald
    if (moroso) return const Color(0xFFEF4444); // Red
    return const Color(0xFF0F766E); // Teal
  }

  /// Etiqueta del estado
  String get estadoTexto {
    if (pagado) return 'PAGADO';
    if (moroso) return 'VENCIDO';
    return 'POR COBRAR';
  }
}
