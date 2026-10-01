import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import 'patota_repository.dart';

class SupabasePatotaRepository implements PatotaRepository {
  SupabasePatotaRepository(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  String get displayName =>
      client.auth.currentUser?.userMetadata?['display_name'] as String? ??
      'Jogador';

  @override
  Future<List<Patota>> loadPatotas() async {
    final rows = await client
        .from('patota_members')
        .select('role, patotas(id, name, modality, timezone)')
        .eq('user_id', userId!)
        .eq('status', 'active');
    return rows.map((row) {
      final p = row['patotas'] as Map<String, dynamic>;
      return Patota(
        id: p['id'] as String,
        name: p['name'] as String,
        modality: Modality.values.byName(p['modality'] as String),
        timezone: p['timezone'] as String,
        role: row['role'] as String,
      );
    }).toList();
  }

  @override
  Future<List<MatchRoster>> loadMatches(String patotaId) async {
    final rows = await client
        .from('matches')
        .select(
          '*, match_attendances(player_id, status, queue_position, players(user_id, display_name))',
        )
        .eq('patota_id', patotaId)
        .order('starts_at');
    return rows
        .map(
          (row) => MatchRoster(
            Match(
              id: row['id'] as String,
              patotaId: row['patota_id'] as String,
              startsAt: DateTime.parse(row['starts_at'] as String).toUtc(),
              timezone: row['timezone'] as String,
              venue: row['venue'] as String,
              capacity: row['capacity'] as int,
              status: row['status'] as String,
            ),
            (row['match_attendances'] as List).map((a) {
              final player = a['players'] as Map<String, dynamic>;
              return Attendance(
                playerId: a['player_id'] as String,
                userId: player['user_id'] as String?,
                name: player['display_name'] as String,
                status: AttendanceStatus.parse(a['status'] as String),
                queuePosition: (a['queue_position'] as num?)?.toInt(),
              );
            }).toList(),
          ),
        )
        .toList();
  }

  @override
  Future<Patota> createPatota(
    String name,
    Modality modality,
    String timezone,
  ) async {
    final id = await client.rpc(
      'create_patota',
      params: {
        'p_name': name.trim(),
        'p_modality': modality.name,
        'p_timezone': timezone,
      },
    ) as String;
    return Patota(
      id: id,
      name: name.trim(),
      modality: modality,
      timezone: timezone,
      role: 'admin',
    );
  }

  @override
  Future<void> joinPatota(String code) async {
    final id = await client.rpc(
      'join_patota_by_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    if (id == null) {
      throw StateError(
        'Código inválido ou limite de tentativas atingido. Tente mais tarde.',
      );
    }
  }

  @override
  Future<String> invitationCode(
    String patotaId, {
    bool regenerate = false,
  }) async => await client.rpc(
    'patota_invitation_code',
    params: {'p_patota_id': patotaId, 'p_regenerate': regenerate},
  ) as String;
  @override
  Future<void> createMatch(
    String patotaId,
    DateTime startsAt,
    String venue,
    int capacity,
  ) async {
    await client.rpc(
      'schedule_match',
      params: {
        'p_patota_id': patotaId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_venue': venue.trim(),
        'p_capacity': capacity,
      },
    );
  }

  @override
  Future<void> respond(String matchId, bool going) async {
    await client.rpc(
      'respond_to_match',
      params: {
        'p_match_id': matchId,
        'p_going': going,
        'p_request_id': const Uuid().v4(),
      },
    );
  }
}
