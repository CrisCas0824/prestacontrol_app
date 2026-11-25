/// URL base de la API. Cambiar UNA linea segun donde corra la API:
///
/// - Emulador de Android Studio: 'http://10.0.2.2:8090'
///   (10.0.2.2 es el localhost de tu PC visto desde el emulador).
/// - Celular fisico en la misma WiFi: 'http://TU_IP_DE_LA_PC:8090'
///   (busca tu IP con `ipconfig` en Windows, ejemplo 192.168.1.10).
/// - API publicada en Render: 'https://tu-api.onrender.com' (sin puerto).
class ApiConfig {
  static const String baseUrl = 'https://prestamoservice-api.onrender.com';
}
