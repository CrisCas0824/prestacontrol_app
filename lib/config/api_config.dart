/// URL base de la API Spring Boot.
///
/// Opciones comunes segun donde pruebes la app:
/// - Emulador de Android Studio: 'http://10.0.2.2:8090'
///   (10.0.2.2 es el localhost de tu PC visto desde el emulador de Android).
/// - Celular fisico en tu red WiFi: 'http://192.168.18.70:8090'
///   (la IP local de tu PC en la red Wi-Fi actual).
/// - En la misma PC (Windows / Web / Desktop): 'http://localhost:8090'
/// - Servidor en la nube (Render / VPS): 'https://tu-api.onrender.com'
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:8090';

  /// Puerto y host configurados por defecto
  static const int port = 8090;
}
