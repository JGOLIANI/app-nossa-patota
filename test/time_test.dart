import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:nossa_patota/core/time.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'Agenda converte horário da patota para UTC, independentemente do aparelho',
    () {
      final instant = scheduleInstant(
        DateTime(2026, 10, 8),
        20,
        0,
        'America/Sao_Paulo',
      );
      expect(instant, DateTime.utc(2026, 10, 8, 23));
      expect(matchLocalTime(instant, 'America/Manaus').hour, 19);
    },
  );
  test(
    'Não normaliza silenciosamente horários inexistentes no horário de verão',
    () {
      expect(
        () => scheduleInstant(DateTime(2026, 3, 29), 1, 30, 'Europe/Lisbon'),
        throwsStateError,
      );
    },
  );
}
