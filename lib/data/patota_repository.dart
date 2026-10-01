import '../core/models.dart';

abstract class PatotaRepository {
  String? get userId;
  String get displayName;
  Future<List<Patota>> loadPatotas();
  Future<List<MatchRoster>> loadMatches(String patotaId);
  Future<Patota> createPatota(String name, Modality modality, String timezone);
  Future<void> joinPatota(String code);
  Future<String> invitationCode(String patotaId, {bool regenerate = false});
  Future<void> createMatch(
    String patotaId,
    DateTime startsAt,
    String venue,
    int capacity,
  );
  Future<void> respond(String matchId, bool going);
}
