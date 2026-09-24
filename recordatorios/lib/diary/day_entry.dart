/// Lo que se puede hacer con una persona: contactarla, presentarle o darle
/// seguimiento.
enum PersonAction { contactar, presentar, seguir }

class PersonPlan {
  String name;

  /// Lo que se planea hacer con ella en la mañana.
  PersonAction? planned;

  /// Lo que de verdad se hizo, marcado en la noche.
  Set<PersonAction> done;

  PersonPlan({required this.name, this.planned, Set<PersonAction>? done})
    : done = done ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'planned': planned?.name,
    'done': done.map((a) => a.name).toList(),
  };

  factory PersonPlan.fromJson(Map<String, dynamic> json) => PersonPlan(
    name: json['name'] as String,
    planned: _action(json['planned'] as String?),
    done: ((json['done'] as List?) ?? const [])
        .map((e) => _action(e as String))
        .whereType<PersonAction>()
        .toSet(),
  );

  static PersonAction? _action(String? name) =>
      PersonAction.values.where((a) => a.name == name).firstOrNull;
}

/// Una entrada del diario: la intención (mañana) y la cuenta (noche) de un día.
class DayEntry {
  final DateTime date;

  // Mañana — la intención
  List<PersonPlan> people;
  String? event;
  int? prospectGoal;
  String inviteNext;
  int? morningEnergy;
  Set<int> morningCommitments;
  String oneThing;
  bool morningSealed;

  // Noche — la cuenta
  int contacted;
  int presented;
  int followed;
  int? newProspects;
  String didToday;
  String followTomorrow;
  Set<int> nightCommitments;
  bool? teamMovedWithoutMe;
  int? nightEnergy;
  String fear;
  String affirmation;
  bool? addedSomeone;
  bool nightClosed;

  DayEntry({
    required DateTime date,
    List<PersonPlan>? people,
    this.event,
    this.prospectGoal,
    this.inviteNext = '',
    this.morningEnergy,
    Set<int>? morningCommitments,
    this.oneThing = '',
    this.morningSealed = false,
    this.contacted = 0,
    this.presented = 0,
    this.followed = 0,
    this.newProspects,
    this.didToday = '',
    this.followTomorrow = '',
    Set<int>? nightCommitments,
    this.teamMovedWithoutMe,
    this.nightEnergy,
    this.fear = '',
    this.affirmation = '',
    this.addedSomeone,
    this.nightClosed = false,
  }) : date = DateTime(date.year, date.month, date.day),
       people = people ?? [],
       morningCommitments = morningCommitments ?? {},
       nightCommitments = nightCommitments ?? {};

  String get key => dateKey(date);

  bool get isComplete => morningSealed && nightClosed;

  /// Si se escribió algo ese día (para no listar días vacíos en el historial).
  bool get hasContent =>
      morningSealed ||
      nightClosed ||
      people.isNotEmpty ||
      morningEnergy != null ||
      nightEnergy != null ||
      oneThing.isNotEmpty ||
      didToday.isNotEmpty;

  /// Contactos totales del día (contactadas + presentaciones + seguimientos).
  int get reach => contacted + presented + followed;

  /// Marca o desmarca en la noche una acción hecha con una persona, y ajusta
  /// el contador correspondiente.
  void toggleDone(PersonPlan person, PersonAction action) {
    final add = !person.done.contains(action);
    add ? person.done.add(action) : person.done.remove(action);
    final delta = add ? 1 : -1;
    switch (action) {
      case PersonAction.contactar:
        contacted = (contacted + delta).clamp(0, 999);
      case PersonAction.presentar:
        presented = (presented + delta).clamp(0, 999);
      case PersonAction.seguir:
        followed = (followed + delta).clamp(0, 999);
    }
  }

  Map<String, dynamic> toJson() => {
    'date': key,
    'people': people.map((p) => p.toJson()).toList(),
    'event': event,
    'prospectGoal': prospectGoal,
    'inviteNext': inviteNext,
    'morningEnergy': morningEnergy,
    'morningCommitments': morningCommitments.toList()..sort(),
    'oneThing': oneThing,
    'morningSealed': morningSealed,
    'contacted': contacted,
    'presented': presented,
    'followed': followed,
    'newProspects': newProspects,
    'didToday': didToday,
    'followTomorrow': followTomorrow,
    'nightCommitments': nightCommitments.toList()..sort(),
    'teamMovedWithoutMe': teamMovedWithoutMe,
    'nightEnergy': nightEnergy,
    'fear': fear,
    'affirmation': affirmation,
    'addedSomeone': addedSomeone,
    'nightClosed': nightClosed,
  };

  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
    date: DateTime.parse(j['date'] as String),
    people: ((j['people'] as List?) ?? const [])
        .map((e) => PersonPlan.fromJson(e as Map<String, dynamic>))
        .toList(),
    event: j['event'] as String?,
    prospectGoal: j['prospectGoal'] as int?,
    inviteNext: j['inviteNext'] as String? ?? '',
    morningEnergy: j['morningEnergy'] as int?,
    morningCommitments: _ints(j['morningCommitments']),
    oneThing: j['oneThing'] as String? ?? '',
    morningSealed: j['morningSealed'] as bool? ?? false,
    contacted: j['contacted'] as int? ?? 0,
    presented: j['presented'] as int? ?? 0,
    followed: j['followed'] as int? ?? 0,
    newProspects: j['newProspects'] as int?,
    didToday: j['didToday'] as String? ?? '',
    followTomorrow: j['followTomorrow'] as String? ?? '',
    nightCommitments: _ints(j['nightCommitments']),
    teamMovedWithoutMe: j['teamMovedWithoutMe'] as bool?,
    nightEnergy: j['nightEnergy'] as int?,
    fear: j['fear'] as String? ?? '',
    affirmation: j['affirmation'] as String? ?? '',
    addedSomeone: j['addedSomeone'] as bool?,
    nightClosed: j['nightClosed'] as bool? ?? false,
  );

  static Set<int> _ints(Object? list) =>
      ((list as List?) ?? const []).map((e) => e as int).toSet();
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
