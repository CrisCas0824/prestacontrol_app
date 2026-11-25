import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prestamo.dart';
import '../services/api_exception.dart';
import '../services/prestamo_service.dart';

/// Formulario para registrar y editar un prestamo.
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
  final _interesCtrl = TextEditingController();
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
      _interesCtrl.text = p.interes.toStringAsFixed(2);
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
    final fecha = await showDatePicker(
      context: context,
      initialDate: _vencimiento ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (fecha != null) setState(() => _vencimiento = fecha);
  }

  String _fechaTexto(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vencimiento == null) {
      setState(() => _error = 'Elige la fecha de vencimiento');
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
      setState(() => _error = 'No se pudo guardar. Revisa la conexion con la API.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = () {
      final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
      final interes =
          double.tryParse(_interesCtrl.text.replaceAll(',', '.')) ?? 0;
      return monto + monto * interes / 100;
    }();
    return Scaffold(
      appBar: AppBar(
          title: Text(_editando ? 'Editar prestamo' : 'Registrar prestamo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _clienteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Cliente', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el cliente' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dniCtrl,
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'DNI (8 digitos)',
                    border: OutlineInputBorder(),
                    counterText: ''),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa el DNI';
                  if (v.length != 8) return 'El DNI debe tener 8 digitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Monto (S/)', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null) return 'Ingresa un monto valido';
                  if (n <= 0) return 'El monto debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interesCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Interes (%)', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null) return 'Ingresa un interes valido';
                  if (n < 0) return 'El interes no puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de vencimiento'),
                subtitle: Text(_vencimiento == null
                    ? 'Sin fecha'
                    : _fechaTexto(_vencimiento!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _elegirFecha,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Total a cobrar: S/ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_editando) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Pagado'),
                  value: _pagado,
                  onChanged: (v) => setState(() => _pagado = v),
                ),
              ],
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade800)),
                ),
              if (_error != null) const SizedBox(height: 16),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_editando ? 'Guardar cambios' : 'Registrar prestamo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
