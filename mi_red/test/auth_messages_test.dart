import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/services/auth_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sin conexión o proyecto pausado', () {
    final msg = authErrorMessage(Exception(
        "ClientException with SocketException: Failed host lookup: "
        "'ftjycrbadkdnhvjnimgz.supabase.co'"));
    expect(msg, contains('No se pudo conectar'));
    expect(msg, contains('pausado'));
  });

  test('errores de Supabase en español', () {
    expect(authErrorMessage(const AuthException('Invalid login credentials')),
        'Correo o contraseña incorrectos.');
    expect(authErrorMessage(const AuthException('Email not confirmed')),
        contains('confirmas tu correo'));
    expect(authErrorMessage(const AuthException('User already registered')),
        contains('ya tiene una cuenta'));
    expect(
        authErrorMessage(const AuthException(
            'For security purposes, you can only request this after 42 seconds.')),
        contains('Espera un minuto'));
  });

  test('un error desconocido conserva el detalle', () {
    expect(authErrorMessage(const AuthException('algo raro')),
        'No se pudo completar: algo raro');
  });

  test('el enlace de los correos usa el esquema de la app', () {
    expect(Uri.parse(authRedirectUrl).scheme, 'mired');
    expect(Uri.parse(authRedirectUrl).host, 'login-callback');
  });
}
