enum Modality {
  futsal('Futsal', 10),
  society('Society', 14),
  campo('Campo', 22);

  const Modality(this.label, this.defaultCapacity);
  final String label;
  final int defaultCapacity;
}

class Patota {
  const Patota({
    required this.id,
    required this.name,
    required this.modality,
    required this.timezone,
    required this.role,
  });
  final String id;
  final String name;
  final Modality modality;
  final String timezone;
  final String role;
  bool get isAdmin => role == 'admin';
}

class Match {
  const Match({
    required this.id,
    required this.patotaId,
    required this.startsAt,
    required this.timezone,
    required this.venue,
    required this.capacity,
    this.status = 'scheduled',
  });
  final String id;
  final String patotaId;
  final DateTime startsAt;
  final String timezone;
  final String venue;
  final int capacity;
  final String status;
  bool get isOpen => status == 'scheduled' && startsAt.isAfter(DateTime.now());
}

enum AttendanceStatus {
  invited('Sem resposta'),
  confirmed('Confirmado'),
  declined('Não vai'),
  waitlisted('Na fila'),
  cancelled('Cancelado'),
  attended('Participou'),
  noShow('Não compareceu');

  const AttendanceStatus(this.label);
  final String label;
  String get databaseValue => this == noShow ? 'no_show' : name;
  static AttendanceStatus parse(String value) =>
      values.firstWhere((s) => s.databaseValue == value, orElse: () => invited);
}

class Attendance {
  const Attendance({
    required this.playerId,
    required this.userId,
    required this.name,
    required this.status,
    this.queuePosition,
  });
  final String playerId;
  final String? userId;
  final String name;
  final AttendanceStatus status;
  final int? queuePosition;
}

class MatchRoster {
  const MatchRoster(this.match, this.attendances);
  final Match match;
  final List<Attendance> attendances;
  int get confirmedCount => attendances
      .where(
        (a) =>
            a.status == AttendanceStatus.confirmed ||
            a.status == AttendanceStatus.attended,
      )
      .length;
  int get waitingCount =>
      attendances.where((a) => a.status == AttendanceStatus.waitlisted).length;
  int get vacancies =>
      (match.capacity - confirmedCount).clamp(0, match.capacity);
  Attendance? forUser(String? userId) {
    for (final attendance in attendances) {
      if (attendance.userId == userId) return attendance;
    }
    return null;
  }
}
