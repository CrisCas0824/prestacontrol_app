import 'package:flutter/material.dart';

import '../models/prestamo.dart';
import '../models/resumen.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/prestamo_service.dart';
import 'login_screen.dart';
import 'prestamo_form_screen.dart';

/// Pantalla principal: Dashboard financiero, lista y administración de préstamos.
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
  String? _nombreUsuario;
  bool _cargando = true;
  String? _error;
  bool _tokenPorVencer = false;
  DateTime? _tokenExpira;

  // 0 = Todos, 1 = Por cobrar, 2 = Cobrados, 3 = Morosos
  int _tab = 0;

  String? get _estado {
    switch (_tab) {
      case 1:
        return 'por_cobrar';
      case 2:
        return 'cobrados';
      case 3:
        return 'morosos';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final nombre = await _auth.getNombre();
    if (mounted) setState(() => _nombreUsuario = nombre);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.listar(
        search: _searchCtrl.text,
        estado: _estado,
      );
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
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo conectar con la API en el puerto 8090. Verifica la conexión.';
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _marcarPagado(Prestamo p) async {
    try {
      await _service.marcarPagado(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Préstamo de ${p.cliente} marcado como pagado'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _cargar();
    } on UnauthorizedException {
      _cerrarSesion();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _eliminar(Prestamo p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Anular Préstamo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Se anulará el préstamo de ${p.cliente} por ${p.totalTexto}.\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anular Préstamo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _service.eliminar(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Préstamo de ${p.cliente} anulado'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _cargar();
    } on UnauthorizedException {
      _cerrarSesion();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _abrirFormulario([Prestamo? p]) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PrestamoFormScreen(prestamo: p)),
    );
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final r = _resumen;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nombreUsuario != null && _nombreUsuario!.isNotEmpty
                  ? 'Hola, ${_nombreUsuario!}'
                  : 'PrestaControl',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const Text(
              'Gestión de Cartera & Préstamos',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar datos',
            onPressed: _cargando ? null : _cargar,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nuevo Préstamo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F766E),
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Aviso de Token próximo a expirar
            if (_tokenPorVencer && _tokenExpira != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu sesión vence a las ${_tokenExpira!.hour.toString().padLeft(2, '0')}:${_tokenExpira!.minute.toString().padLeft(2, '0')}. Vuelve a iniciar sesión pronto.',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Tarjeta Hero Dashboard (Resumen de cartera moderno)
            if (r != null) _construirHeroDashboard(r),

            const SizedBox(height: 16),

            // Barra de Búsqueda moderna
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _cargar(),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente o DNI...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF64748B), size: 22),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _cargar();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Chips Filtros de Estado
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipFiltro(
                      0, 'Todos', r?.cantidadPrestamos ?? _prestamos.length),
                  const SizedBox(width: 8),
                  _chipFiltro(1, 'Por cobrar', r?.porCobrar),
                  const SizedBox(width: 8),
                  _chipFiltro(2, 'Cobrados', r?.cobrados),
                  const SizedBox(width: 8),
                  _chipFiltro(3, 'Morosos', r?.morosos, esAlerta: true),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contenido: Cargando, Error o Lista
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                ),
              )
            else if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF475569), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _cargar,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_prestamos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined,
                          size: 48, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay préstamos para mostrar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Presiona el botón "+ Nuevo Préstamo" para registrar el primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._prestamos.map((p) => _construirTarjetaPrestamo(p)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // Tarjeta Hero Dashboard
  Widget _construirHeroDashboard(Resumen r) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL POR COBRAR',
                style: TextStyle(
                  color: Color(0xFF99F6E4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${r.cantidadPrestamos} préstamos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r.totalPorCobrarTexto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Capital Prestado',
                      style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.capitalPrestadoTexto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ganancia Estimada',
                      style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.gananciaEsperadaTexto,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Chip de filtro interactivo
  Widget _chipFiltro(int index, String titulo, int? conteo,
      {bool esAlerta = false}) {
    final seleccionado = _tab == index;
    final colorTexto = seleccionado
        ? Colors.white
        : esAlerta && conteo != null && conteo > 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF475569);

    final colorFondo = seleccionado
        ? (esAlerta ? const Color(0xFFEF4444) : const Color(0xFF0F766E))
        : Colors.white;

    final colorBorde = seleccionado
        ? Colors.transparent
        : esAlerta && conteo != null && conteo > 0
            ? const Color(0xFFFCA5A5)
            : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: () {
        setState(() => _tab = index);
        _cargar();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorBorde),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: TextStyle(
                color: colorTexto,
                fontSize: 13,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (conteo != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: seleccionado
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$conteo',
                  style: TextStyle(
                    color: seleccionado ? Colors.white : colorTexto,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tarjeta moderna de préstamo
  Widget _construirTarjetaPrestamo(Prestamo p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.moroso
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
          width: p.moroso ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrirFormulario(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Avatar + Nombre y DNI + Estado Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar con iniciales
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: p.pagado
                          ? const Color(0xFFDCFCE7)
                          : p.moroso
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFCCFBF1),
                      child: Text(
                        p.iniciales,
                        style: TextStyle(
                          color: p.pagado
                              ? const Color(0xFF15803D)
                              : p.moroso
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nombre y DNI
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.cliente,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined,
                                  size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'DNI ${p.dni}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Badge de Estado
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.pagado
                            ? const Color(0xFFDCFCE7)
                            : p.moroso
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.estadoTexto,
                        style: TextStyle(
                          color: p.pagado
                              ? const Color(0xFF15803D)
                              : p.moroso
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF0369A1),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Menú de 3 puntos
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'pagar') _marcarPagado(p);
                        if (v == 'editar') _abrirFormulario(p);
                        if (v == 'eliminar') _eliminar(p);
                      },
                      itemBuilder: (_) => [
                        if (!p.pagado)
                          const PopupMenuItem(
                            value: 'pagar',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 18, color: Color(0xFF10B981)),
                                SizedBox(width: 8),
                                Text('Marcar Pagado'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 18, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Anular',
                                  style: TextStyle(color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Fila Inferior: Detalles Financieros y Vencimiento
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Columna: Préstamo e Interés
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Monto: ${p.montoTexto}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${p.interesTexto}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: p.moroso
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.tiempoRestanteTexto,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: p.moroso
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: p.moroso
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Columna: Total a Cobrar destacado
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total a Cobrar',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Text(
                          p.totalTexto,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: p.pagado
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0F766E),
                          ),
                        ),
                      ],
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
