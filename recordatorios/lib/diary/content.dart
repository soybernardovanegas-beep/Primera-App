/// Textos fijos del diario de 90 días. Para cambiar un compromiso, un evento o
/// una frase, basta con editarlo aquí.
library;

const programDays = 90;

const morningCommitments = [
  'Madrugar',
  'Dar tiempo real a alguien del equipo',
  'No jugar PlayStation',
  'Sin noches de café vacías',
  'Sin fiestas que resten foco',
];

const nightCommitments = [
  'Madrugué',
  'Di tiempo real al equipo',
  'Sin PlayStation',
  'Sin café vacío ni fiesta',
];

const events = ['Open de negocios', 'Academia de liderazgo', 'Ninguno'];

const morningQuote =
    'No estoy buscando la cifra. Estoy construyendo el equipo.';
const nightQuote =
    '180 no es el fracaso de 420. Es la señal de que la máquina arrancó.';

/// Pregunta del recordatorio diario; rota según el número de día.
const dailyQuestions = [
  '¿Qué es lo más importante que estoy fingiendo que no es importante?',
  '¿A quién puedo mover hoy que todavía no he llamado?',
  '¿Qué haría hoy si no tuviera miedo al rechazo?',
  '¿Estoy ocupado o estoy avanzando?',
  '¿Qué conversación estoy evitando?',
  '¿A quién del equipo le di tiempo real hoy?',
  '¿Qué excusa me conté hoy?',
  '¿Qué haría el líder que quiero ser en las próximas dos horas?',
  '¿Qué me está costando más: hacerlo o no hacerlo?',
  '¿A quién puedo presentar antes de que termine el día?',
  '¿Qué distracción me robó foco hoy?',
  '¿Qué promesa me hice esta mañana y todavía puedo cumplir?',
  '¿Quién en mi lista merece un seguimiento hoy?',
  '¿Qué pequeño paso hoy hace más fácil el día 90?',
];

String questionForDay(int day) =>
    dailyQuestions[(day - 1).clamp(0, 1 << 30) % dailyQuestions.length];
