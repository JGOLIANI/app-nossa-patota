import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

DateTime matchLocalTime(DateTime instant, String timezone) =>
    tz.TZDateTime.from(instant.toUtc(), tz.getLocation(timezone));

String formatMatchTime(DateTime instant, String timezone) => DateFormat(
  "EEE, dd MMM • HH:mm",
  'pt_BR',
).format(matchLocalTime(instant, timezone));

DateTime scheduleInstant(DateTime day, int hour, int minute, String timezone) {
  final local = tz.TZDateTime(
    tz.getLocation(timezone),
    day.year,
    day.month,
    day.day,
    hour,
    minute,
  );
  if (local.hour != hour || local.minute != minute) {
    throw StateError('Este horário não existe no fuso escolhido.');
  }
  return local.toUtc();
}
