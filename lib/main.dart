import 'package:flutter/material.dart';

import 'screens/lista_prestamos_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const PrestaControlApp());
}

class PrestaControlApp extends StatelessWidget {
  const PrestaControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrestaControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Sesion persistente: si hay token guardado, entra directo a la lista.
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data!
              ? const ListaPrestamosScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
