import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/config.dart';
import 'data/demo_repository.dart';
import 'data/supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('pt_BR');
  if (!AppConfig.demoMode && !AppConfig.isConfigured) {
    runApp(const ConfigurationRequiredApp());
    return;
  }
  SupabaseClient? client;
  if (!AppConfig.demoMode) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    client = Supabase.instance.client;
  }
  final state = AppState(
    client == null ? DemoRepository() : SupabasePatotaRepository(client),
    client: client,
    isDemo: AppConfig.demoMode,
  );
  if (state.isSignedIn) await state.refresh();
  runApp(NossaPatotaApp(state: state));
}
