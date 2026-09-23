import 'package:flutter/material.dart';

/// Guías de trabajo que trae la app. El usuario puede editarlas; su versión
/// se guarda en Supabase (tabla crm_guides) y reemplaza a la de aquí.
///
/// Formato: "## Título" para secciones, "- " para viñetas y el resto como
/// párrafos. En los guiones, {nombre} se reemplaza por el nombre del
/// contacto y {mi_porque} por tu porqué.
class Guide {
  const Guide(this.key, this.title, this.icon, this.defaultContent);

  final String key;
  final String title;
  final IconData icon;
  final String defaultContent;
}

const guideObjeciones = Guide(
  'objeciones',
  'Objeciones',
  Icons.shield_outlined,
  '''
Escuchar, validar y preguntar. Nunca discutas: una objeción es una pregunta disfrazada. Usa la fórmula "Siento, sentí, encontré": entiendo cómo te sientes, yo también me sentí así, y encontré que...

## "No tengo tiempo"
Te entiendo, justamente por eso te lo muestro. Esto se trabaja en los tiempos libres, de 5 a 10 horas a la semana. La pregunta es: ¿quieres seguir sin tiempo toda la vida o construir algo que te lo devuelva? ¿Qué día tienes 30 minutos libres para mostrártelo?

## "No tengo dinero"
Precisamente por eso vale la pena mirarlo. No te pido que decidas hoy, solo que conozcas la información. Hay formas de empezar con muy poco y recuperar la inversión con los primeros clientes. ¿Te parece si lo vemos con números reales?

## "Eso es una pirámide"
Qué bueno que lo preguntes, yo también lo pensé. Una pirámide no tiene producto y solo gana quien entra primero. Aquí hay un producto real que la gente consume, y cualquiera puede ganar más que quien lo invitó según su trabajo. Te muestro cómo funciona el plan y tú decides.

## "Déjame pensarlo"
¡Claro! Es una decisión importante. Para ayudarte a pensarlo bien: ¿qué parte te genera más dudas, el producto, el negocio o el dinero? Así te doy la información exacta. ¿Hablamos el [día] a las [hora]?

## "Tengo que consultarlo con mi pareja"
Me parece excelente, las decisiones importantes se toman en familia. ¿Qué tal si nos reunimos los tres? Así tu pareja escucha la información de primera mano y pueden hacer todas las preguntas.

## "No soy bueno para vender"
Yo tampoco lo era. Esto no se trata de vender, se trata de recomendar lo que usas y compartir información, como cuando recomiendas una película. Además, tendrás acompañamiento y capacitación desde el primer día.

## "Ya lo intenté y no funcionó"
Gracias por contarme. ¿Qué crees que faltó esa vez? Muchas veces es el acompañamiento o el sistema. Te muestro cómo trabajamos nosotros para que compares y decidas con información.

## "No me interesa"
Lo respeto totalmente. Solo por curiosidad, ¿es el producto o el negocio lo que no te llama? (Si es firme, agradece y pregunta: "¿Conoces a alguien a quien le podría interesar?" y pasa el contacto a "Contactar después".)
''',
);

const guideProspeccion = Guide(
  'prospeccion',
  'Prospección',
  Icons.auto_awesome_outlined,
  '''
Prospectar es seleccionar, no convencer. Tu trabajo es encontrar a las personas que ya están buscando algo más.

## Arma tu lista
- Escribe mínimo 100 nombres sin juzgar: familia, amigos, compañeros de trabajo, gym, iglesia, vecinos, clientes de tu trabajo.
- Usa el método de memoria: ¿quién te vendió tu carro? ¿quién es tu médico? ¿con quién estudiaste?
- Cárgalos en la app (Más → Importar) y califícalos con las 4 preguntas.

## Prioriza
- Empieza por los Ideales 🦈 y Potenciales 🐬 con credibilidad alta.
- Los Inciertos 🦔 no se descartan: primero construye relación.
- Meta diaria sugerida: 5 contactos nuevos, 2 presentaciones.

## La invitación
- Sé breve, con urgencia y sin dar detalles del negocio por teléfono.
- Despierta curiosidad: "Estoy empezando un proyecto y pensé en ti porque eres una persona emprendedora".
- Pide una cita concreta: "¿Te queda mejor el martes o el jueves?"
- Confirma la cita el mismo día.

## Qué NO hacer
- No expliques todo por WhatsApp o teléfono.
- No persigas: si no hay interés, agenda "Contactar después".
- No prejuzgues quién va a decir que sí.
''',
);

const guideRedes = Guide(
  'redes',
  'Redes',
  Icons.language_outlined,
  '''
Las redes sociales son una vitrina: primero te conocen, después te compran.

## Perfil
- Foto clara y sonriente, descripción que diga a quién ayudas.
- Enlace directo a tu WhatsApp.

## Qué publicar (regla 80/20)
- 80 % valor y vida: tu rutina, tus logros, consejos de salud, tu porqué, testimonios.
- 20 % producto u oportunidad.
- Historias todos los días; publicaciones 3 a 4 veces por semana.

## Ideas de contenido
- Antes y después (con permiso).
- "Un día conmigo" trabajando el negocio.
- Preguntas y encuestas en historias para generar conversación.
- Resultados de eventos y reconocimientos del equipo.

## De la red al chat
- Responde todos los comentarios y reacciones con una pregunta.
- A quien reacciona a tus historias, escríbele por privado de forma natural.
- Cada persona que muestra interés: agrégala a la app con origen "Instagram" o "Facebook".

## Mensaje de apertura
Hola {nombre}, vi que te gustó mi historia 😊 ¿Estás buscando mejorar tu salud o te llama más lo de generar ingresos extra?
''',
);

const guideSeguimiento = Guide(
  'seguimiento',
  'Seguimiento',
  Icons.schedule_outlined,
  '''
La fortuna está en el seguimiento. La mayoría de cierres llegan entre el 5.º y el 7.º contacto.

## Reglas de oro
- Haz seguimiento dentro de las 24 a 48 horas después de la presentación.
- Siempre deja agendado el próximo paso: nunca cierres una conversación sin fecha.
- Registra cada contacto en la app y crea el siguiente recordatorio.

## Preguntas de cierre
- ¿Qué fue lo que más te gustó de lo que viste?
- Del 1 al 10, ¿qué tan interesado estás?
- ¿Qué te faltaría para tomar la decisión?
- ¿Empezamos con el producto, con el negocio o con ambos?

## Si no responde
- Día 2: mensaje corto y amable.
- Día 5: comparte un testimonio o dato de valor.
- Día 10: llamada.
- Si sigue sin respuesta: "Contactar después" a 3 meses. Las circunstancias cambian.

## Tercera persona
Apóyate en tu línea de patrocinio: una llamada a tres o una reunión con alguien de más experiencia genera credibilidad y ayuda a cerrar.
''',
);

const guideGuionProducto = Guide(
  'guion_producto',
  'Guion de llamada: Producto',
  Icons.shopping_bag_outlined,
  '''
## Saludo
Hola {nombre}, ¿cómo estás? ¿Tienes un minuto?

## Conexión
Pregunta por su familia, su trabajo, su salud. Escucha más de lo que hablas.

## Puente
Te llamo porque estoy usando unos productos que me han ayudado muchísimo con mi energía y bienestar, y me acordé de ti.

## Pregunta clave
¿Cómo te has sentido últimamente con tu salud, tu energía, tu descanso?

## Invitación
Me encantaría mostrarte cómo funcionan, son 20 minutos. ¿Te queda mejor [día] o [día]?

## Cierre
Perfecto, quedamos el [día] a las [hora]. Te escribo un día antes para confirmar.
''',
);

const guideGuionNegocio = Guide(
  'guion_negocio',
  'Guion de llamada: Negocio',
  Icons.work_outline,
  '''
## Saludo
Hola {nombre}, ¿cómo estás? ¿Estás ocupado?

## Conexión
Pregunta cómo le va en el trabajo o en su negocio. Escucha si menciona falta de tiempo o de dinero.

## Puente
Estoy arrancando un proyecto de negocio con una empresa muy seria y estoy buscando personas emprendedoras. Pensé en ti.

## Mi porqué
Cuéntale en una frase por qué lo haces tú: {mi_porque}

## Pregunta clave
Si hubiera una forma de generar un ingreso extra en tus tiempos libres, ¿estarías abierto a mirarla?

## Invitación
No te lo puedo explicar bien por teléfono. ¿Nos tomamos un café el [día] o prefieres el [día]?

## Cierre
Listo, quedamos el [día] a las [hora]. Lleva la mente abierta, te va a gustar.
''',
);

const allGuides = [
  guideObjeciones,
  guideProspeccion,
  guideRedes,
  guideSeguimiento,
  guideGuionProducto,
  guideGuionNegocio,
];

Guide guideByKey(String key) => allGuides.firstWhere((g) => g.key == key);

/// Una sección de una guía: título ("## ...") y su contenido.
class GuideSection {
  const GuideSection(this.title, this.body);

  final String title;
  final String body;
}

/// Divide una guía en secciones por sus títulos "## ". El texto antes del
/// primer título queda como sección con título vacío.
List<GuideSection> parseSections(String content) {
  final sections = <GuideSection>[];
  var title = '';
  final body = StringBuffer();
  void flush() {
    final text = body.toString().trim();
    if (title.isNotEmpty || text.isNotEmpty) {
      sections.add(GuideSection(title, text));
    }
    body.clear();
  }

  for (final line in content.split('\n')) {
    if (line.startsWith('## ')) {
      flush();
      title = line.substring(3).trim();
    } else {
      body.writeln(line);
    }
  }
  flush();
  return sections;
}

/// Reemplaza los marcadores {nombre} y {mi_porque}.
String fillPlaceholders(String text, {String name = '', String myWhy = ''}) {
  final firstName = name.trim().split(RegExp(r'\s+')).first;
  return text
      .replaceAll('{nombre}', firstName)
      .replaceAll('{mi_porque}', myWhy.isEmpty ? '(escribe tu porqué en Más → Mi perfil)' : myWhy);
}
