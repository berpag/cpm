// Versión 1.5
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/dashboard/dashboard_screen.dart';

// --- NUEVAS IMPORTACIONES ---
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// ----------------------------

// La función 'main' ahora necesita ser 'async' porque la inicialización de Firebase
// es una operación asíncrona (toma un momento).
Future<void> main() async {
  // Asegúrate de que todos los bindings de Flutter estén listos antes de ejecutar código nativo.
  WidgetsFlutterBinding.ensureInitialized();
  
  // ¡EL PASO CLAVE!
  // Inicializamos Firebase usando el archivo 'firebase_options.dart' que generamos.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        primarySwatch: Colors.purple,
      ),
      // El 'home' ahora es const porque MyHomePage lo es.
      home: const MyHomePage(), 
    );
  }
}