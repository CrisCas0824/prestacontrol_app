import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

/// Autenticacion: registro, login, token en almacenamiento seguro.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _emailKey = 'email';
  static const _nombreKey = 'nombre';
  static const _expiresKey = 'token_expires_at';
  static const Duration _timeout = Duration(seconds: 60);

  Future<void> register(String nombre, String email, String password) async {
    try {
      final res = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
        }),
      )
          .timeout(_timeout);
      await _guardarSiOk(res, emailFallback: email, nombreFallback: nombre);
    } on TimeoutException {
      throw ApiException(
        'El servidor en Render tardó demasiado en responder. Intenta de nuevo.',
        408,
      );
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final res = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(_timeout);
      await _guardarSiOk(res, emailFallback: email);
    } on TimeoutException {
      throw ApiException(
        'El servidor en Render tardó demasiado en responder. Intenta de nuevo.',
        408,
      );
    }
  }

  Future<void> _guardarSiOk(
      http.Response res, {
        String emailFallback = '',
        String nombreFallback = '',
      }) async {
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _storage.write(key: _tokenKey, value: data['token'] as String);
      await _storage.write(
        key: _emailKey,
        value: (data['email'] as String?) ?? emailFallback,
      );
      await _storage.write(
        key: _nombreKey,
        value: (data['nombre'] as String?) ?? nombreFallback,
      );
      await _storage.write(
        key: _expiresKey,
        value: '${data['expiresAt'] ?? ''}',
      );
      return;
    }
    throw ApiException(_mensajeError(res), res.statusCode);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Future<String?> getNombre() => _storage.read(key: _nombreKey);

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nombreKey);
    await _storage.delete(key: _expiresKey);
  }

  /// Fecha de expiracion del token (del 'exp' del JWT o del expiresAt guardado).
  Future<DateTime?> getTokenExpiry() async {
    final guardado = await _storage.read(key: _expiresKey);
    if (guardado != null && guardado.isNotEmpty) {
      final ms = int.tryParse(guardado);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final token = await getToken();
    if (token == null) return null;
    try {
      final partes = token.split('.');
      if (partes.length != 3) return null;
      final payload = jsonDecode(utf8.decode(
          base64Url.decode(base64Url.normalize(partes[1]))))
      as Map<String, dynamic>;
      final exp = payload['exp'] as num?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Avisa si el token vence en menos de 30 minutos.
  Future<bool> isExpiringSoon() async {
    final exp = await getTokenExpiry();
    if (exp == null) return false;
    return exp.difference(DateTime.now()).inMinutes < 30;
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
    if (res.statusCode == 401) return 'Email o contrasena incorrectos.';
    if (res.statusCode == 409) return 'Ese email ya esta registrado.';
    return 'Error ${res.statusCode}. Revisa que la API este encendida.';
  }
}
