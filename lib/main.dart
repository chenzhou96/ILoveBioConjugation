import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjunction/app.dart';
import 'package:ilovebioconjunction/data/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = SqfliteDatabase();
  await db.init();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const App(),
    ),
  );
}
