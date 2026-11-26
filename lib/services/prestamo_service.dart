import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/prestamo.dart';
import '../models/resumen.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class PrestamoService {
  final AuthService _auth = AuthService();
  static const Duration _timeout = Duration(seconds: 30);

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
    final queryParams = <String, String>{
      'limit': '100', // Traer todos los necesarios para la vista
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (estado != null && estado.isNotEmpty) {
      queryParams['estado'] = estado;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/prestamos')
        .replace(queryParameters: queryParams);

    final res =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      List<dynamic> list;
      if (decoded is Map<String, dynamic> && decoded.containsKey('content')) {
        list = decoded['content'] as List<dynamic>;
      } else if (decoded is List<dynamic>) {
        list = decoded;
      } else {
        list = [];
      }

      var prestamos = list
          .map((e) => Prestamo.fromJson(e as Map<String, dynamic>))
          .toList();

      // Filtrado cliente adicional por seguridad y velocidad
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
        if (eUpper == 'PAGADO' || eUpper == 'PAGADOS' || eUpper == 'COBRADOS') {
          prestamos = prestamos.where((p) => p.pagado).toList();
        } else if (eUpper == 'PENDIENTE' ||
            eUpper == 'PENDIENTES' ||
            eUpper == 'POR_COBRAR') {
          prestamos = prestamos.where((p) => !p.pagado).toList();
        } else if (eUpper == 'MOROSO' || eUpper == 'MOROSOS') {
          prestamos = prestamos.where((p) => p.moroso).toList();
        }
      }

      return prestamos;
    }
    _revisar401(res);
  }

  Future<Resumen> resumen() async {
    // 1. Intentar llamar al endpoint nativo del backend
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/prestamos/resumen');
      final res =
          await http.get(uri, headers: await _headers()).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return Resumen.fromJson(data);
      }
    } catch (_) {
      // Si falla o no está disponible, calculamos desde la lista completa
    }

    // 2. Fallback calculado desde los datos
    final prestamos = await listar();
    final totalPrestamos = prestamos.length;
    final pagados = prestamos.where((p) => p.pagado).length;
    final pendientes = totalPrestamos - pagados;
    final morosos = prestamos.where((p) => p.moroso).length;

    double capitalPrestado = 0.0;
    double totalPorCobrar = 0.0;
    double gananciaEsperada = 0.0;

    for (final p in prestamos) {
      capitalPrestado += p.monto;
      if (!p.pagado) {
        totalPorCobrar += p.totalACobrar;
        gananciaEsperada += (p.totalACobrar - p.monto);
      }
    }

    return Resumen(
      capitalPrestado: capitalPrestado,
      totalPorCobrar: totalPorCobrar,
      gananciaEsperada: gananciaEsperada,
      cantidadPrestamos: totalPrestamos,
      porCobrar: pendientes,
      cobrados: pagados,
      morosos: morosos,
    );
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
