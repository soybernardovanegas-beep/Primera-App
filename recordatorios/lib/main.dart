import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/reminders_screen.dart';
import 'services/notification_service.dart';
import 'services/reminder_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await NotificationService.instance.init();

  final store = ReminderStore();
  await store.load();
  store.resync();

  runApp(RecordatoriosApp(store: store));
}

class RecordatoriosApp extends StatelessWidget {
  final ReminderStore store;

  const RecordatoriosApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorios',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEF6C00)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF6C00),
          brightness: Brightness.dark,
        ),
      ),
      home: RemindersScreen(store: store),
    );
  }
}
