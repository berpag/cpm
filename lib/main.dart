// Versión 2.5.1
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cpm/presentation/screens/auth/auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Aseguramos la inicialización de los bindings.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Imprimimos un mensaje para saber que Firebase se inició.
  print("Firebase App inicializada con éxito.");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Organizacion Crypto',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mejoramos el manejo del estado de conexión
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Mientras Firebase decide si hay un usuario, mostramos un loader.
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData) {
          // Si hay datos de usuario (no es nulo), mostramos el portafolio.
          print("AuthGate: Usuario autenticado (UID: ${snapshot.data!.uid}). Mostrando MyHomePage.");
          return const MyHomePage();
        } else {
          // Si no hay datos (es nulo), mostramos la pantalla de login.
          print("AuthGate: No hay usuario. Mostrando AuthScreen.");
          return const AuthScreen();
        }
      },
    );
  }
}