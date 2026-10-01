import '../core/models.dart';
import 'patota_repository.dart';

/// Dados fictícios e temporários, isolados do backend.
class DemoRepository implements PatotaRepository {
  DemoRepository() {
    _patotas.add(
      const Patota(
        id: 'demo-patota',
        name: 'Resenha de quinta',
        modality: Modality.society,
        timezone: 'America/Sao_Paulo',
        role: 'admin',
      ),
    );
    final match = Match(
      id: 'demo-match',
      patotaId: 'demo-patota',
      startsAt: DateTime.now().toUtc().add(const Duration(days: 2)),
      timezone: 'America/Sao_Paulo',
      venue: 'Arena da Resenha',
      capacity: 10,
    );
    _matches.add(
      MatchRoster(match, [
        for (var i = 0; i < 8; i++)
          Attendance(
            playerId: 'player-$i',
            userId: 'user-$i',
            name: [
              'Rafa',
              'Lucas',
              'Bia',
              'Pedro',
              'Marina',
              'Dudu',
              'João',
              'Caio',
            ][i],
            status: AttendanceStatus.confirmed,
          ),
        const Attendance(
          playerId: 'demo-player',
          userId: 'demo-user',
          name: 'Você',
          status: AttendanceStatus.invited,
        ),
      ]),
    );
    _codes['demo-patota'] = 'DEMO2026';
  }
  final _patotas = <Patota>[];
  final _matches = <MatchRoster>[];
  final _codes = <String, String>{};
  int _sequence = 0;
  @override
  String get userId => 'demo-user';
  @override
  String get displayName => 'Jogador de demonstração';
  @override
  Future<List<Patota>> loadPatotas() async => List.of(_patotas);
  @override
  Future<List<MatchRoster>> loadMatches(String patotaId) async =>
      _matches.where((m) => m.match.patotaId == patotaId).toList()
        ..sort((a, b) => a.match.startsAt.compareTo(b.match.startsAt));
  @override
  Future<Patota> createPatota(
    String name,
    Modality modality,
    String timezone,
  ) async {
    final p = Patota(
      id: 'demo-${++_sequence}',
      name: name,
      modality: modality,
      timezone: timezone,
      role: 'admin',
    );
    _patotas.add(p);
    _codes[p.id] = 'DEMO${_sequence.toString().padLeft(4, '0')}';
    return p;
  }

  @override
  Future<void> joinPatota(String code) async {
    if (!_codes.containsValue(code.trim().toUpperCase())) {
      throw StateError('Código não encontrado na demonstração.');
    }
  }

  @override
  Future<String> invitationCode(
    String patotaId, {
    bool regenerate = false,
  }) async {
    if (regenerate) {
      _codes[patotaId] = 'DEMO${(++_sequence).toString().padLeft(4, '0')}';
    }
    return _codes[patotaId]!;
  }

  @override
  Future<void> createMatch(
    String patotaId,
    DateTime startsAt,
    String venue,
    int capacity,
  ) async {
    final p = _patotas.firstWhere((p) => p.id == patotaId);
    _matches.add(
      MatchRoster(
        Match(
          id: 'match-${++_sequence}',
          patotaId: patotaId,
          startsAt: startsAt,
          timezone: p.timezone,
          venue: venue,
          capacity: capacity,
        ),
        const [
          Attendance(
            playerId: 'demo-player',
            userId: 'demo-user',
            name: 'Você',
            status: AttendanceStatus.invited,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> respond(String matchId, bool going) async {
    final index = _matches.indexWhere((m) => m.match.id == matchId);
    final roster = _matches[index];
    if (!roster.match.isOpen) {
      throw StateError('Esta rodada não aceita respostas.');
    }
    final current = roster.forUser(userId)!;
    if (going &&
        [
          AttendanceStatus.confirmed,
          AttendanceStatus.waitlisted,
        ].contains(current.status)) {
      return;
    }
    final others = roster.attendances.where((a) => a.userId != userId).toList();
    final hasSpace =
        others.where((a) => a.status == AttendanceStatus.confirmed).length <
        roster.match.capacity;
    final waiting = others
        .where((a) => a.status == AttendanceStatus.waitlisted)
        .length;
    final status = !going
        ? AttendanceStatus.declined
        : hasSpace && waiting == 0
        ? AttendanceStatus.confirmed
        : AttendanceStatus.waitlisted;
    others.add(
      Attendance(
        playerId: current.playerId,
        userId: userId,
        name: current.name,
        status: status,
        queuePosition: status == AttendanceStatus.waitlisted
            ? waiting + 1
            : null,
      ),
    );
    if (!going && current.status == AttendanceStatus.confirmed && waiting > 0) {
      final first = others.indexWhere(
        (a) => a.status == AttendanceStatus.waitlisted,
      );
      final promoted = others[first];
      others[first] = Attendance(
        playerId: promoted.playerId,
        userId: promoted.userId,
        name: promoted.name,
        status: AttendanceStatus.confirmed,
      );
    }
    var position = 0;
    final normalized = others
        .map(
          (a) => Attendance(
            playerId: a.playerId,
            userId: a.userId,
            name: a.name,
            status: a.status,
            queuePosition: a.status == AttendanceStatus.waitlisted
                ? ++position
                : null,
          ),
        )
        .toList();
    _matches[index] = MatchRoster(roster.match, normalized);
  }
}
