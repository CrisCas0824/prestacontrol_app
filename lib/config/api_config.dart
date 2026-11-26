import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// URL base de la API Spring Boot (puerto 8090).
///
/// Detecta automáticamente la plataforma:
/// - Android Emulator: 'http://10.0.2.2:8090'
/// - Windows / Desktop / Web: 'http://localhost:8090'
///
/// Si pruebas en un celular físico Android por WiFi, cambia el retorno de
/// Android a la IP local de tu PC: 'http://192.168.18.70:8090'.
class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8090';
    if (Platform.isAndroid) return 'http://10.0.2.2:8090';
    return 'http://localhost:8090';
  }

  /// Puerto configurado por defecto
  static const int port = 8090;
}
