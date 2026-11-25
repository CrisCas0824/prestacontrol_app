import 'package:flutter/material.dart';

import '../models/prestamo.dart';
import '../models/resumen.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/prestamo_service.dart';
import 'login_screen.dart';
import 'prestamo_form_screen.dart';

/// Lista de prestamos + resumen de cartera + filtros + busqueda.
class ListaPrestamosScreen extends StatefulWidget {
  const ListaPrestamosScreen({super.key});

  @override
  State<ListaPrestamosScreen> createState() => _ListaPrestamosScreenState();
}

class _ListaPrestamosScreenState extends State<ListaPrestamosScreen> {
  final _service = PrestamoService();
  final _auth = AuthService();
  final _searchCtrl = TextEditingController();

  List<Prestamo> _prestamos = [];
  Resumen? _resumen;
  bool _cargando = true;
  String? _error;
  bool _tokenPorVencer = false;
  DateTime? _tokenExpira;

  // 0 = Todos, 1 = Por cobrar, 2 = Cobrados
  int _tab = 0;
  String? get _estado =>
      _tab == 1 ? 'por_cobrar' : _tab == 2 ? 'cobrados' : null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.listar(
          search: _searchCtrl.text, estado: _estado);
      final resumen = await _service.resumen();
      final porVencer = await _auth.isExpiringSoon();
      final expira = await _auth.getTokenExpiry();
      if (!mounted) return;
      setState(() {
        _prestamos = lista;
        _resumen = resumen;
        _tokenPorVencer = porVencer;
        _tokenExpira = expira;
        _cargando = false;
      });
    } on UnauthorizedException {
      await _auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con la API.';
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _marcarPagado(Prestamo p) async {
    try {
      await _service.marcarPagado(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestamo marcado como pagado')));
      _cargar();
    } on UnauthorizedException {
      _cerrarSesion();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _eliminar(Prestamo p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular prestamo'),
        content: Text('Se anulara el prestamo de ${p.cliente} (${p.totalTexto}).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anular')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _service.eliminar(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestamo anulado')));
      _cargar();
    } on UnauthorizedException {
      _cerrarSesion();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _abrirFormulario([Prestamo? p]) async {
    final cambio = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PrestamoFormScreen(prestamo: p)));
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final r = _resumen;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrestaControl'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Prestar'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_tokenPorVencer && _tokenExpira != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    'Tu sesion vence a las ${_tokenExpira!.hour.toString().padLeft(2, '0')}:${_tokenExpira!.minute.toString().padLeft(2, '0')}. Vuelve a iniciar sesion pronto.',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (r != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resumen de cartera',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _filaResumen('Capital prestado',
                          'S/ ${r.capitalPrestado.toStringAsFixed(2)}'),
                      _filaResumen('Total por cobrar',
                          'S/ ${r.totalPorCobrar.toStringAsFixed(2)}'),
                      _filaResumen('Ganancia esperada',
                          'S/ ${r.gananciaEsperada.toStringAsFixed(2)}'),
                      _filaResumen('Por cobrar: ${r.porCobrar}  |  Cobrados: ${r.cobrados}  |  Morosos: ${r.morosos}',
                          ''),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o DNI',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _cargar();
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _cargar(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Todos')),
                ButtonSegment(value: 1, label: Text('Por cobrar')),
                ButtonSegment(value: 2, label: Text('Cobrados')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
                _cargar();
              },
            ),
            const SizedBox(height: 12),
            if (_cargando)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: _cargar,
                        child: const Text('Reintentar')),
                  ],
                ),
              )
            else if (_prestamos.isEmpty)
                const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay prestamos aqui todavia.',
                          textAlign: TextAlign.center),
                    ))
              else
                ..._prestamos.map((p) => Card(
                  color: p.moroso ? Colors.red.shade50 : null,
                  child: ListTile(
                    title: Text(p.cliente,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'DNI ${p.dni}  -  Vence ${p.fechaVencimientoTexto}\n'
                            'Monto ${p.montoTexto}  -  Interes ${p.interesTexto}'
                            "${p.moroso ? '\nVENCIDO SIN PAGAR' : ''}"
                            "${p.pagado ? '\nPagado' : ''}",
                        style: TextStyle(
                            color: p.moroso ? Colors.red.shade800 : null)),
                    isThreeLine: true,
                    trailing: Text(p.totalTexto,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _abrirFormulario(p),
                    leading: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) {
                        if (v == 'pagar') _marcarPagado(p);
                        if (v == 'editar') _abrirFormulario(p);
                        if (v == 'eliminar') _eliminar(p);
                      },
                      itemBuilder: (_) => [
                        if (!p.pagado)
                          const PopupMenuItem(
                              value: 'pagar',
                              child: Text('Marcar como pagado')),
                        const PopupMenuItem(
                            value: 'editar', child: Text('Editar')),
                        const PopupMenuItem(
                            value: 'eliminar', child: Text('Anular')),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta),
          if (valor.isNotEmpty)
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}