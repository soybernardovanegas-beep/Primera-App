import 'package:supabase_flutter/supabase_flutter.dart';

/// Enlace al que vuelven los correos de Supabase (confirmar cuenta y
/// recuperar contraseña). Abre la app gracias al intent-filter "mired://"
/// del AndroidManifest. Debe estar en Supabase → Authentication → URL
/// Configuration → Redirect URLs.
const authRedirectUrl = 'mired://login-callback/';

/// Convierte los errores de inicio de sesión en mensajes claros en español.
String authErrorMessage(Object error) {
  final raw = error is AuthException ? error.message : error.toString();
  final text = raw.toLowerCase();
  if (text.contains('failed host lookup') ||
      text.contains('socketexception') ||
      text.contains('network') ||
      text.contains('connection')) {
    return 'No se pudo conectar con el servidor. Revisa tu internet. Si tienes '
        'internet, es posible que el proyecto de Supabase esté pausado: '
        'reactívalo en supabase.com.';
  }
  if (text.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (text.contains('email not confirmed')) {
    return 'Aún no confirmas tu correo. Abre el correo de confirmación que te '
        'enviamos (revisa también Spam).';
  }
  if (text.contains('already registered') || text.contains('already exists')) {
    return 'Ese correo ya tiene una cuenta. Inicia sesión o usa "¿Olvidaste tu '
        'contraseña?".';
  }
  if (text.contains('should be different')) {
    return 'La contraseña nueva debe ser distinta a la anterior.';
  }
  if (text.contains('password should be') || text.contains('weak password')) {
    return 'La contraseña es muy corta o débil. Usa al menos 6 caracteres.';
  }
  if (text.contains('security purposes') || text.contains('rate limit')) {
    return 'Hiciste varios intentos seguidos. Espera un minuto y vuelve a '
        'intentarlo.';
  }
  if (text.contains('invalid email') || text.contains('unable to validate')) {
    return 'El correo no es válido.';
  }
  if (text.contains('expired') || text.contains('invalid flow state')) {
    return 'El enlace ya venció o ya se usó. Pide uno nuevo.';
  }
  return 'No se pudo completar: $raw';
}
