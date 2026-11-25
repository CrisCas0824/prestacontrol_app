/// Error de la API (mensaje que viene en el JSON de error).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// La API respondio 401: token ausente, alterado o vencido.
/// La app debe borrar el token y volver al login.
class UnauthorizedException extends ApiException {
  UnauthorizedException() : super('Tu sesion vencio. Vuelve a iniciar sesion.', 401);
}
