import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/prestamo.dart';
import '../models/resumen.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class PrestamoService {
  final AuthService _auth = AuthService();
  static const Duration _timeout = Duration(seconds: 60);

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    if (token == null) throw UnauthorizedException();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Never _revisar401(http.Response res) {
    if (res.statusCode == 401) throw UnauthorizedException();
    throw ApiException(_mensajeError(res), res.statusCode);
  }

  Future<List<Prestamo>> listar({String? search, String? estado}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/prestamos');
    final res = await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      var prestamos = list
          .map((e) => Prestamo.fromJson(e as Map<String, dynamic>))
          .toList();

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        prestamos = prestamos
            .where((p) =>
        p.cliente.toLowerCase().contains(q) ||
            p.dni.toLowerCase().contains(q))
            .toList();
      }

      if (estado != null && estado.isNotEmpty) {
        final eUpper = estado.toUpperCase();
        if (eUpper == 'PAGADO' || eUpper == 'PAGADOS') {
          prestamos = prestamos.where((p) => p.pagado).toList();
        } else if (eUpper == 'PENDIENTE' || eUpper == 'PENDIENTES') {
          prestamos = prestamos.where((p) => !p.pagado).toList();
        }
      }

      return prestamos;
    }
    _revisar401(res);
  }

  Future<Resumen> resumen() async {
    final prestamos = await listar();
    final totalPrestamos = prestamos.length;
    final pagados = prestamos.where((p) => p.pagado).length;
    final pendientes = totalPrestamos - pagados;

    double montoTotal = 0.0;
    double totalCobrar = 0.0;
    double pendienteCobrar = 0.0;

    for (final p in prestamos) {
      final totalP = p.monto + (p.monto * p.interes / 100);
      montoTotal += p.monto;
      totalCobrar += totalP;
      if (!p.pagado) {
        pendienteCobrar += totalP;
      }
    }

    return Resumen.fromJson({
      'totalPrestamos': totalPrestamos,
      'pendientes': pendientes,
      'pagados': pagados,
      'montoTotal': montoTotal,
      'totalCobrar': totalCobrar,
      'pendienteCobrar': pendienteCobrar,
    });
  }

  Future<Prestamo> crear(Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('${ApiConfig.baseUrl}/prestamos'),
        headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      return Prestamo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    _revisar401(res);
  }

  Future<Prestamo> actualizar(int id, Map<String, dynamic> body) async {
    final res = await http
        .put(Uri.parse('${ApiConfig.baseUrl}/prestamos/$id'),
        headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return Prestamo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    _revisar401(res);
  }

  Future<Prestamo> marcarPagado(Prestamo p) async {
    return actualizar(p.id, p.toRequestJson(pagadoOverride: true));
  }

  Future<void> eliminar(int id) async {
    final res = await http
        .delete(Uri.parse('${ApiConfig.baseUrl}/prestamos/$id'),
        headers: await _headers())
        .timeout(_timeout);
    if (res.statusCode == 204 || res.statusCode == 200) return;
    _revisar401(res);
  }

  String _mensajeError(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['error'] is String && data['message'] == null) {
        return data['error'] as String;
      }
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
      if (data['detalles'] is Map) {
        return (data['detalles'] as Map).values.join('\n');
      }
    } catch (_) {}
    return 'Error ${res.statusCode} de la API.';
  }
}