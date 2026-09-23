import '../models/contact.dart';

/// Mensajes sugeridos para WhatsApp según la etapa y el enfoque del
/// contacto. Son plantillas fijas (sin IA ni costos); el usuario puede
/// editarlas antes de enviar.
class MessageTemplate {
  const MessageTemplate(this.title, this.text, {this.stages, this.interests});

  final String title;
  final String text;

  /// Etapas en las que aplica (null = todas).
  final Set<Stage>? stages;

  /// Enfoques en los que aplica (null = todos).
  final Set<Interest>? interests;

  bool appliesTo(Contact c) =>
      (stages == null || stages!.contains(c.stage)) &&
      (interests == null || interests!.contains(c.interest));
}

const _producto = {Interest.cliente, Interest.ambos};
const _negocio = {Interest.socio, Interest.ambos};

const messageTemplates = [
  MessageTemplate(
    'Primer contacto: producto',
    'Hola {nombre} 😊 ¿Cómo estás? Hace rato no hablábamos. Estoy usando unos '
        'productos que me han ayudado mucho con mi energía y bienestar y me '
        'acordé de ti. ¿Te puedo contar en una llamada corta?',
    stages: {Stage.nuevo},
    interests: _producto,
  ),
  MessageTemplate(
    'Primer contacto: negocio',
    'Hola {nombre}, ¿cómo vas? Estoy empezando un proyecto de negocio con una '
        'empresa muy seria y pensé en ti porque eres una persona emprendedora. '
        '¿Tienes 15 minutos esta semana para contarte?',
    stages: {Stage.nuevo},
    interests: _negocio,
  ),
  MessageTemplate(
    'Invitar a presentación',
    'Hola {nombre} 🙌 Me gustaría mostrarte en persona lo que te comenté, son '
        '20 minutos y creo que te va a gustar. ¿Te queda mejor el martes o el '
        'jueves?',
    stages: {Stage.contactado},
  ),
  MessageTemplate(
    'Con su porqué: ingresos',
    'Hola {nombre}, me quedé pensando en lo que me contaste: {porque_ingresos}. '
        'Justamente por eso creo que esto te puede servir. ¿Lo hablamos con '
        'calma esta semana?',
    stages: {Stage.contactado, Stage.presentacion, Stage.seguimiento},
    interests: _negocio,
  ),
  MessageTemplate(
    'Con su porqué: salud',
    'Hola {nombre}, me acordé de lo que me dijiste: {porque_salud}. Tengo algo '
        'que te puede ayudar y me encantaría mostrártelo. ¿Cuándo tienes un '
        'ratico?',
    stages: {Stage.contactado, Stage.presentacion, Stage.seguimiento},
    interests: _producto,
  ),
  MessageTemplate(
    'Confirmar cita',
    'Hola {nombre} 👋 Te escribo para confirmar nuestra cita. ¿Seguimos en pie? '
        'Quedo atento.',
    stages: {Stage.contactado, Stage.presentacion},
  ),
  MessageTemplate(
    'Seguimiento después de la presentación',
    'Hola {nombre}, gracias por el tiempo del otro día 🙏 ¿Qué fue lo que más '
        'te gustó de lo que viste? ¿Te quedó alguna duda?',
    stages: {Stage.presentacion, Stage.seguimiento},
  ),
  MessageTemplate(
    'Seguimiento: pregunta de cierre',
    'Hola {nombre} 😊 Del 1 al 10, ¿qué tan interesado quedaste? Así sé cómo '
        'ayudarte mejor.',
    stages: {Stage.seguimiento},
  ),
  MessageTemplate(
    'Retomar contacto',
    'Hola {nombre}, ¿cómo va todo? Hace un tiempo hablamos y me acordé de ti. '
        'Tengo novedades que creo que te pueden interesar. ¿Te cuento?',
    stages: {Stage.seguimiento, Stage.descartado, Stage.nuevo},
  ),
  MessageTemplate(
    'Cliente: ¿cómo te ha ido?',
    'Hola {nombre} 😊 ¿Cómo te ha ido con el producto? Cuéntame qué resultados '
        'has notado. ¿Te separo tu pedido de este mes?',
    stages: {Stage.cliente},
  ),
  MessageTemplate(
    'Cliente: invitar al negocio',
    'Hola {nombre}, ya que te ha gustado el producto, ¿sabías que puedes '
        'obtenerlo con descuento y además generar ingresos recomendándolo? Te '
        'cuento cuando quieras.',
    stages: {Stage.cliente},
  ),
  MessageTemplate(
    'Socio: acompañamiento',
    'Hola {nombre} 💪 ¿Cómo vas con tu lista y tus contactos de la semana? '
        '¿Hacemos una llamada a tres con alguno de tus prospectos?',
    stages: {Stage.socio},
  ),
];

/// Rellena los marcadores de una plantilla con los datos del contacto.
String fillTemplate(MessageTemplate template, Contact contact) {
  final firstName = contact.name.trim().split(RegExp(r'\s+')).first;
  return template.text
      .replaceAll('{nombre}', firstName)
      .replaceAll(
        '{porque_ingresos}',
        contact.whyIncome.isEmpty ? 'que quieres ingresos extra' : _lower(contact.whyIncome),
      )
      .replaceAll(
        '{porque_salud}',
        contact.whyHealth.isEmpty ? 'que quieres cuidar tu salud' : _lower(contact.whyHealth),
      );
}

String _lower(String text) {
  final t = text.trim();
  if (t.isEmpty) return t;
  final noDot = t.endsWith('.') ? t.substring(0, t.length - 1) : t;
  return noDot[0].toLowerCase() + noDot.substring(1);
}

/// Plantillas que aplican al contacto; las de su porqué solo si lo tiene.
List<MessageTemplate> templatesFor(Contact contact) =>
    messageTemplates.where((t) {
      if (!t.appliesTo(contact)) return false;
      if (t.text.contains('{porque_ingresos}') && contact.whyIncome.isEmpty) {
        return false;
      }
      if (t.text.contains('{porque_salud}') && contact.whyHealth.isEmpty) {
        return false;
      }
      return true;
    }).toList();
