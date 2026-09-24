import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'diary/diary_store.dart';
import 'diary/history_screen.dart';
import 'diary/progress_screen.dart';
import 'diary/today_screen.dart';
import 'screens/reminders_screen.dart';
import 'services/notification_service.dart';
import 'services/reminder_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await NotificationService.instance.init();

  final reminders = ReminderStore();
  final diary = DiaryStore();
  await Future.wait([reminders.load(), diary.load()]);
  reminders.resync();
  diary.scheduleQuestions();

  runApp(RecordatoriosApp(reminders: reminders, diary: diary));
}

class RecordatoriosApp extends StatelessWidget {
  final ReminderStore reminders;
  final DiaryStore diary;

  const RecordatoriosApp({
    super.key,
    required this.reminders,
    required this.diary,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorios',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(),
      home: HomeScreen(reminders: reminders, diary: diary),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ReminderStore reminders;
  final DiaryStore diary;

  const HomeScreen({super.key, required this.reminders, required this.diary});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _tabs = ['Hoy', 'Progreso', 'Historial', 'Avisos'];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) widget.diary.flush();
    if (state == AppLifecycleState.resumed) {
      // Al volver otro día, "Hoy" y las preguntas deben ponerse al día.
      setState(() {});
      widget.diary.scheduleQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(store: widget.diary),
      ProgressScreen(store: widget.diary),
      HistoryScreen(store: widget.diary),
      RemindersScreen(store: widget.reminders),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (final (i, label) in _tabs.indexed)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style:
                            labelStyle(
                              color: i == _tab
                                  ? AppColors.accent
                                  : AppColors.muted,
                              size: 12,
                            ).copyWith(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
