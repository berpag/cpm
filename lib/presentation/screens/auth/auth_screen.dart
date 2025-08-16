// Versión 2.3
// lib/presentation/screens/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _message; // Cambiamos a un mensaje genérico para feedback
  bool _isError = true; // Para saber si el mensaje es de error o de éxito

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  String _translateErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Las credenciales son incorrectas. Por favor, revisa tu correo y contraseña, o regístrate si aún no tienes una cuenta.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado. ¿Deseas iniciar sesión?';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Debe tener al menos 6 caracteres.';
      default:
        return 'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.';
    }
  }

  Future<void> _register() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _message = null; });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isError = true;
        _message = _translateErrorMessage(e.code);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _message = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isError = true;
        _message = _translateErrorMessage(e.code);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ¡NUEVA FUNCIÓN PARA RESTABLECER CONTRASEÑA! ---
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _isError = true;
        _message = 'Por favor, introduce tu correo electrónico para restablecer la contraseña.';
      });
      return;
    }

    if (!mounted) return;
    setState(() { _isLoading = true; _message = null; });
    try {
      // Llamamos a la función de Firebase para enviar el correo.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      // Mostramos un mensaje de éxito.
      setState(() {
        _isError = false; // No es un error, es un mensaje informativo
        _message = 'Se ha enviado un enlace para restablecer tu contraseña a $email. ¡Revisa tu correo!';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isError = true;
        _message = _translateErrorMessage(e.code);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autenticación'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _register,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Registrarse'),
                ),
              ],
              
              // --- ¡NUEVO BOTÓN DE TEXTO PARA RESTABLECER! ---
              TextButton(
                onPressed: _resetPassword,
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              
              // Mostramos un mensaje de error o de éxito si existe.
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  // El color del texto dependerá si es un error o un mensaje de éxito.
                  style: TextStyle(color: _isError ? Colors.red : Colors.green, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}