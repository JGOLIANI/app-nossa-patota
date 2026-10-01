import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:nossa_patota/app/app.dart';
import 'package:nossa_patota/app/app_state.dart';
import 'package:nossa_patota/core/models.dart';
import 'package:nossa_patota/data/demo_repository.dart';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });
  testWidgets(
    'Demonstração identifica dados locais e confirma presença pela tela',
    (tester) async {
      final state = AppState(DemoRepository(), isDemo: true);
      await state.refresh();
      await tester.pumpWidget(NossaPatotaApp(state: state));
      await tester.pumpAndSettle();
      expect(find.textContaining('DEMONSTRAÇÃO'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Arena da Resenha'), 180);
      await tester.tap(find.text('Arena da Resenha'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Vou jogar'));
      await tester.tap(find.text('Vou jogar'));
      await tester.pumpAndSettle();
      expect(
        state.roster('demo-match')!.forUser(state.userId)!.status,
        AttendanceStatus.confirmed,
      );
      expect(state.roster('demo-match')!.confirmedCount, 9);
      await tester.tap(find.text('Vou jogar'));
      await tester.pumpAndSettle();
      expect(state.roster('demo-match')!.confirmedCount, 9);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
