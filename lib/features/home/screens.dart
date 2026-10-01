import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/time.dart';

class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.title,
    required this.index,
    required this.child,
  });
  final String title;
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: state.loading ? null : state.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.isDemo) const DemoBanner(),
            if (state.loading) const LinearProgressIndicator(),
            if (state.loadError != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: ErrorNotice(state.loadError!, onRetry: state.refresh),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            context.go(['/', '/agenda', '/profile'][value]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Rodadas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFFFE9AD),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: const Text(
      'DEMONSTRAÇÃO • dados fictícios, salvos só nesta sessão',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      ),
    ),
  );
}

class GroupPicker extends StatelessWidget {
  const GroupPicker({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.patotas.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      initialValue: state.selectedPatotaId,
      key: ValueKey(state.selectedPatotaId),
      decoration: const InputDecoration(
        labelText: 'Sua patota',
        prefixIcon: Icon(Icons.groups_outlined),
      ),
      items: state.patotas
          .map(
            (p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: state.loading
          ? null
          : (id) {
              if (id != null) state.selectPatota(id);
            },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.selectedPatota;
    final upcoming = state.rosters.where((r) => r.match.isOpen).firstOrNull;
    return PageShell(
      title: 'Nossa Patota',
      index: 0,
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PatotaTheme.ink,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sports_soccer, color: Color(0xFFCDF47A)),
                      SizedBox(width: 8),
                      Text(
                        'O JOGO COMEÇA AQUI',
                        style: TextStyle(
                          color: Color(0xFFCDF47A),
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Menos lista.\nMais futebol.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Organize a rodada, confirme presença e reúna sua patota.',
                    style: TextStyle(color: Color(0xFFD5E2D9), fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCDF47A),
                      foregroundColor: PatotaTheme.ink,
                    ),
                    onPressed: () => context.push(
                      p?.isAdmin == true ? '/schedule' : '/create-patota',
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      p?.isAdmin == true
                          ? 'Marcar rodada'
                          : 'Criar minha patota',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (state.patotas.isNotEmpty) ...[
              const GroupPicker(),
              const SizedBox(height: 12),
              Text(
                '${p!.modality.label} • ${p.timezone}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              const SectionTitle('Próxima rodada'),
              if (upcoming != null)
                MatchCard(roster: upcoming)
              else
                const EmptyCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'A próxima resenha começa com uma data',
                  message: 'Ainda não há rodadas agendadas nesta patota.',
                ),
              if (p.isAdmin) ...[
                const SizedBox(height: 20),
                const SectionTitle('Reúna a galera'),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.group_add_outlined,
                      color: PatotaTheme.green,
                    ),
                    title: const Text('Convidar para a patota'),
                    subtitle: const Text('Compartilhe seu código de entrada'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => context.push('/invite'),
                  ),
                ),
              ],
            ] else if (!state.loading)
              const EmptyCard(
                icon: Icons.groups_outlined,
                title: 'Sua patota começa aqui',
                message: 'Crie um grupo ou entre com o código enviado pelo organizador.',
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/create-patota'),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar patota'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/join'),
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar com código'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: PatotaTheme.green),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.roster});
  final MatchRoster roster;
  @override
  Widget build(BuildContext context) {
    final match = roster.match;
    final mine = roster.forUser(AppScope.of(context).userId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/match/${match.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_soccer, color: PatotaTheme.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formatMatchTime(match.startsAt, match.timezone),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Text(match.venue, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: roster.confirmedCount / match.capacity,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    '${roster.confirmedCount}/${match.capacity} confirmados',
                  ),
                  if (roster.waitingCount > 0)
                    Text('${roster.waitingCount} na fila'),
                  Text(
                    match.status == 'cancelled'
                        ? 'Rodada cancelada'
                        : mine?.status.label ?? 'Sem resposta',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Rodadas',
      index: 1,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const GroupPicker(),
          const SizedBox(height: 20),
          if (state.selectedPatota?.isAdmin == true) ...[
            FilledButton.icon(
              onPressed: () => context.push('/schedule'),
              icon: const Icon(Icons.add),
              label: const Text('Marcar rodada'),
            ),
            const SizedBox(height: 20),
          ],
          if (state.rosters.isEmpty && !state.loading)
            const EmptyCard(
              icon: Icons.event_outlined,
              title: 'Nenhuma rodada por aqui',
              message:
                  'Quando uma rodada for marcada, ela aparecerá nesta agenda.',
            ),
          ...state.rosters.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MatchCard(roster: r),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.id});
  final String id;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool busy = false;
  String? error;
  Future<void> respond(bool going) async {
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await state.repository.respond(widget.id, going);
      await state.refresh();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final roster = state.roster(widget.id);
    if (roster == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rodada')),
        body: const Center(
          child: Text('Rodada indisponível. Volte à agenda e atualize.'),
        ),
      );
    }
    final match = roster.match;
    final mine = roster.forUser(state.userId);
    final entries = List<Attendance>.of(roster.attendances)
      ..sort((a, b) {
        if (a.status == AttendanceStatus.waitlisted &&
            b.status == AttendanceStatus.waitlisted) {
          return (a.queuePosition ?? 0).compareTo(b.queuePosition ?? 0);
        }
        return a.status.index.compareTo(b.status.index);
      });
    return Scaffold(
      appBar: AppBar(
        title: const Text('A rodada'),
        actions: [
          IconButton(
            tooltip: 'Atualizar presença',
            onPressed: busy ? null : state.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (state.isDemo) const DemoBanner(),
            const SizedBox(height: 16),
            Text(
              match.venue,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(formatMatchTime(match.startsAt, match.timezone)),
            Text(
              'Horário da patota • ${match.timezone}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Metric('${roster.confirmedCount}', 'confirmados'),
                ),
                Expanded(child: _Metric('${roster.vacancies}', 'vagas')),
                Expanded(child: _Metric('${roster.waitingCount}', 'na fila')),
              ],
            ),
            const SizedBox(height: 20),
            if (state.loadError != null)
              ErrorNotice(state.loadError!, onRetry: state.refresh),
            if (error != null) ErrorNotice(error!),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Você vem?'),
                    Text(
                      mine?.status == AttendanceStatus.waitlisted
                          ? 'Você está na fila • posição ${mine?.queuePosition ?? "–"}'
                          : mine?.status.label ??
                                'Sua presença ainda não foi confirmada.',
                    ),
                    const SizedBox(height: 16),
                    if (match.isOpen) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : () => respond(true),
                            icon: const Icon(Icons.check),
                            label: Text(
                              busy
                                  ? 'Salvando…'
                                  : roster.vacancies == 0 &&
                                        mine?.status !=
                                            AttendanceStatus.confirmed
                                  ? 'Entrar na fila'
                                  : 'Vou jogar',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => respond(false),
                            icon: const Icon(Icons.close),
                            label: const Text('Não vou'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ao lotar, as confirmações entram na fila. Uma desistência promove o próximo automaticamente.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ] else
                      const Text(
                        'A rodada está encerrada para novas respostas.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('A galera'),
            ...entries.map(
              (a) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: const Icon(Icons.person_outline),
                  ),
                  title: Text(a.name),
                  subtitle: Text(
                    a.status == AttendanceStatus.waitlisted
                        ? '${a.status.label} • posição ${a.queuePosition ?? "–"}'
                        : a.status.label,
                  ),
                  trailing: a.userId == state.userId
                      ? const Chip(label: Text('Você'))
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Meu perfil',
      index: 2,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(
            radius: 40,
            child: Icon(Icons.person_outline, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            state.repository.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          const EmptyCard(
            icon: Icons.sports_soccer,
            title: 'Toda história começa na primeira rodada',
            message: 'Depois da primeira partida finalizada, acompanhe sua carreira e suas estatísticas por aqui.',
          ),
          const SizedBox(height: 24),
          if (!state.isDemo)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await state.signOut();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
        ],
      ),
    );
  }
}
