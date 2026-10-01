import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app.dart';
import '../../app/app_state.dart';
import '../../core/models.dart';
import '../../core/config.dart';
import '../../core/time.dart';
import '../home/screens.dart';

abstract class ActionState<T extends StatefulWidget> extends State<T> {
  bool busy = false;
  String? error;
  Future<bool> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.error,
  });
  final String title;
  final List<Widget> children;
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (AppScope.of(context).isDemo) const DemoBanner(),
              if (error != null) ErrorNotice(error!),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ActionState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool registering = false;
  String? notice;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    final client = AppScope.of(context).client!;
    await perform(() async {
      if (registering) {
        final result = await client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          emailRedirectTo: AppConfig.authRedirect,
          data: {'display_name': name.text.trim()},
        );
        if (mounted && result.session == null) {
          setState(() {
            notice = 'Confira seu e-mail para ativar a conta. Depois volte aqui para entrar.';
            registering = false;
          });
        }
      } else {
        await client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Nossa Patota',
    error: error,
    children: [
      const SizedBox(height: 24),
      const Icon(Icons.sports_soccer, size: 56),
      const SizedBox(height: 24),
      Text(
        'Sua próxima rodada\ncomeça aqui.',
        style: Theme.of(context).textTheme.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      const Text(
        'Entre para organizar a galera e confirmar presença. O básico é gratuito.',
      ),
      const SizedBox(height: 28),
      if (notice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(notice!),
        ),
      Form(
        key: _form,
        child: Column(
          children: [
            if (registering) ...[
              TextFormField(
                controller: name,
                maxLength: 60,
                autofillHints: const [AutofillHints.nickname],
                decoration: const InputDecoration(
                  labelText: 'Como a galera te chama?',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 2
                    ? 'Informe um nome com pelo menos 2 caracteres.'
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) =>
                  v != null &&
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? null
                  : 'Informe um e-mail válido.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
              obscureText: true,
              autofillHints: [
                registering
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              decoration: const InputDecoration(labelText: 'Senha'),
              validator: (v) => (v?.length ?? 0) < (registering ? 8 : 1)
                  ? 'Use uma senha com pelo menos 8 caracteres.'
                  : null,
              onFieldSubmitted: (_) {
                if (!busy) submit();
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? 'Aguarde…'
                      : registering
                      ? 'Criar conta'
                      : 'Entrar',
                ),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      registering = !registering;
                      error = null;
                      notice = null;
                    }),
              child: Text(
                registering
                    ? 'Já tenho uma conta'
                    : 'Primeira vez? Criar conta',
              ),
            ),
            if (!registering)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(email.text.trim())) {
                          setState(
                            () => error =
                                'Informe seu e-mail para recuperar a senha.',
                          );
                          return;
                        }
                        final client = AppScope.of(context).client!;
                        await perform(() async {
                          await client.auth.resetPasswordForEmail(
                            email.text.trim(),
                            redirectTo: AppConfig.authRedirect,
                          );
                          if (mounted) {
                            setState(
                              () => notice = 'Se houver uma conta com este e-mail, você receberá um link para redefinir a senha.',
                            );
                          }
                        });
                      },
                child: const Text('Esqueci minha senha'),
              ),
          ],
        ),
      ),
    ],
  );
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ActionState<ResetPasswordScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Redefinir senha',
    error: error,
    children: [
      const SizedBox(height: 24),
      const SectionTitle('Uma nova senha para sua conta'),
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Nova senha'),
              validator: (v) =>
                  (v?.length ?? 0) < 8 ? 'Use pelo menos 8 caracteres.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Repita a nova senha',
              ),
              validator: (v) =>
                  v != password.text ? 'As senhas devem ser iguais.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      final state = AppScope.of(context);
                      final ok = await perform(() async {
                        await state.client!.auth.updateUser(
                          UserAttributes(password: password.text),
                        );
                      });
                      if (ok && mounted) state.finishPasswordRecovery();
                    },
              child: Text(busy ? 'Salvando…' : 'Salvar nova senha'),
            ),
          ],
        ),
      ),
    ],
  );
}

class CreatePatotaScreen extends StatefulWidget {
  const CreatePatotaScreen({super.key});
  @override
  State<CreatePatotaScreen> createState() => _CreatePatotaScreenState();
}

class _CreatePatotaScreenState extends ActionState<CreatePatotaScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController();
  Modality modality = Modality.society;
  String timezone = 'America/Sao_Paulo';
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final ok = await perform(() async {
      final patota = await state.repository.createPatota(
        name.text,
        modality,
        timezone,
      );
      state.selectedPatotaId = patota.id;
      await state.refresh();
    });
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Criar patota',
    error: error,
    children: [
      const SizedBox(height: 16),
      const SectionTitle('Qual é a sua patota?'),
      const Text(
        'Só o essencial para reunir a galera. Você será o organizador desta patota.',
      ),
      const SizedBox(height: 24),
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nome da patota',
                hintText: 'Ex.: Resenha de quinta',
              ),
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? 'Use pelo menos 3 caracteres.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Modality>(
              initialValue: modality,
              decoration: const InputDecoration(labelText: 'Modalidade'),
              items: Modality.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => modality = v!),
            ),
            const SizedBox(height: 8),
            Text(
              '${modality.defaultCapacity} participantes sugeridos. A capacidade pode mudar em cada rodada.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: timezone,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Fuso horário da patota',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'America/Sao_Paulo',
                  child: Text('Brasília / São Paulo'),
                ),
                DropdownMenuItem(
                  value: 'America/Manaus',
                  child: Text('Manaus'),
                ),
                DropdownMenuItem(value: 'America/Belem', child: Text('Belém')),
                DropdownMenuItem(
                  value: 'America/Rio_Branco',
                  child: Text('Rio Branco'),
                ),
                DropdownMenuItem(value: 'Europe/Lisbon', child: Text('Lisboa')),
              ],
              onChanged: busy ? null : (v) => setState(() => timezone = v!),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy ? 'Criando…' : 'Criar minha patota'),
            ),
          ],
        ),
      ),
    ],
  );
}

class JoinPatotaScreen extends StatefulWidget {
  const JoinPatotaScreen({super.key});
  @override
  State<JoinPatotaScreen> createState() => _JoinPatotaScreenState();
}

class _JoinPatotaScreenState extends ActionState<JoinPatotaScreen> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (code.text.trim().length != 8) {
      setState(() => error = 'Informe um código de 8 caracteres.');
      return;
    }
    final state = AppScope.of(context);
    final ok = await perform(() async {
      await state.repository.joinPatota(code.text);
      await state.refresh();
    });
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Entrar na patota',
    error: error,
    children: [
      const SizedBox(height: 20),
      const SectionTitle('A galera está te esperando'),
      const Text(
        'Digite o código enviado pelo organizador. Você entrará como jogador, sem permissões de administração.',
      ),
      const SizedBox(height: 24),
      TextField(
        controller: code,
        maxLength: 8,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Código da patota',
          hintText: 'Ex.: K7M4X2PA',
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Entrando…' : 'Entrar na patota'),
      ),
    ],
  );
}

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});
  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ActionState<InvitationScreen> {
  String? code;
  bool requested = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested) {
      requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load({bool regenerate = false}) async {
    final state = AppScope.of(context);
    final p = state.selectedPatota;
    if (p == null || !p.isAdmin) return;
    await perform(() async {
      final result = await state.repository.invitationCode(
        p.id,
        regenerate: regenerate,
      );
      if (mounted) setState(() => code = result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).selectedPatota;
    return FormPage(
      title: 'Convidar a galera',
      error: error,
      children: [
        const SizedBox(height: 20),
        SectionTitle(p?.name ?? 'Selecione uma patota'),
        if (p?.isAdmin == true) ...[
          const Text(
            'Quem tem este código pode entrar como jogador. Compartilhe apenas com a sua galera.',
          ),
          const SizedBox(height: 24),
          SelectableText(
            code ?? 'Carregando…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 3),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy || code == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: code!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado.')),
                      );
                    }
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar código'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy || code == null
                ? null
                : () async {
                    final size = MediaQuery.sizeOf(context);
                    await perform(() async {
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Bora jogar com a ${p!.name}? No Nossa Patota, entre com o código $code.',
                          sharePositionOrigin: Rect.fromLTWH(
                            size.width / 2,
                            size.height / 2,
                            1,
                            1,
                          ),
                        ),
                      );
                    });
                  },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartilhar convite'),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Gerar novo código?'),
                        content: const Text(
                          'O código anterior deixará de aceitar entradas. Os membros atuais continuam na patota.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Gerar novo'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      await load(regenerate: true);
                    }
                  },
            child: const Text('Revogar código e gerar outro'),
          ),
          if (error != null)
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Tentar novamente'),
            ),
        ] else
          const Text('Somente o organizador pode consultar o código.'),
      ],
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ActionState<ScheduleScreen> {
  final _form = GlobalKey<FormState>();
  final venue = TextEditingController();
  final capacity = TextEditingController();
  DateTime? day;
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = AppScope.of(context).selectedPatota;
    if (p != null && day == null) {
      final today = matchLocalTime(DateTime.now(), p.timezone);
      day = DateTime(today.year, today.month, today.day + 1);
      capacity.text = p.modality.defaultCapacity.toString();
    }
  }

  @override
  void dispose() {
    venue.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final p = state.selectedPatota!;
    final ok = await perform(() async {
      final instant = scheduleInstant(day!, time.hour, time.minute, p.timezone);
      if (!instant.isAfter(DateTime.now().toUtc())) {
        throw StateError('Escolha uma data e um horário futuros.');
      }
      await state.repository.createMatch(
        p.id,
        instant,
        venue.text,
        int.parse(capacity.text),
      );
      await state.refresh();
    });
    if (ok && mounted) context.go('/agenda');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).selectedPatota;
    return FormPage(
      title: 'Marcar rodada',
      error: error,
      children: [
        if (p == null || !p.isAdmin)
          const Text('Selecione uma patota que você organiza.')
        else ...[
          const SizedBox(height: 16),
          SectionTitle(p.name),
          Text(
            'Horários no fuso ${p.timezone}. A presença fica aberta até o início da rodada.',
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: venue,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Onde vai ser?',
                    hintText: 'Nome da quadra ou campo',
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 3
                      ? 'Informe o local da rodada.'
                      : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final today = matchLocalTime(
                            DateTime.now(),
                            p.timezone,
                          );
                          final chosen = await showDatePicker(
                            context: context,
                            initialDate: day,
                            firstDate: DateTime(
                              today.year,
                              today.month,
                              today.day,
                            ),
                            lastDate: DateTime(today.year + 2),
                          );
                          if (chosen != null && mounted) {
                            setState(() => day = chosen);
                          }
                        },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy').format(day!)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final chosen = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (chosen != null && mounted) {
                            setState(() => time = chosen);
                          }
                        },
                  icon: const Icon(Icons.schedule),
                  label: Text(time.format(context)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Capacidade de jogadores',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 2 || n > 100
                        ? 'Informe entre 2 e 100 jogadores.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fila FIFO: quem confirma primeiro ocupa as vagas. Desistências promovem o próximo da fila automaticamente.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Salvando…' : 'Criar rodada'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
