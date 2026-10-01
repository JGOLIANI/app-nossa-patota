import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';
import '../data/patota_repository.dart';

class AppState extends ChangeNotifier {
  AppState(this.repository, {this.client, required this.isDemo}) {
    _authSubscription = client?.auth.onAuthStateChange.listen((event) {
      if (!isSignedIn) {
        ++_loadVersion;
        patotas = [];
        rosters = [];
        selectedPatotaId = null;
        loading = false;
        recoveringPassword = false;
        notifyListeners();
      } else if (event.event == AuthChangeEvent.passwordRecovery) {
        recoveringPassword = true;
        notifyListeners();
      } else if (event.event != AuthChangeEvent.tokenRefreshed) {
        unawaited(refresh());
      }
    });
  }
  final PatotaRepository repository;
  final SupabaseClient? client;
  final bool isDemo;
  StreamSubscription<AuthState>? _authSubscription;
  bool loading = false;
  bool recoveringPassword = false;
  String? loadError;
  List<Patota> patotas = [];
  List<MatchRoster> rosters = [];
  String? selectedPatotaId;
  bool get isSignedIn => isDemo || client?.auth.currentSession != null;
  String? get userId => repository.userId;
  Patota? get selectedPatota {
    for (final p in patotas) {
      if (p.id == selectedPatotaId) return p;
    }
    return null;
  }

  MatchRoster? roster(String id) {
    for (final r in rosters) {
      if (r.match.id == id) return r;
    }
    return null;
  }

  int _loadVersion = 0;
  Future<void> refresh() async {
    final version = ++_loadVersion;
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final groups = await repository.loadPatotas();
      final id = groups.any((p) => p.id == selectedPatotaId)
          ? selectedPatotaId
          : groups.firstOrNull?.id;
      final matches = id == null
          ? <MatchRoster>[]
          : await repository.loadMatches(id);
      if (version != _loadVersion || !isSignedIn) return;
      patotas = groups;
      selectedPatotaId = id;
      rosters = matches;
    } catch (error) {
      if (version == _loadVersion) loadError = friendlyError(error);
    } finally {
      if (version == _loadVersion) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectPatota(String id) async {
    selectedPatotaId = id;
    rosters = [];
    await refresh();
  }

  Future<void> signOut() async => client?.auth.signOut();
  void finishPasswordRecovery() {
    recoveringPassword = false;
    notifyListeners();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

String friendlyError(Object error) {
  if (error is AuthException) {
    if (error.code == 'invalid_credentials') {
      return 'E-mail ou senha incorretos.';
    }
    if (error.code == 'email_not_confirmed') {
      return 'Confirme seu e-mail antes de entrar.';
    }
    return 'Não foi possível acessar sua conta. Confira os dados e tente novamente.';
  }
  if (error is PostgrestException) {
    return switch (error.message) {
      'match_closed' => 'Esta rodada não aceita mais respostas.',
      'not_authorized' => 'Você não tem permissão para esta ação.',
      'invalid_input' => 'Confira os dados informados.',
      _ => 'Não foi possível salvar no servidor. Tente novamente.',
    };
  }
  if (error is StateError) return error.message.toString();
  return 'Não foi possível conectar. Verifique sua conexão e tente novamente.';
}
