# prestacontrol_app — PrestaControl (Flutter)

App del Ejercicio 2 de la ED "Programación de una aplicación con Flutter".
Flutter (canal stable), Dart 3, Material 3. Paquetes: `http` y
`flutter_secure_storage`. Organización: `config/`, `models/`, `services/`,
`screens/`.

## Qué hace

- **Login y registro**: crea la cuenta e inicia sesión, con mensajes de error claros.
- **Sesión persistente**: el token JWT se guarda en almacenamiento seguro;
  al reabrir la app entra directo a la lista.
- **Lista de préstamos**: cliente, monto, interés, total a cobrar y fecha
  de vencimiento.
- **Registrar y editar**: formulario con cliente, DNI (8 dígitos), monto (> 0),
  interés y fecha de vencimiento, con validaciones. Muestra el total a cobrar
  mientras escribes.
- **Marcar como pagado y anular**: desde el menú de cada préstamo.
- **Cierre de sesión y token vencido**: botón de salir; si la API responde
  401, la app borra el token y vuelve al login.

Complementarias (las 4, la guía pide al menos 2 para Excelente):

1. **Resumen de cartera**: tarjeta con capital prestado, total por cobrar y
   ganancia esperada (`GET /prestamos/resumen`).
2. **Filtros y morosos**: pestañas Todos / Por cobrar / Cobrados; los
   vencidos sin pagar salen en rojo con "VENCIDO SIN PAGAR".
3. **Aviso de expiración**: lee el `exp` del token y avisa en amarillo si
   vence en menos de 30 minutos.
4. **Búsqueda**: por nombre del cliente o por DNI.

## Configurar la URL de la API

Editar UNA línea en `lib/config/api_config.dart` (`ApiConfig.baseUrl`):

| Dónde corre la API | URL |
|---|---|
| Emulador de Android Studio | `http://10.0.2.2:8090` (ya viene así) |
| Celular físico, misma WiFi | `http://TU_IP_DE_LA_PC:8090` |
| Render (publicada) | `https://tu-api.onrender.com` |

## Ejecutar

```bash
flutter pub get
flutter run            # emulador o celular por USB
```

## Instalar en el celular (APK)

```bash
flutter build apk --release
# El APK queda en build/app/outputs/flutter-apk/app-release.apk
```

## Probar que cada uno ve solo su cartera

1. Registra dos prestamistas distintos (dos emails).
2. Con el primero crea un préstamo; cierra sesión.
3. Entra con el segundo: la lista está vacía y no puede ver el préstamo del otro.
