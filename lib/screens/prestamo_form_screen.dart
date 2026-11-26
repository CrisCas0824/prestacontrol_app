import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prestamo.dart';
import '../services/api_exception.dart';
import '../services/prestamo_service.dart';

/// Formulario moderno para registrar y editar préstamos.
class PrestamoFormScreen extends StatefulWidget {
  final Prestamo? prestamo;
  const PrestamoFormScreen({super.key, this.prestamo});

  @override
  State<PrestamoFormScreen> createState() => _PrestamoFormScreenState();
}

class _PrestamoFormScreenState extends State<PrestamoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _interesCtrl = TextEditingController(text: '15.0');
  final _service = PrestamoService();

  DateTime? _vencimiento;
  bool _pagado = false;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.prestamo != null;

  @override
  void initState() {
    super.initState();
    final p = widget.prestamo;
    if (p != null) {
      _clienteCtrl.text = p.cliente;
      _dniCtrl.text = p.dni;
      _montoCtrl.text = p.monto.toStringAsFixed(2);
      _interesCtrl.text = p.interes.toStringAsFixed(1);
      _vencimiento = p.fechaVencimiento;
      _pagado = p.pagado;
    } else {
      _vencimiento = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _dniCtrl.dispose();
    _montoCtrl.dispose();
    _interesCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _vencimiento ?? ahora.add(const Duration(days: 30)),
      firstDate: ahora.subtract(const Duration(days: 365)),
      lastDate: ahora.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F766E),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (fecha != null) setState(() => _vencimiento = fecha);
  }

  void _ajustarPlazoDias(int dias) {
    setState(() {
      _vencimiento = DateTime.now().add(Duration(days: dias));
    });
  }

  String _fechaTexto(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vencimiento == null) {
      setState(() => _error = 'Elige una fecha de vencimiento');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });

    final body = {
      'cliente': _clienteCtrl.text.trim(),
      'dni': _dniCtrl.text.trim(),
      'monto': double.parse(_montoCtrl.text.replaceAll(',', '.')),
      'interes': double.parse(_interesCtrl.text.replaceAll(',', '.')),
      'fechaVencimiento':
          '${_vencimiento!.year.toString().padLeft(4, '0')}-'
          '${_vencimiento!.month.toString().padLeft(2, '0')}-'
          '${_vencimiento!.day.toString().padLeft(2, '0')}',
      'pagado': _pagado,
    };

    try {
      if (_editando) {
        await _service.actualizar(widget.prestamo!.id, body);
      } else {
        await _service.crear(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() =>
          _error = 'No se pudo guardar. Revisa la conexión con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final interesPorc =
        double.tryParse(_interesCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final ganancia = monto * (interesPorc / 100);
    final totalACobrar = monto + ganancia;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _editando ? 'Editar Préstamo' : 'Nuevo Préstamo',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección 1: Datos del Cliente
              _seccionTitulo('DATOS DEL PRESTATARIO', Icons.person_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _clienteCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Cliente',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre del cliente'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _dniCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'DNI (8 dígitos)',
                        prefixIcon: Icon(Icons.badge_outlined),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa el DNI del cliente';
                        }
                        if (v.length != 8) {
                          return 'El DNI debe tener exactamente 8 dígitos';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sección 2: Condiciones del Préstamo
              _seccionTitulo('CONDICIONES DEL PRÉSTAMO', Icons.payments_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _montoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Monto a Prestar (S/)',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (v) {
                        final n =
                            double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null) return 'Ingresa un monto numérico válido';
                        if (n <= 0) return 'El monto debe ser mayor a 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _interesCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Tasa de Interés (%)',
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                      validator: (v) {
                        final n =
                            double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null) return 'Ingresa un porcentaje válido';
                        if (n < 0) return 'El interés no puede ser negativo';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tasas frecuentes:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [10, 15, 20, 25, 30].map((tasa) {
                        final activa =
                            (double.tryParse(_interesCtrl.text) ?? -1) ==
                                tasa.toDouble();
                        return ChoiceChip(
                          label: Text('$tasa%'),
                          selected: activa,
                          onSelected: (_) {
                            setState(() {
                              _interesCtrl.text = tasa.toString();
                            });
                          },
                          selectedColor: const Color(0xFF0F766E),
                          labelStyle: TextStyle(
                            color: activa ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sección 3: Vencimiento
              _seccionTitulo('FECHA DE VENCIMIENTO', Icons.event_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _elegirFecha,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: Color(0xFF0F766E), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fecha límite de pago',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    _vencimiento == null
                                        ? 'Seleccionar fecha'
                                        : _fechaTexto(_vencimiento!),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Plazos rápidos:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'label': '+15 días', 'dias': 15},
                        {'label': '+30 días', 'dias': 30},
                        {'label': '+45 días', 'dias': 45},
                        {'label': '+60 días', 'dias': 60},
                      ].map((item) {
                        return ActionChip(
                          label: Text(item['label'] as String),
                          onPressed: () =>
                              _ajustarPlazoDias(item['dias'] as int),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tarjeta Resumen de Cálculo en Vivo
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Capital inicial:',
                          style:
                              TextStyle(color: Color(0xFFCCFBF1), fontSize: 13),
                        ),
                        Text(
                          'S/ ${monto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ganancia por interés (${interesPorc.toStringAsFixed(1)}%):',
                          style: const TextStyle(
                              color: Color(0xFFCCFBF1), fontSize: 13),
                        ),
                        Text(
                          '+ S/ ${ganancia.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL A COBRAR:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'S/ ${totalACobrar.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_editando) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Préstamo Pagado',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      _pagado
                          ? 'Marcado como completamente saldado'
                          : 'Pendiente de cobro',
                      style: const TextStyle(fontSize: 12),
                    ),
                    activeTrackColor: const Color(0xFF10B981),
                    value: _pagado,
                    onChanged: (v) => setState(() => _pagado = v),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _editando ? 'Guardar Cambios' : 'Registrar Préstamo',
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccionTitulo(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: const Color(0xFF0F766E)),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
