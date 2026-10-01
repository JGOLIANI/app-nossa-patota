# Nossa Patota

Aplicativo Android/iOS em Flutter, iniciado a partir da [especificação v1.5](docs/especificacao-v1.5.md). Primeiro corte da fundação e do fluxo de organização de rodadas; não conclui o roadmap inteiro.

## Implementado

- Início, agenda e perfil em português, com tema e navegação.
- Cadastro/login por e-mail e senha, confirmação, recuperação e sessão pelo Supabase.
- Criação de patota com modalidade Futsal/Society/Campo e fuso IANA.
- Entrada autenticada por código aleatório de 8 caracteres, rotação só por admin e compartilhamento nativo.
- Agendamento com capacidade de 2 a 100 jogadores, horário UTC e snapshot das regras.
- Presença gratuita, fila FIFO e promoção automática após desistência.
- RPCs transacionais, autorização no banco, RLS, auditoria e idempotência de comandos por UUID.
- Demonstração local identificada, sem credenciais e sem persistência entre execuções.

As escolhas iniciais e pendências estão em [decisões](docs/decisoes.md). Times, estatísticas, recorrência, visitantes, financeiro, push, Superwall e WhatsApp/Pix pertencem às próximas etapas da especificação.

## Executar

Versão utilizada: **Flutter 3.47.5 / Dart 3.13.4**, fixada em `.flutter-version`, com dependências em `pubspec.lock`.

Com Flutter e um dispositivo/emulador:

```sh
flutter pub get --enforce-lockfile
flutter run --dart-define=DEMO_MODE=true
```

No cloud, use o checkout existente, sem criar worktree:

```sh
cd /workspace/app-nossa-patota
bash scripts/setup.sh
bash scripts/flutter.sh test --no-pub
bash scripts/flutter.sh build apk --debug --target-platform android-arm64 --dart-define=DEMO_MODE=true
```

O modo padrão é demonstração. O banner identifica os dados fictícios. “Resenha de quinta”, seus jogadores e o código `DEMO2026` são exemplos locais; nada é enviado ao servidor. Criar patota, agendar e responder modifica apenas a sessão em memória.

O APK é gerado em `build/app/outputs/flutter-apk/app-debug.apk`: demonstração de desenvolvimento assinada com chave debug, não destinada às lojas.

## Conectar Supabase de desenvolvimento

1. Crie um projeto separado de produção. Habilite e-mail/senha, confirmação e controles de abuso/CAPTCHA.
2. Revise e aplique `supabase/migrations/202610010001_foundation.sql`. Com a CLI autenticada:

   ```sh
   supabase link --project-ref SEU_PROJECT_REF
   supabase db push
   ```

   Use um projeto vazio ou revise conflitos antes de aplicar em banco existente. Nenhuma migração foi aplicada remotamente durante esta implementação.

3. Em Auth → URL Configuration, permita `nossapatota://login-callback`. Android/iOS registram o scheme e `supabase_flutter` processa o callback. Configure templates de e-mail e valide confirmação/recuperação nos dois sistemas.
4. Copie `config/development.example.json` para `config/development.json` e informe URL e **publishable key**. O arquivo local é ignorado pelo Git. Não use `service_role`, secret key ou chaves privadas no app.
5. Execute:

   ```sh
   flutter run --dart-define-from-file=config/development.json
   ```

No cloud, substitua `flutter` por `bash scripts/flutter.sh`. `DEMO_MODE=false` ativa o servidor. Sem configuração válida, o app mostra uma tela de configuração, sem cair silenciosamente para demonstração.

A Data API lê sob RLS. Escritas críticas usam RPC; o código da patota fica em schema privado. Presença só aparece após resposta do servidor e atualização da lista: não há confirmação otimista nem fila offline. Atualização entre aparelhos é manual pelo botão de atualizar; Realtime e push serão adicionados depois.

## Verificar

```sh
flutter analyze
flutter test
```

Os testes Flutter exercitam confirmação pela tela e conversão de fuso, incluindo horário inexistente no horário de verão.

Os testes de banco usam PostgreSQL 16 real, isolado e descartável. Simulam apenas o contrato SQL de `auth.uid()`/roles do Supabase; não validam a Data API, Auth ou e-mail do serviço hospedado. Requerem Linux x64, Node.js e npm:

```sh
bash scripts/test-db.sh
```

Verificam isolamento por RLS, papéis, entrada repetida, limite de tentativas persistente, rotação de código, replay de confirmação após desistência, rodada cancelada e **20 confirmações simultâneas para 2 vagas**, com duas desistências concorrentes e promoção FIFO.

Ferramentas e caches ficam fora do checkout. Para escolher diretórios:

```sh
PATOTA_PG_TOOLS=/tmp/patota-pg npm_config_cache=/tmp/patota-npm bash scripts/test-db.sh
```

## Builds e organização

`.github/workflows/ci.yml` prepara análise/testes, banco, build Android e build iOS para simulador em macOS. CI remota ainda não foi executada. iOS exige macOS/Xcode; assinatura e testes em aparelho continuam necessários para distribuição.

IDs provisórios: Android `br.com.nossapatota.nossa_patota`; iOS `br.com.nossapatota.nossaPatota`. Revise antes de cadastrar nas lojas. Android usa SDK 36, JDK 21 e Gradle com checksum fixado. O helper `configure-gradle-proxy.py` usa o proxy/certificado da plataforma em configuração local, mantendo TLS verificado.

```text
lib/app/                 tema, estado e rotas
lib/core/                modelos, configuração e horários
lib/data/                repositórios demo e Supabase
lib/features/home/       início, agenda, presença e perfil
lib/features/onboarding/ autenticação, patota e agendamento
supabase/migrations/     esquema, RLS e RPCs
supabase/tests/          regressões SQL e concorrência
test/                    testes Flutter
docs/                    especificação e decisões
```

Estado com `ChangeNotifier`/`InheritedNotifier`, navegação com `go_router`, acesso a dados por `PatotaRepository`. As regras concorrentes reais pertencem ao Postgres.
