# Nossa Patota — especificação de produto e implementação

**Versão:** 1.5  
**Data:** 01/10/2026  
**Status:** especificação-base para iniciar um produto mobile do zero

> **Decisões de plataforma:** aplicativo Android e iOS em Flutter/Dart; backend Supabase; paywall e compra de assinaturas mobile com Superwall. A aplicação começa do zero. A página existente no GitHub Pages é uma superfície institucional/compartilhável opcional, não o produto principal nem fonte de verdade. Este documento é uma especificação de produto e arquitetura, não um retrato do repositório atual.

## 1. Visão e princípios

O Nossa Patota deve ser a fonte oficial de presença, partidas, estatísticas e histórico da patota. O aplicativo organiza o futebol; o WhatsApp distribui links e, futuramente, oferece automação. A oportunidade de diferenciação é conectar a organização da rodada com a história esportiva real do grupo: overall que evolui com partidas, balanceamento explicável, premiações que combinam votação e desempenho e retrospectivas que criam identidade.

### Princípios de produto

1. **Presença básica é gratuita.** Cobrar pela conveniência de automação e administração, não pelo direito de participar.
2. **Uma fonte de verdade.** App, link público e WhatsApp operam sobre os mesmos registros e comandos de domínio.
3. **Explicabilidade.** Mostrar por que um time, overall ou prêmio foi calculado; permitir correção auditável.
4. **Consentimento e privacidade.** Compartilhar apenas os dados necessários; obter opt-in e respeitar opt-out de mensagens.
5. **Humano no controle.** Regras automáticas configuráveis; ações com impacto na lista, pagamentos e resultados têm histórico e desfazer/correção quando viável.
6. **Evolução por etapas.** Começar por presença, histórico confiável e compartilhamento; introduzir automação externa após validar uso e custos.

## 2. Perfis e vocabulário

- **Patota:** grupo/espaço de jogadores e administradores, unidade de cobrança Pro.
- **Organizador/admin:** configura partidas, capacidade, regras, escalações e financeiro.
- **Jogador:** confirma presença, vê dados próprios e do grupo conforme permissões, vota e registra eventos autorizados.
- **Visitante:** participante sem vínculo permanente, associado a uma partida e identificado pelo organizador.
- **Partida/rodada:** ocorrência datada; pode pertencer a uma série recorrente.
- **Presença:** estado do jogador na partida: convidado/sem resposta, confirmado, fora, espera, cancelado ou participante efetivo.
- **Pro:** assinatura da patota, não de cada jogador. Valores citados na conversa eram hipóteses de mercado, não decisão de preço.

## 3. Arquitetura-alvo

### 3.1 Plataformas e responsabilidades

```text
Flutter/Dart (Android e iOS)
  ├─ UI, navegação, domínio, câmera/galeria, share sheet e notificações locais
  ├─ supabase_flutter: Auth, Data API, Storage, Realtime e Edge Functions
  └─ SDK Flutter Superwall: paywalls, ofertas e compras das lojas
              │ HTTPS / WebSocket + chave publicável
              ▼
Supabase: Auth + Postgres/RLS + Storage + RPC + Edge Functions
              ▲
App Store / Google Play ─ Superwall/webhooks de billing ─ Edge Function
FCM/APNs ───────────────── Edge Function/serviço de notificações
GitHub Pages (opcional): site institucional e páginas mínimas de compartilhamento
```

- Flutter é o único cliente principal na primeira entrega. A web institucional pode permanecer no GitHub Pages; Flutter Web e paridade funcional web ficam fora do escopo inicial.
- `supabase_flutter` conecta o app. URL e publishable key podem estar no binário; a segurança depende de RLS e grants. `service_role` e quaisquer secrets nunca entram no cliente.
- Consultas simples podem usar a Data API sob RLS. Ações concorrentes/críticas — vaga e fila, ledger, fechamento de partida e apuração — passam por RPC transacional. Edge Functions ficam para segredos, webhooks, integrações e tarefas privilegiadas; não criar uma API monolítica.
- Realtime atualiza telas abertas e respeita autorização de leitura. Push é separado: o app registra token/preferências e serviço servidor envia por FCM/APNs. Não presumir entrega ou leitura.
- Outbox, filas e retries entram quando uma integração assíncrona precisar de entrega confiável. Mensagens externas nunca são enviadas dentro da transação de presença.
- Superwall apresenta paywalls, experimentos e compras mobile associados a produtos de App Store/Google Play. Não substitui os entitlements do produto nem a autorização do backend.
- A assinatura inicial será oferecida pelos produtos mobile configurados para App Store/Google Play no Superwall. Se houver contratação pelo site no futuro, definir separadamente como o acesso será sincronizado e revisar os requisitos aplicáveis.

### 3.2 Organização Flutter sugerida

Começar com um único app Flutter, arquitetura por feature e separação entre UI, domínio e dados. Escolher uma solução de estado/navegação e usá-la consistentemente (Riverpod e go_router são opções). Evitar microserviços e abstrações genéricas prematuras.

Usar configurações distintas para desenvolvimento, homologação e produção: project URL/publishable key do Supabase e API key pública do Superwall são valores por ambiente. Não colocar senhas, service role, chaves privadas de APNs/FCM nem segredos de provedores em `--dart-define` ou no app. Persistir sessão Auth pelo mecanismo suportado pelo `supabase_flutter`; testar retorno por deep link para magic link/OAuth e recuperação de senha. Rotação e exclusão de tokens de push são parte do ciclo da conta.

```text
lib/ app/ core/ features/{auth,patotas,partidas,presenca,times,estatisticas,
  temporadas,financeiro,assinatura,notificacoes,perfil}/ data/
supabase/ migrations/ functions/
```

### 3.3 Eventos e processamento

Os nomes de eventos são vocabulário de domínio/telemetria, não uma exigência de event sourcing. Postgres e snapshots canônicos são a fonte da verdade. Persistir outbox apenas quando uma entrega assíncrona precisar ocorrer sem perda.

`PatotaCreated`, `PatotaModalityChanged`, `PatotaJoinCodeRegenerated`, `PlayerJoined`, `PlayerProfileUpdated`, `MatchScheduled`, `MatchUpdated`, `AttendanceOpened`, `AttendanceChanged`, `WaitlistPromoted`, `MatchCapacityReached`, `TeamsGenerated`, `TeamVisualIdentityChanged`, `MatchStarted`, `MatchActionRecorded`, `MatchFinished`, `AwardVoteOpened`, `AwardVoteCast`, `AwardsCalculated`, `SeasonStarted`, `SeasonClosed`, `AchievementUnlocked`, `RecordSet`, `PaymentDueCreated`, `PaymentRecorded`, `PaymentReversed`, `ShareLinkCreated`, `PlayerMatchCardGenerated`, `RecapGenerated`, `RecapPublished`, `NotificationRequested`, `NotificationSent`, `NotificationDelivered`, `NotificationFailed`, `WhatsAppOptInChanged`, `SubscriptionChanged`.

Não emitir evento de negócio para cada leitura. Para qualquer job futuro: idempotência, retry limitado, erro sanitizado e revalidação de estado antes do envio.

## 4. Modelo de dados sugerido

IDs UUID; datas em UTC e fuso IANA da patota; valores financeiros em centavos inteiros e moeda explícita. Criar o esquema com migrações SQL versionadas; usar constraints e chaves estrangeiras além das validações de interface.

| Entidade | Campos centrais e regras |
|---|---|
| `patotas` | `id`, `name`, `modality`, `join_code_hash`/código normalizado, `timezone`, `settings` (preferir colunas tipadas para regras críticas), `created_by`, `created_at`; modalidade e código de entrada têm regras próprias |
| `profiles` | perfil mínimo vinculado 1:1 a `auth.users`; dados de perfil separados de papéis/permissões; nunca usar `user_metadata` para autorização |
| `patota_members` | `patota_id`, `user_id`, `role`, `status`, `joined_at`; único por patota/usuário |
| `players` | identidade esportiva por membro: `id`, `patota_id`, `user_id` nullable para visitante, `display_name`, `position`, `base_rating`, `is_goalkeeper`, `active` |
| `match_series` | regras de recorrência, local e horário padrão; gera partidas concretas, não substitui instâncias |
| `matches` | `id`, `patota_id`, `series_id`, `starts_at`, `timezone`, `venue`, `capacity`, `status`, `attendance_opens_at`, `attendance_closes_at`, `rules_snapshot` |
| `match_attendances` | `match_id`, `player_id`, `status`, `responded_at`, `source`, `queue_position`, `version`; único por partida/jogador |
| `team_generations` / `team_assignments` | versão, parâmetros, resultado, explicação, autor, timestamp e identidade visual publicada (`team_label`, `color_token`/cor); uma geração publicada e histórico de re-gerações |
| `match_stats` | `match_id`, `player_id`, `team_id`, minutos, gols, assistências, defesas, cartões e outros indicadores habilitados |
| `match_actions` | eventos observáveis com autor, minuto, tipo, envolvidos e correção/reversão; trilha de gols/cartões/substituições |
| `award_votes` | rodada, eleitor, categoria, escolhido; um voto por eleitor/categoria, janela e elegibilidade |
| `award_results` | categoria, vencedor, componentes/pesos, contagens e desempate; resultado congelado após publicação |
| `player_rating_snapshots` | partida/data, overall, componentes, versão de fórmula; permite evolução e auditoria |
| `seasons`, `season_matches`, `season_player_totals` | período e snapshot de regras; tabela agregada pode ser reconstruída |
| `achievements`, `player_achievements` | definição versionada e concessão única por jogador/temporada quando aplicável |
| `rivalries` / `rivalry_stats` | par de jogadores/equipes, período opcional e métricas deriváveis |
| `financial_accounts`, `dues`, `payments`, `ledger_entries` | obrigação, vencimento, pagador, valor, estado; ledger imutável com reversões, não sobrescrita |
| `share_links` | token aleatório/hash, recurso, escopo, expiração, revogação, limite de uso; não conter PII no token |
| `notification_preferences` | canais, categorias, consentimento, opt-out e timestamps por membro |
| `automation_rules` | gatilho, filtros, ação/template, janela, ativo, versão, limite/frequência |
| `notification_jobs`, `message_deliveries` | agendamento, dedupe key, provider id, estado, tentativas, erro sanitizado e timestamps |
| `domain_outbox`, `consumer_receipts`, `audit_log` | publicação confiável, idempotência por consumidor e auditoria de ação sensível |
| `subscriptions`, `entitlements`, `usage_counters` | plano, patota beneficiária, comprador, product/store IDs, IDs de transação, estado, período, eventos recebidos e permissões calculadas; sincronizar por evento verificado e idempotente do Superwall/lojas |
| `push_devices` | `user_id`, token FCM/APNs, plataforma, timestamps, último uso e revogação; token legível apenas por serviço autorizado |
| `generated_share_cards` / `recap_snapshots` | recurso (`player_match`, `match`, `season`, `player_year`, `patota_year`), período, versão, payload derivado, template, dono/escopo, status e timestamps; reconstruíveis dos dados canônicos e versionados para preservar o que foi compartilhado |
| `product_analytics_events` | telemetria de funil separada dos eventos de domínio: evento, sessão/usuário quando consentido, patota, origem/campanha, variante de experimento, timestamp e propriedades minimizadas; não é fonte de verdade de negócio |
| `organizer_dashboard_snapshots` | projeção operacional da próxima rodada: confirmações, fila, convidados, pendências financeiras, saldo, alertas e ações recomendadas; reconstruível a partir dos dados canônicos |
| `service_offers`, `service_requests`, `service_bookings` | oferta/demanda de goleiro, jogador, árbitro, churrasqueiro ou outro serviço habilitado; localização aproximada, data, valor, estado, prestador, contratante e regras de cancelamento |
| `pix_payment_requests`, `payment_provider_events` | cobrança Pix opcional, QR Code/copia-e-cola, identificador externo, expiração, status, webhook recebido, conciliação e vínculo com `dues`/`payments`; nunca guardar segredo do provedor no cliente |

Preferir estatísticas canônicas por partida e snapshots versionados. Não tornar agregado materializado a única fonte de verdade.

## 5. Contratos de domínio no Supabase

Não haverá servidor REST próprio no primeiro corte. A Data API serve CRUD permitido por RLS; RPCs Postgres implementam mutações atômicas; Edge Functions integram terceiros e recebem webhooks. Os nomes são conceitos de domínio, não endpoints obrigatórios.

| Operação | Implementação inicial | Garantias |
|---|---|---|
| Criar/editar rodada | Data API com RLS; RPC se a operação tocar invariantes relacionadas | associação e papel admin validados no banco |
| Responder presença / fila | RPC transacional `respond_to_match` | capacidade/fila atômicas e idempotentes; nunca exceder vagas |
| Gerar/publicar times | código Dart inicialmente ou RPC conforme necessidade; persistir algoritmo, seed e alterações manuais | roster autorizado e geração auditável/reprodutível |
| Registrar ação/fechar partida | RPCs de domínio | partida/ator autorizados; fechamento e recálculo coerentes |
| Votar/apurar | tabela sob RLS + RPC de fechamento/apuração | unicidade, prazo e elegibilidade impostos no banco |
| Links/card/retrospectiva | renderização no app; Edge Function só se precisar de segredo ou link público seguro | token aleatório/hash, escopo mínimo, validade e revogação |
| Patota/código | CRUD sob RLS + RPC de entrada/regeneração com proteção contra abuso | associação criada atomicamente; código não dá acesso irrestrito |
| Financeiro | RPCs para ledger e reversão | admin autorizado; reversão compensatória auditável |
| Push | Edge Function e jobs/tokens privados quando necessários | consentimento, preferências, deduplicação e limpeza de tokens inválidos |
| WhatsApp/Pix futuros | Edge Functions isoladas para webhooks/chamadas externas | segredo servidor, assinatura, idempotência e revisão operacional |
| Projeções/painel | SQL/views/RPC; job apenas para cálculo longo | escopo de leitura protegido e reconstrução possível |
| Marketplace | CRUD/transições com RLS/RPC; integrações isoladas em Edge Function | autorização por ação, auditoria e privacidade mínima |

Habilitar RLS em cada tabela exposta pela Data API e escrever políticas específicas para cada operação, escopadas pela associação e papel da patota. `authenticated` sozinho não autoriza acesso. RPC `SECURITY DEFINER` deve ser exceção estreita, com `search_path` fixo, grants explícitos, acesso público revogado e validação interna de `auth.uid()` e escopo. Nunca incluir `service_role`/secret key no app. SQL, grants, RLS, RPCs e Edge Functions devem ser versionados.

## 6. Especificações por feature

Cada bloco inclui objetivo, experiência, regras, dados, eventos, operação Supabase, interface, mensagens, aceite, dependências, riscos e sequência. Referências a endpoint em features herdadas significam uma operação equivalente de Data API, RPC ou Edge Function, conforme a seção 5; não pressupõem servidor REST próprio.

### 6.1 Presença e agenda de partidas

- **Objetivo:** substituir a lista editada manualmente no grupo por uma agenda confiável e uma confirmação fácil.
- **Experiência:** organizador cria rodada avulsa ou série; jogador abre app ou link, escolhe “Vou”/“Não vou” e vê contagem e estado atual. Admin edita data/local/capacidade e pode convidar jogadores.
- **Regras:** estados claros (`invited`, `confirmed`, `declined`, `waitlisted`, `cancelled`, `attended`, `no_show`); só membro elegível ou visitante autorizado responde; alteração concorrente usa versão/ordem do servidor; fechar/cancelar a partida bloqueia nova resposta ou exige reabertura registrada. Roster fechado não equivale a comparecimento: presença efetiva é confirmada no dia.
- **Dados/modelo:** `matches`, `match_series`, `match_attendances`, estados e fonte da resposta; registrar ator e timestamps. Série gera instâncias com fuso e exceções individuais.
- **Eventos:** `MatchScheduled`, `AttendanceOpened`, `AttendanceChanged`, `MatchUpdated`, `MatchCancelled`.
- **Supabase (RPC/Data API/Edge Function):** criar/editar rodada e operação RPC idempotente de resposta; leitura paginada da lista; controle de autorização de visitante.
- **Telas:** calendário/agenda, detalhe da rodada, confirmação rápida, formulário de rodada, lista de confirmados e histórico.
- **Notificações:** push opt-in para convite/alteração; compartilhamento manual inicial; WhatsApp automático opcional em etapa futura.
- **Aceite:** uma resposta ativa por jogador/partida; contador coincide com registros; repetição do mesmo comando não duplica; jogador sem acesso à patota não altera presença; rodada cancelada mostra motivo e impede confirmação.
- **Dependências:** identidade de jogador, associação à patota, timezone e política de convidados.
- **Riscos:** contas duplicadas, jogador sem smartphone/conta, edições simultâneas e mudanças tardias. Suportar admin lançar presença com autoria e preservar auditoria.
- **Implementação:** primeiro CRUD e presença autenticada; depois link com onboarding simples; por último recorrência e convites externos controlados.

### 6.2 Fila de espera e capacidade

- **Objetivo:** preencher desistências sem o organizador reorganizar manualmente a lista.
- **Experiência:** ao lotar a rodada, próximas confirmações entram na fila com posição visível. Cancelamento libera vaga e promove o próximo; jogador recebe aviso e confirma dentro de uma janela configurável.
- **Regras:** aquisição de vaga e fila são transacionais; posição baseada em `queue_entered_at` e sequência monotônica. Definir janela de aceite; se expirar, passa ao próximo. Respeitar critérios de prioridade explícitos (ex.: mensalista), apenas se patota habilitar, com explicação e trilha. Limite de vagas não inclui recusados. Evitar promoção silenciosa se exige aceite.
- **Dados:** capacidade em `matches`; status e posição/fila; `promotion_deadline`, prioridade e histórico de transições.
- **Eventos:** `MatchCapacityReached`, `WaitlistJoined`, `WaitlistPromoted`, `PromotionExpired`, `AttendanceChanged`.
- **Supabase (RPC/Data API/Edge Function):** operação transacional `respond`; worker de expiração; RPC administrativa para ajustar capacidade e repriorizar com auditoria.
- **Telas:** badge “fila — posição N”, estimativa não garantida, aviso de vaga e prazo de resposta; painel admin de fila.
- **Notificações:** push e, no Pro, WhatsApp transacional mediante opt-in; mensagem contém prazo e link individual protegido.
- **Aceite:** nunca há mais confirmações do que capacidade, salvo override admin explícito; duas desistências concorrentes não promovem duas pessoas para uma vaga; expiração promove a pessoa seguinte uma única vez.
- **Dependências:** presença, worker/scheduler e política de prioridade.
- **Riscos:** atraso de entrega, jogador confirmar por outro canal e janela injusta. Revalidar vaga no clique e oferecer confirmação direta pelo link.
- **Implementação:** fila FIFO confiável; então janela/automação; depois prioridades configuráveis, sempre visíveis.

### 6.3 Balanceamento dinâmico e explicável de times

- **Objetivo:** gerar equipes equilibradas que melhorem à medida que a patota acumula histórico real.
- **Experiência:** admin seleciona jogadores disponíveis, posições/restrições e tamanho; recebe times, diferença prevista e explicação (“goleiros distribuídos”, “força estimada”); pode travar pares ou trocar manualmente e comparar alternativas.
- **Regras:** incluir apenas presentes elegíveis; dividir goleiros, equilibrar soma/variância de ratings e cobertura posicional; ponderações configuráveis/versionadas. Usar forma e estatísticas com amostra mínima e encolhimento para o rating-base. Evitar premiar quantidade de jogos ou punir posição por dados faltantes. Seed e algoritmo ficam salvos; correção manual é explícita e não altera histórico do rating. Nunca prometer equilíbrio perfeito.
- **Dados:** posição, goleiro, base rating/autoavaliação, snapshots overall, métricas recentes, geração, seed, parâmetros, travas, trocas e atribuições.
- **Eventos:** `TeamsGenerated`, `TeamAssignmentOverridden`, `MatchStarted`.
- **Supabase (RPC/Data API/Edge Function):** função de geração determinística/versionada no servidor; operação de publicação e re-geração; retorno com breakdown agregado sem expor fórmula sensível além do necessário.
- **Telas:** seletor de participantes, configuração de times, cartões comparáveis, explicação e confirmação/publicação.
- **Notificações:** push ou compartilhamento dos times; WhatsApp Pro pode publicar mensagem após admin aprovar.
- **Aceite:** mesmo roster, seed e versão produzem o mesmo resultado; cada jogador aparece uma vez; respeita quantidade e goleiros/restrições; tela mostra diferença e critérios; edição manual fica auditada.
- **Dependências:** posições, ratings e registro de partidas; não bloquear sorteio básico sem histórico.
- **Riscos:** viés por poucos jogos, manipulação de rating e percepção de “caixa-preta”. Mostrar incerteza e permitir modo aleatório/transparente como alternativa.
- **Implementação:** algoritmo determinístico balanceando rating-base; acumular snapshots; adicionar forma recente/amostra mínima; testar fairness com dados sintéticos e reais antes de tornar padrão.

### 6.4 Carreira, perfil esportivo e overall

- **Objetivo:** transformar a participação continuada em uma carreira legível e divertida, com força estimada que melhora com evidência.
- **Experiência:** perfil mostra overall (0–100), tendência, partidas, forma recente, gols/assistências, posição, prêmios e trajetória. Informar “amostra pequena” quando aplicável; permitir ao jogador corrigir dados do perfil e contestar estatística.
- **Regras:** overall é específico da patota (não comparar automaticamente entre grupos); combinar base administrativa/autoavaliação calibrada com desempenho e participação. Fórmula inicial da análise competitiva considerava nível base, aproveitamento, últimas cinco partidas, gols, assistências, participações, vitórias e derrotas — isso é hipótese, não peso validado. Normalizar por minutos/posição, limitar extremos, usar janela/amostra mínima, publicar versão da fórmula. Não inferir habilidade individual só de vitória da equipe. Mostrar componente, direção e explicação.
- **Dados:** `players`, appearances, stats, `player_rating_snapshots`, formula version e opt-out de exposição pública.
- **Eventos:** `PlayerProfileUpdated`, `MatchFinished`, `PlayerRatingRecalculated`, `AchievementUnlocked`.
- **Supabase (RPC/Data API/Edge Function):** leitura de perfil e série histórica; recalculador idempotente após finalização/correção de jogo; operação administrativa de contestação.
- **Telas:** cartão do jogador, gráfico de evolução, resumo da rodada, privacidade do perfil.
- **Notificações:** resumo opcional de evolução; evitar spam após todo recálculo; publicação em grupo apenas por regra habilitada.
- **Aceite:** histórico de snapshots reproduzível por versão; ajuste/correção gera novo snapshot e trilha, sem apagar o anterior; estatísticas corrigidas atualizam overall; privacidade escolhida é aplicada a perfil e links públicos.
- **Dependências:** histórico íntegro, posições, reconciliação de partidas e consentimento de exibição.
- **Riscos:** constrangimento, disputa de nota, incentivo a estatística individual. Nomear overall como estimativa lúdica, não avaliação objetiva; opção de ocultar.
- **Implementação:** perfil e contagens confiáveis; depois fórmula simples com baseline e confiança; calibrar antes de usar no balanceamento; depois gráfico e explicações.

### 6.5 Estatísticas e jogo ao vivo

- **Objetivo:** registrar desempenho de maneira rápida, consistente e corrigível.
- **Experiência:** durante jogo, operador registra gol, assistência, defesa/cartão/substituição conforme configuração; após jogo, revisa placar e estatísticas. Jogadores consultam totais e médias.
- **Regras:** distinguir gol e gol contra; assistência opcional; evitar duplicatas; eventos têm minuto aproximado e autor; registro ao vivo pode ser corrigido com log; fechamento congela dados até reabertura admin; estatísticas contam apenas jogos finalizados e aparições confirmadas conforme política.
- **Dados:** `match_actions`, `match_stats`, equipes/roster, reverts, estado da partida. Incluir só métricas que a patota realmente quer registrar.
- **Eventos:** `MatchStarted`, `MatchActionRecorded`, `MatchActionCorrected`, `MatchFinished`, `MatchReopened`.
- **Supabase (RPC/Data API/Edge Function):** comando append/reverse, sumarização por jogador/partida, fechar/reabrir com autorização.
- **Telas:** placar ao vivo, botões grandes, feed cronológico, revisão final e páginas de estatística.
- **Notificações:** publicar placar final mediante aprovação; não enviar cada evento ao WhatsApp por padrão.
- **Aceite:** placar deriva das ações válidas; reversão recalcula projeções; partida não finalizada não afeta rankings; mudança registra autor/motivo.
- **Dependências:** roster/time e status de partida.
- **Riscos:** baixa adesão ao apontador, rede instável, dados incompletos. Permitir fila offline se app suportar e sincronização idempotente; caso contrário comunicar requisito de conexão.
- **Implementação:** gols/assistências/placar; depois outras ações; posteriormente entrada offline e análises avançadas.

### 6.6 Premiações híbridas

- **Objetivo:** reconhecer tanto o que os dados medem quanto o que a patota percebeu.
- **Experiência:** após jogo, janela de votação para Craque, Paredão e outras categorias; resultado mostra votos, indicadores usados e critério de desempate.
- **Regras:** proposta discutida: 70% votação + 30% desempenho; tratar como configuração inicial a validar. Categoria tem elegibilidade própria (ex.: goleiro para Paredão), estatística mínima e desempate determinístico. Um voto por eleitor/categoria; eleitor precisa ser participante elegível; não votar em si mesmo por padrão configurável; abstenção permitida; votação encerra em horário explícito. Estatísticas são normalizadas por posição/minutos. Resultado guarda snapshot e fórmula.
- **Dados:** categorias versionadas, votos, janela, elegibilidade, components, snapshots e resultado.
- **Eventos:** `AwardVoteOpened`, `AwardVoteCast`, `AwardVoteClosed`, `AwardsCalculated`, `AwardResultCorrected`.
- **Supabase (RPC/Data API/Edge Function):** abrir/encerrar votação, voto idempotente, apuração protegida server-side.
- **Telas:** enquete simples, status de participação sem revelar voto individual, resultado com explicação e histórico.
- **Notificações:** lembrete único de voto e divulgação opt-in após fechamento; link seguro.
- **Aceite:** eleitor não altera voto após prazo (ou alteração fica claramente permitida/configurada); resultado reproduzível; empate resolvido conforme política visível; correção de stats antes do fechamento recalcula resultado ainda não publicado.
- **Dependências:** jogo encerrado, roster, dados de estatística e privacidade.
- **Riscos:** popularidade, retaliação/brincadeira e contestação da métrica. Evitar voto público nominal; admin pode anular com justificativa e registro.
- **Implementação:** votação e categorias; cálculo híbrido simples auditável; calibrar pesos e regras por patota; painel histórico.

### 6.7 Temporadas

- **Objetivo:** agrupar rodadas em ciclos que deem contexto a rankings e retrospectivas.
- **Experiência:** admin inicia temporada com nome e datas; jogadores acompanham tabela, forma e metas; encerramento gera resumo e preserva a temporada como histórico.
- **Regras:** partidas pertencem a no máximo uma temporada ativa por competição/patota; decidir elegibilidade de jogos atrasados, jogos cancelados e estatísticas corrigidas. Fechamento produz snapshot; reabrir requer motivo e mantém versão anterior.
- **Dados:** `seasons`, regras versionadas, relação de partidas, totais calculáveis e snapshot de fechamento.
- **Eventos:** `SeasonStarted`, `MatchAssignedToSeason`, `SeasonClosed`, `SeasonReopened`.
- **Supabase (RPC/Data API/Edge Function):** gestão de temporada; consulta de tabela; job idempotente de encerramento/reconstrução.
- **Telas:** overview, classificação, jogadores, calendário e resumo final.
- **Notificações:** início/fim e retrospectiva compartilhável por opt-in.
- **Aceite:** totais conferem com jogos elegíveis; mudança de regra não reinterpreta silenciosamente temporada encerrada; cancelamento não soma pontos.
- **Dependências:** estatísticas e partidas finalizadas.
- **Riscos:** regras complexas e dados tardios. Começar por temporada manual e pontos simples.
- **Implementação:** ciclos com datas; depois tabelas/objetivos; então snapshots e retrospectiva.

### 6.8 Recordes e rivalidades

- **Objetivo:** revelar narrativas do grupo sem transformar provocações em assédio.
- **Experiência:** tela mostra recordes (mais gols, sequência de vitórias, jogos, defesas), comparações amigáveis entre jogadores/equipes escolhidos e narrativas históricas adicionais quando houver dados suficientes, como maior placar, maior jejum de gols, duplas com mais jogos/vitórias juntas e confrontos diretos.
- **Regras:** definir cada métrica, elegibilidade, mínimo de jogos e tratamento de empate; derivar de dados canônicos; comparação entre pares só dentro da mesma patota e com consentimento/configuração; ocultar por privacidade e oferecer reportar/ocultar rivalidade.
- **Dados:** definições versionadas, snapshots/cache, preferências de exposição, pares consentidos e agregados opcionais de parceria/confronto reconstruíveis do histórico.
- **Eventos:** `RecordSet`, `RivalryMilestoneReached`, `PrivacyPreferenceChanged`.
- **Supabase (RPC/Data API/Edge Function):** leitura de ranking e comparação; recalculador pós-jogo.
- **Telas:** hall de recordes, confronto direto e configurações de visibilidade.
- **Notificações:** notificações de marco limitadas e desligáveis.
- **Aceite:** cálculo reproduzível; empate refletido corretamente; jogador oculto não aparece em página/compartilhamento público; usuário pode desligar comparações.
- **Dependências:** histórico e controles de privacidade.
- **Riscos:** métricas incompletas, provocação indesejada e exposição. Tom leve e opt-out por jogador/patota.
- **Implementação:** recordes objetivos; adicionar comparações consentidas; por último notificações e conteúdo social.

### 6.9 Sistema de milestones e conquistas progressivas

- **Objetivo:** transformar estatísticas e participação continuada em progresso visível, celebrando marcos esportivos dentro da própria patota sem incentivar comportamento tóxico ou distorcer o jogo.
- **Experiência:** o perfil mostra conquistas já desbloqueadas, progresso até o próximo milestone e, quando aplicável, nível/faixa da conquista. Exemplo: “Artilheiro — 42/50 gols (84%)”. Ao atingir um marco, o jogador recebe uma celebração e pode gerar um card compartilhável usando a infraestrutura social já existente.
- **Categorias iniciais de milestones:** gols (`1, 10, 25, 50, 100, 250`), assistências (`1, 10, 25, 50, 100, 250`), jogos (`1, 10, 25, 50, 100, 250, 500`), vitórias (`1, 10, 25, 50, 100, 250`), Craque da Rodada/prêmios equivalentes (`1, 5, 10, 25, 50`) e vitórias consecutivas (`3, 5, 10, 15, 20`). Os valores são configuração inicial a validar e devem ser versionados, não constantes espalhadas pelo cliente.
- **Milestones de goleiro:** habilitar jogos como goleiro, defesas, clean sheets ou outros marcos específicos somente quando essas métricas forem efetivamente registradas de forma confiável. Não inferir clean sheet ou defesa quando o modelo de dados não suportar a informação.
- **Acumulativos vs. sequências:** gols, assistências, jogos, vitórias e prêmios são acumulativos e não regridem por uso normal; podem mudar após correção dos dados canônicos. Sequências mantêm ao menos `current_streak` e `best_streak`; uma partida que interrompa o critério encerra a sequência atual, preservando a melhor marca histórica.
- **Contexto:** milestones pertencem à relação jogador–patota. “100 gols” significa 100 gols válidos naquela patota; não somar automaticamente estatísticas entre grupos diferentes.
- **Regras:** critérios determinísticos, versionados e recalculáveis a partir de partidas finalizadas e dados canônicos. Não conceder por pagamento. Evitar metas que estimulem ausência de fair play, manipulação de estatísticas ou presença quando o jogador deveria se ausentar. Correções de partida podem conceder ou revogar um milestone, preservando motivo, versão e trilha de auditoria.
- **Progressão:** mostrar marco atual, próximo marco, valor atual, valor-alvo e progresso percentual/barra. Quando todos os marcos configurados de uma categoria forem atingidos, exibir a maior conquista alcançada sem inventar um próximo objetivo infinito.
- **Dados/modelo:** reutilizar `achievements` para definição/versionamento dos marcos e `player_achievements` para concessões. A definição deve suportar `metric`, `threshold`, `category`, `level`, `formula_version`/`definition_version` e escopo por patota. Progresso corrente deve ser derivável das estatísticas; cache/projeção é permitido, mas não vira fonte de verdade. Para streaks, manter projeção reconstruível de `current_streak` e `best_streak`.
- **Eventos:** reutilizar `MatchFinished`, `MatchReopened`, `AchievementUnlocked`, `AchievementRevoked` e eventos de correção já existentes. Não emitir evento para cada visualização ou atualização cosmética da barra. Se no futuro consumidores externos precisarem reagir ao progresso intermediário, avaliar `MilestoneProgressed` somente com necessidade comprovada.
- **Supabase (RPC/Data API/Edge Function):** consulta de catálogo/conquistas do jogador e progresso para o próximo marco; avaliador idempotente acionado após fechamento/correção de partida; reconstrução administrativa por jogador/patota; operação de geração de card reutiliza o mecanismo de cards/compartilhamento existente.
- **Telas:** perfil do jogador com seção “Milestones”, categorias e barras de progresso; detalhe da conquista com critérios e histórico; celebração de desbloqueio; card social do milestone. Não depender apenas de cor para comunicar nível ou progresso.
- **Compartilhamento/notificações:** desbloqueios relevantes podem gerar push opt-in. O jogador escolhe se deseja compartilhar. O card pode incluir nome de exibição, patota, milestone, marca atingida e identidade visual permitida, respeitando privacidade e as mesmas regras dos cards pós-partida.
- **Fluxo integrado:** `Partida → estatísticas → progresso → milestone → card → compartilhamento → perfil/carreira`. O milestone não mantém uma segunda contagem independente de gols, assistências, jogos ou vitórias.
- **Aceite:** reprocessar a mesma partida não duplica concessões; progresso confere com dados canônicos; correção retroativa recalcula milestones; streak atual e melhor streak são reproduzíveis; jogador não recebe milestone de métrica não registrada; milestones permanecem isolados por patota; privacidade impede exposição em cards públicos quando configurada.
- **Dependências:** partidas finalizadas, estatísticas confiáveis, identidade jogador–patota, premiações publicadas quando usadas como métrica, infraestrutura de cards/share e controles de privacidade.
- **Riscos:** inflação de badges, competição excessiva, manipulação de apontamentos, marcos pouco significativos e frustração por correções. Priorizar poucos milestones compreensíveis, mostrar origem da métrica, permitir contestação pelos fluxos existentes e calibrar thresholds com uso real.
- **Implementação:** começar por jogos, gols, assistências e vitórias acumulativas; adicionar vitórias consecutivas; integrar Craque da Rodada quando a premiação estiver estável; depois cards compartilháveis e categorias específicas por posição. Medir antes de criar editor genérico de milestones.

### 6.10 Retrospectiva da rodada, temporada e ano

- **Objetivo:** fechar ciclos esportivos e sociais com uma narrativa compartilhável, preservando o histórico da patota em diferentes períodos.
- **Experiência:** além do resumo da rodada/temporada, no encerramento do ano o app oferece duas experiências: **Meu Ano na Patota**, individual, e **Ano da Patota**, coletiva. O jogador percorre uma sequência vertical de cards no estilo Stories/Wrapped e pode compartilhar cards específicos ou a sequência suportada pela plataforma.
- **Meu Ano na Patota:** pode apresentar partidas, gols, assistências, vitórias, prêmios, evolução de overall, melhores sequências e curiosidades pessoais. Só incluir métricas realmente registradas e comparáveis no período; não fabricar ranking ou narrativa quando a amostra for insuficiente.
- **Ano da Patota:** pode apresentar número de partidas e participantes, gols, artilharia, assistências, prêmios, recordes, sequências e destaques coletivos. Rankings e destaques obedecem às regras de elegibilidade/privacidade já definidas nas features de estatísticas, recordes e premiações.
- **Regras:** usar apenas partidas encerradas e resultados publicados; período anual é explícito no fuso da patota (por padrão ano civil, salvo configuração futura). Estatística ausente é “não registrada”, nunca zero. Dados individuais respeitam privacidade/consentimento. Correções posteriores geram nova versão do snapshot; conteúdo já compartilhado não é silenciosamente reescrito. Admin revisa conteúdo coletivo antes de publicação automatizada; o jogador controla o compartilhamento da própria retrospectiva.
- **Dados:** `recap_snapshots`/`generated_share_cards`, período, escopo, versão, template, snapshots de partidas/prêmios/stats/overall e preferências de compartilhamento. O snapshot é uma projeção; os dados canônicos continuam nas features de origem.
- **Eventos:** `MatchFinished`, `AwardsCalculated`, `RecapGenerated`, `RecapPublished`; correções relevantes podem invalidar/superseder versão ainda não publicada.
- **Supabase (RPC/Data API/Edge Function):** geração idempotente por `{patota, scope, period, player?}`, consulta de versões e publicação; link/token público escopado e revogável quando houver página compartilhável.
- **Telas:** retrospectiva da rodada, arquivo por temporada, fluxo “Meu Ano na Patota”, fluxo “Ano da Patota”, visualizador de cards, revisão coletiva e share sheet.
- **Notificações:** avisar uma vez quando a retrospectiva anual estiver pronta; compartilhamento manual por padrão. Automação Pro, se existir, exige regra, revisão e consentimento adequados.
- **Aceite:** totais conferem com partidas elegíveis; jogador A nunca recebe dados privados do jogador B; card identifica patota/período e versão quando necessário; ausência de dados é tratada explicitamente; correção cria nova versão; link revogado deixa de expor conteúdo.
- **Dependências:** histórico suficiente, stats, premiações, overall/recordes quando usados, share links, templates de card e controles de privacidade.
- **Riscos:** comparação constrangedora, narrativa incorreta por dados incompletos e conteúdo público desatualizado. Evitar categorias negativas, indicar amostra insuficiente, permitir ocultar métricas e exigir revisão do conteúdo coletivo antes de automação.
- **Implementação:** manter recap simples de rodada; adicionar cards exportáveis; depois `Meu Ano na Patota` com métricas estáveis; em seguida `Ano da Patota`; só então curiosidades/recordes avançados e automação.

### 6.11 Compartilhamento e links públicos

- **Objetivo:** levar o grupo do WhatsApp ao registro correto com pouco atrito, sem integração automática inicialmente.
- **Experiência:** “Compartilhar no WhatsApp” monta texto com data, vagas, lista e link da rodada; abre compartilhamento do sistema. Quem recebe pode ver estado público e entrar/responder segundo autenticação ou token individual.
- **Regras:** link mínimo, escopado, expirável/revogável; não usar ID sequencial como segredo; público vê apenas nome de exibição e disponibilidade escolhida; mutação exige login/OTP ou token de uso limitado vinculado; respeitar opt-out e visibilidade.
- **Dados:** `share_links`, hash de token, scope, expiry, revocation, access counters e template snapshot.
- **Eventos:** `ShareLinkCreated`, `PublicPageViewed` (telemetria minimizada), `AttendanceChanged`.
- **Supabase (RPC/Data API/Edge Function):** criar/revogar link e renderizar rota pública; rate-limit e proteção contra scraping.
- **Telas:** preview da mensagem, página pública leve, estado de confirmação e erro de link expirado.
- **Notificações:** nenhuma mensagem é enviada automaticamente no Free; usuário inicia o compartilhamento.
- **Aceite:** compartilhar não exige número de telefone; link expirado/revogado bloqueia; mensagem não inclui dado privado; usuários não autenticados não assumem identidade alheia.
- **Dependências:** agenda, autenticação/OTP e política pública.
- **Riscos:** link encaminhado ou scraping. Escopo reduzido, expiração, revogação e rate limits.
- **Implementação:** share sheet/copy; depois leitura pública; por último confirmação via link autenticado.

### 6.12 WhatsApp, notificações e automação (conceito interno focado)

- **Objetivo:** reduzir trabalho do organizador com mensagens transacionais e respostas estruturadas, sem fazer do WhatsApp a base de dados.
- **Experiência:** fase inicial usa compartilhamento manual. Fase automatizada: usuário opta por receber; patota conecta canal oficial; configura regras (“lista abriu”, “24h antes para não respondentes”, “time publicado”). Respostas por botão/link/deep link atualizam a mesma presença do app. Console mostra pendentes, envio, entrega e erro disponíveis pelo provedor.
- **Regras:** automatizar mensagens permitidas pelo provedor e templates aprovados quando exigido; janela de conversa, opt-in, opt-out, limites, cobrança e políticas variam e devem ser confirmados em documentação vigente. Não presumir que um bot pode entrar e ler um grupo normal: projetar para mensagens individuais e links, salvo capacidade oficial comprovada. Não enviar para contatos sem consentimento. Assinatura/verificação de webhook, idempotência e proteção contra replay. Botões/respostas mapeiam para comando validado, não SQL direto.
- **Dados:** preferências/consentimento, conexão/número, templates, regras, jobs/deliveries, provider IDs, webhook receipts, estado de opt-out, limites de uso e auditoria. Criptografar segredos/identificadores sensíveis conforme infraestrutura.
- **Eventos:** `NotificationRequested`, `NotificationSent/Delivered/Failed`, `WhatsAppOptInChanged`, `AttendanceChanged`, `TeamsGenerated`, `MatchFinished`.
- **API/Edge Functions:** adaptador `sendMessage`, verificação GET e POST do webhook, normalizador para comandos (`ConfirmAttendance`, `DeclineAttendance`), dispatcher de outbox e gestão de templates. Chaves apenas em secret store.
- **Telas:** conexão/estado do canal, automações, prévia, limites/consumo, opt-ins, fila e histórico operacional; não expor segredos.
- **Notificações:** convite, confirmação, fila, lembretes limitados, times e resumo final; preferências por categoria e “parar” funcional. Revalidar estado logo antes de enviar, suprimir lembrete se já respondeu.
- **Aceite:** webhook inválido é rejeitado; repetição não duplica resposta/envio; opt-out impede comunicações futuras da categoria/canal; falhas são visíveis e tentáveis novamente; entrega não é confundida com leitura quando provedor não a oferece.
- **Dependências:** conta/credenciais elegíveis, templates/políticas, opt-in verificável, scheduler, filas e suporte operacional. Kapso pode ser avaliado como provedor opcional, não como modelo de domínio.
- **Riscos:** mudanças de política/API, bloqueios, custos por mensagem, entrega não garantida, spam, templates recusados e suporte a números. Começar com compartilhamento manual e piloto limitado; medir custo por patota e conversão antes de ampliar.
- **Implementação:** preferências/infra genérica e push; adaptador WhatsApp + teste interno; mensagens transacionais opt-in; respostas estruturadas; regras configuráveis e painel depois. Adiar IA/inbox/broadcast genérico até haver caso de uso e capacidade operacional.

### 6.13 Financeiro e pagamentos

- **Objetivo:** dar transparência à mensalidade, rateio e caixa sem transformar o app em instituição financeira.
- **Experiência:** admin cria cobrança/obrigação, valor e vencimento; jogador vê o que deve e registra pagamento informado; admin concilia. Resumo apresenta recebidos, pendentes e despesas com exportação. Em uma etapa posterior, a cobrança pode oferecer QR Code Pix/copia-e-cola e baixa automática quando um provedor compatível confirmar o pagamento por webhook.
- **Regras:** separar obrigação de pagamento confirmado; registro manual exige ator e data; reversão cria lançamento compensatório, sem apagar. Períodos e moeda explícitos; não armazenar credenciais/cartão. Integração PIX/provedor só com desenho e revisão próprios; não afirmar pagamento quitado por comprovante não verificado. Visibilidade financeira apenas a quem autorizado.
- **Dados:** contas, cobranças, ledger entries imutáveis, despesas, anexos opcionais com acesso protegido, reconciliação e audit log.
- **Eventos:** `PaymentDueCreated`, `PaymentReported`, `PaymentRecorded`, `PaymentReversed`, `ExpenseRecorded`.
- **Supabase (RPC/Data API/Edge Function):** criar/fechar cobrança, registrar/reverter pagamento, resumo agregado e exportação; autorização admin para confirmação.
- **Telas:** caixa, mensalidades, detalhe individual, despesas, filtros e exportação.
- **Notificações:** lembretes discretos e privados, opt-in e frequência limitada; nunca postar dívida no grupo sem política/consentimento.
- **Aceite:** saldo = lançamentos válidos; reverter mantém trilha; jogador não vê dados de terceiros sem permissão; período/exportação fecha com resumo.
- **Dependências:** roles, consentimento e definição de escopo contábil.
- **Riscos:** erros de conciliação e dados financeiros sensíveis. Acesso mínimo, auditoria, exportação clara; considerar orientação jurídica/fiscal antes de oferecer processamento.
- **Implementação:** caixa manual e ledger; depois chave Pix/QR Code assistido sem custódia; em seguida conciliação automática por webhook; cobrança recorrente/processamento somente após validação de demanda, custos e compliance.

### 6.14 Plano Free/Pro e entitlements

**Regra de cobrança mobile:** Superwall oferece a experiência e o fluxo de compra para os produtos cadastrados na App Store e Google Play; Supabase guarda a assinatura e aplica o entitlement aos recursos do Nossa Patota. O app consulta entitlement após login/retorno ao foreground e atualiza o estado Superwall para que a segmentação do paywall acompanhe o acesso. Se ficar sem conexão, não liberar novas ações Pro com estado desconhecido.

- **Objetivo:** monetizar economia de tempo e operação avançada por patota, mantendo participação básica acessível.
- **Experiência:** página de plano explica limites e preço vigente; admin assina para liberar benefícios a toda patota; upgrade não altera dados e downgrade preserva leitura/exportação.
- **Regras:** direitos checados no servidor, não só esconder botão; assinatura tem estados (trial, active, past_due, canceled, expired), período de graça e política de acesso após falha; entitlements determinam limites; ações bloqueadas explicam o motivo. Não apagar dados ao cancelar. Definir limites Free após observar uso, não arbitrariamente no início.
- **Dados:** `subscriptions`, customer/provider IDs, `entitlements`, histórico de eventos do provedor, contadores de uso e limites versionados.
- **Eventos:** `SubscriptionChanged`, `EntitlementsChanged`, `UsageLimitReached`.
- **Supabase (RPC/Data API/Edge Function):** webhook de billing autenticado/idempotente, portal/checkout quando escolhido, consulta de capacidades, guards nos comandos Pro.
- **Telas:** planos, gestão da assinatura, consumo e status; mensagem de upgrade contextual.
- **Notificações:** recibo/aviso de cobrança do provedor e aviso de mudança de entitlement; respeitar preferências.
- **Aceite:** alteração de plano aplica-se em todos os membros da patota; webhook repetido não duplica; cancelamento não apaga estatísticas, finanças ou histórico; cada recurso Pro é validado no backend.
- **Dependências:** preço, billing provider, política comercial e custos WhatsApp.
- **Riscos:** abuso de limites, cobrança confusa e custo variável excedendo receita. Medir margem por patota e definir cotas transparentes.
- **Implementação:** feature flags/entitlements internos; plano e cobrança manual/piloto; integração de billing; medição de uso e ajustes.

### 6.15 Onboarding, ativação e paywall contextual

- **Objetivo:** levar o organizador rapidamente da promessa do produto ao primeiro valor real, coletando apenas informações que personalizem a configuração da patota ou tornem o benefício mais claro.
- **Estratégia:** por ser predominantemente uma ferramenta de organização/conveniência, usar onboarding relativamente curto. Não copiar fluxos longos de aplicativos de problemas de alta intensidade. Cada tela deve ou ensinar algo útil sobre o usuário/patota ou comunicar valor relevante; perguntas sem consequência são removidas.
- **Sequência proposta:** (1) promessa orientada a resultado — organizar a pelada, montar times equilibrados e acompanhar estatísticas; (2) demonstração rápida do valor, tendo a geração de times equilibrados como principal candidato a *magic moment*; (3) perguntas sobre papel do usuário, nome/tamanho da patota e objetivo principal; (4) progresso visível enquanto a configuração é preparada; (5) revelação da patota/configuração personalizada; (6) primeira ação de valor, como adicionar jogadores e gerar times; (7) oferta Pro contextual após valor percebido, quando aplicável.
- **Personalização inicial:** respostas podem pré-configurar temporada/ciclo atual, ranking, estatísticas, balanceamento e atalhos da home, sem criar dados fictícios. Ex.: quem prioriza balanceamento recebe essa ação em destaque; quem prioriza ranking vê o caminho para registrar a primeira partida.
- **Paywall:** experimentar apresentação após um momento de valor em vez de bloquear necessariamente o cadastro. A oferta deve retomar o benefício recém-experimentado e apresentar no máximo 2–3 opções comerciais. O plano continua pertencendo à patota, conforme seção 6.14.
- **Experimentação Free/Pro:** não congelar cedo a fronteira de recursos. Testar hipóteses como balanceamento Pro desde o início, quantidade limitada de gerações gratuitas ou balanceamento essencial gratuito com análises avançadas Pro; medir ativação, conversão, retenção e suporte antes de consolidar entitlements.
- **Telemetria:** eventos de produto são separados dos eventos de domínio. Instrumentar, quando aplicável, `landing_view`, `install`, `onboarding_started`, `onboarding_completed`, `patota_created`, `player_added`, `first_match_created`, `teams_generated`, `paywall_viewed` e `subscription_started`, com origem/campanha e variante de experimento quando disponíveis. Não transformar visualizações em eventos de domínio.
- **Telas:** promessa, demonstração, papel, configuração da patota, objetivo, progresso/revelação, convite/adição de jogadores, primeira ação de valor e paywall contextual. Login/autenticação deve aparecer no ponto mínimo necessário para persistir/compartilhar dados, sem destruir o contexto já informado.
- **Aceite:** onboarding pode ser retomado sem perder respostas; perguntas exibidas têm uso explícito; criação não gera estatísticas falsas; telemetria não duplica evento de negócio; paywall registra variante/origem; usuário Free consegue concluir a experiência principal definida pela matriz Free/Pro.
- **Riscos:** onboarding longo demais, promessa não comprovada, paywall precoce, coleta excessiva e otimização apenas para compra sacrificando retenção. Testar por coortes e acompanhar primeira e segunda partidas, não apenas conversão imediata.
- **Implementação:** instrumentar funil atual; criar promessa/demonstração e configuração mínima; ativação pela primeira patota/jogador/partida; inserir paywall contextual por feature flag; então executar testes A/B com amostra e janela definidas.

### 6.16 Central do organizador

- **Objetivo:** reduzir a necessidade de o administrador navegar por várias telas para entender o que precisa de atenção antes da próxima rodada.
- **Experiência:** a tela inicial administrativa apresenta a próxima partida, confirmados/vagas, convidados, fila de espera, pendências financeiras, saldo do caixa, alertas e atalhos como “Cobrar pendentes”, “Montar times”, “Adicionar convidado” e “Iniciar partida”.
- **Regras:** a central é uma projeção de leitura; não cria uma segunda fonte de verdade. Cada indicador deve apontar para o dado canônico correspondente e respeitar permissões. Alertas são derivados de regras explícitas, por exemplo “faltam 2 jogadores”, “há 3 mensalidades vencidas” ou “times ainda não publicados”.
- **Dados:** projeção/cache opcional em `organizer_dashboard_snapshots`, reconstruível de partidas, presenças, fila, financeiro, times e notificações.
- **Eventos:** reage a `AttendanceChanged`, `WaitlistPromoted`, `PaymentRecorded`, `PaymentDueCreated`, `TeamsGenerated`, `MatchStarted` e outros eventos já existentes; não exige novos eventos de negócio para cada card.
- **Supabase (RPC/Data API/Edge Function):** consulta agregada de leitura, com possibilidade de refresh/rebuild administrativo.
- **Telas:** dashboard de operação da patota com cards de situação e ações rápidas; priorizar a próxima rodada e exceções que exigem ação.
- **Notificações:** opcionalmente resumir pendências relevantes para o organizador, sem duplicar alertas já enviados por presença/financeiro.
- **Aceite:** números conferem com as telas de origem; ação rápida redireciona ou executa comando existente; ausência de uma projeção nunca bloqueia a operação principal.
- **Dependências:** presença, fila, financeiro e ciclo da partida.
- **Riscos:** painel virar “mais uma tela” ou exibir informação defasada. Manter poucos indicadores acionáveis e permitir reconstrução da projeção.
- **Implementação:** começar com próxima rodada + presença/fila; adicionar financeiro e alertas depois; medir quais cards realmente geram ação.

### 6.17 Marketplace de apoio à patota

- **Objetivo:** ajudar a resolver faltas operacionais da rodada, permitindo encontrar e contratar apoio como goleiro, jogador avulso, árbitro ou churrasqueiro sem transformar isso em requisito do fluxo principal.
- **Experiência:** organizador publica uma necessidade com data, horário, região e valor; pessoas elegíveis visualizam oportunidades, demonstram interesse e podem ser reservadas/confirmadas. O app registra estado da contratação e regras de cancelamento.
- **Regras:** marketplace é opcional e separado da presença normal da patota. Definir categorias permitidas, idade mínima quando aplicável, política de localização, reputação, cancelamento, reembolso e moderação antes de abrir publicamente. Não prometer disponibilidade. Evitar expor endereço exato antes da reserva quando não necessário.
- **Dados:** `service_offers`, `service_requests`, `service_bookings`, categoria, disponibilidade, localização aproximada, valor, status, contratante, prestador, histórico e avaliações somente se forem implementadas.
- **Eventos:** `ServiceRequestCreated`, `ServiceOfferCreated`, `ServiceBookingRequested`, `ServiceBookingConfirmed`, `ServiceBookingCancelled`, `ServiceCompleted`.
- **Supabase (RPC/Data API/Edge Function):** busca por categoria/data/região, criação de pedido/oferta, reserva/cancelamento e moderação; operações financeiras separadas.
- **Telas:** “Precisa de alguém?”, lista/mapa de oportunidades quando fizer sentido, detalhe, reserva e histórico.
- **Pagamentos:** primeira versão pode apenas registrar a combinação entre as partes. Se houver pagamento intermediado, evoluir para Pix via provedor com identificação da transação; comissão/split somente após revisão jurídica, fiscal e operacional.
- **Notificações:** avisos de nova oportunidade compatível, solicitação, confirmação, cancelamento e lembrete da reserva; opt-in por categoria/região.
- **Aceite:** uma reserva não pode ocupar duas disponibilidades incompatíveis; cancelamento mantém histórico; localização e dados pessoais obedecem à visibilidade definida.
- **Dependências:** perfis, localização aproximada opcional, notificações, moderação e política comercial.
- **Riscos:** fraude, no-show, segurança pessoal, disputas, chargeback/reembolso, exigências fiscais e suporte. Pilotar com categorias e regiões limitadas antes de escalar.
- **Implementação:** começar como quadro de pedidos/ofertas sem pagamento; adicionar reserva; depois reputação; somente então testar Pix/intermediação e eventual comissão.

### 6.18 Modalidade da patota

- **Objetivo:** configurar a patota de acordo com o tipo de futebol praticado e usar essa escolha para oferecer defaults coerentes sem duplicar regras por modalidade.
- **Experiência:** durante a criação da patota, o organizador escolhe a modalidade, inicialmente entre **Futsal**, **Society** e **Campo**. A seleção pré-configura posições, tamanho sugerido de equipe e parâmetros compatíveis; o admin pode revisar os defaults antes de criar a primeira rodada.
- **Regras:** `modality` é obrigatória para novas patotas. Cada modalidade aponta para uma definição versionada de defaults, mas regras específicas da patota continuam configuráveis. Alterar modalidade depois exige confirmação e afeta apenas novas configurações/rodadas; partidas históricas mantêm `rules_snapshot` e não são reinterpretadas. Arquitetura deve aceitar novas modalidades sem espalhar condicionais pelo cliente.
- **Dados:** `patotas.modality`, catálogo/versionamento de `sport_modality_definitions` ou configuração equivalente, posições habilitadas, defaults de tamanho e regras; `matches.rules_snapshot` preserva contexto histórico.
- **Eventos:** `PatotaCreated` inclui modalidade; mudança posterior gera `PatotaModalityChanged` com ator, origem/destino e versão dos defaults.
- **Supabase (RPC/Data API/Edge Function):** criação/edição da patota valida modalidade suportada; consulta de catálogo entrega modalidades/defaults ativos; alteração posterior calcula impacto e exige confirmação do admin.
- **Telas:** etapa “Qual modalidade vocês jogam?” no cadastro; configurações da patota exibem modalidade e consequências da alteração.
- **Aceite:** toda nova patota possui modalidade válida; defaults aparecem corretamente; mudança não altera estatísticas nem partidas passadas; modalidade desconhecida não quebra clientes antigos.
- **Dependências:** cadastro da patota, posições, geração de times e regras de partida.
- **Riscos:** transformar defaults em regras rígidas e dificultar grupos com formatos próprios. Tratar modalidade como preset versionado, não como suposição absoluta.
- **Implementação:** Futsal/Society/Campo com poucos defaults; validar uso real; só então adicionar modalidades ou regras específicas adicionais.

### 6.19 Código de entrada randomizado da patota

- **Objetivo:** permitir que um jogador encontre/entre na patota com um código curto e compartilhável, sem depender de o admin cadastrar cada membro ou de um link temporário.
- **Experiência:** ao criar a patota, o sistema gera um código amigável, por exemplo `K7M4X2`. O organizador pode copiar/compartilhar o código; o jogador escolhe “Entrar em uma patota”, digita o código e vê apenas as informações mínimas necessárias para confirmar a entrada. QR Code/deep link pode transportar o mesmo identificador em evolução posterior.
- **Regras:** código é aleatório, não sequencial, case-insensitive após normalização, único no conjunto ativo e separado dos `share_links` de rodada. Evitar caracteres ambíguos quando possível. Regeneração pelo admin revoga o código anterior para novas entradas sem remover membros existentes. Rate limit, proteção contra enumeração e desafios adicionais diante de abuso são obrigatórios; o código não concede privilégios administrativos. Patotas podem exigir aprovação do admin antes da associação.
- **Dados:** código normalizado/índice único (ou hash + estratégia segura de lookup), `created_at`, `rotated_at`, estado e política de entrada; auditoria de regeneração e tentativas abusivas sem armazenar segredos desnecessários em logs.
- **Eventos:** `PatotaJoinCodeRegenerated`, `PlayerJoined`; opcionalmente telemetria de `join_code_submitted`/`join_code_success` sem transformar tentativa em evento de domínio.
- **Supabase (RPC/Data API/Edge Function):** `POST /patotas/join-by-code` com rate limit e resposta que não facilite enumeração; `POST /patotas/{id}/join-code/regenerate` somente admin; opção futura de resolver QR/deep link para o mesmo fluxo.
- **Telas:** código nas configurações/convite; entrada por código; confirmação/aprovação quando habilitada; ação “Gerar novo código”.
- **Aceite:** códigos ativos não colidem; código revogado não cria novas associações; repetição da mesma entrada não duplica membro; usuário sem permissão não regenera; respostas inválidas não revelam dados privados.
- **Dependências:** autenticação, associação à patota, rate limiting e política de convite/aprovação.
- **Riscos:** compartilhamento público, brute force e entrada indesejada. Usar espaço de códigos suficiente, limites por IP/conta/dispositivo quando aplicável, regeneração e aprovação opcional.
- **Implementação:** código + entrada autenticada; depois aprovação opcional; por último QR Code/deep link e controles antifraude adicionais conforme métricas.

### 6.20 Cores e identidade visual dos times

- **Objetivo:** refletir como a patota identifica os times na quadra/campo e tornar escalações, placar e conteúdo compartilhado imediatamente reconhecíveis.
- **Experiência:** o organizador define cores padrão dos times (ex.: Preto e Branco, Azul e Vermelho). Ao gerar uma rodada, pode manter os padrões ou escolher cores específicas; os cards de escalação, placar e recap usam a identidade publicada daquela partida.
- **Regras:** cor nunca é o único identificador: cada equipe mantém nome/label acessível (“Time Preto”, “Time Branco” ou nome configurado). Validar contraste e impedir combinações visualmente indistinguíveis quando possível. A cor publicada é snapshot da partida; alterar o padrão da patota depois não muda o histórico. Overrides por rodada ficam registrados junto da geração/publicação.
- **Dados:** defaults em configuração da patota; `team_generations`/`team_assignments` ou entidade de time da partida guarda `team_label`, `color_token`/valor validado e versão visual. Preferir paleta/tokens controlados antes de liberar qualquer cor hexadecimal.
- **Eventos:** `TeamVisualIdentityChanged`; `TeamsGenerated` carrega referência à identidade publicada sem duplicar a lógica de balanceamento.
- **Supabase (RPC/Data API/Edge Function):** editar defaults da patota e aceitar override validado ao publicar times; leitura histórica retorna a identidade daquele jogo.
- **Telas:** seletor de cores nas configurações e na geração/publicação dos times; prévia com nomes e contraste.
- **Aceite:** duas equipes são distinguíveis sem depender só de cor; histórico mantém cores originais; mudança de default não altera jogo passado; compartilhamentos reproduzem a identidade da rodada.
- **Dependências:** balanceamento/geração, placar e templates de compartilhamento.
- **Riscos:** baixa acessibilidade, excesso de personalização e inconsistência visual. Começar com paleta curada e labels obrigatórios.
- **Implementação:** duas cores padrão por patota + override da rodada; depois múltiplos times/paletas se houver demanda.

### 6.21 Card individual pós-partida

- **Objetivo:** permitir que cada jogador transforme seu desempenho em uma partida específica em conteúdo visual compartilhável, criando valor social sem expor estatísticas de terceiros.
- **Experiência:** após a partida ser finalizada e os dados estarem consolidados, o jogador abre “Compartilhar minha partida” e vê um card vertical priorizado para Stories. O card pode incluir nome/foto conforme permissão, patota, data, placar/resultado, gols, assistências, outras métricas registradas, prêmio recebido e overall/variação quando habilitado. O usuário escolhe entre templates aprovados e usa o share sheet para Instagram, WhatsApp ou outros apps compatíveis.
- **Regras:** card contém somente estatísticas daquele jogador naquela partida, além de contexto coletivo mínimo (patota/data/placar). Estatística não registrada não aparece como zero. Só partidas finalizadas/publicadas geram card. Privacidade do perfil/foto é respeitada; o próprio jogador inicia o compartilhamento por padrão. Correção da partida invalida ou supersede a versão gerada, sem alterar silenciosamente imagem já exportada. Evitar mensagens depreciativas ou comparações automáticas com outros jogadores.
- **Dados:** deriva de `match_stats`, `match_actions`, `award_results`, `player_rating_snapshots`, partida e identidade visual; `generated_share_cards` guarda escopo `player_match`, versão do template, payload/snapshot e timestamps, sem virar fonte de verdade das estatísticas.
- **Eventos:** `PlayerMatchCardGenerated`; `MatchActionCorrected`/reabertura podem marcar versão anterior como desatualizada. Compartilhamento efetivo fora do app só deve ser marcado quando houver sinal confiável da plataforma; não assumir sucesso após abrir share sheet.
- **Supabase (RPC/Data API/Edge Function):** operação autorizada por jogador/admin para gerar/obter card; renderer server-side ou client-side determinístico; URL pública, se usada, é escopada/revogável e não expõe dados além do snapshot autorizado.
- **Telas:** CTA pós-partida, preview vertical, seleção de template, controles de métricas permitidas e share sheet.
- **Notificações:** uma notificação opcional após consolidação pode avisar “Seu card da partida está pronto”; sem envio automático a redes sociais.
- **Aceite:** números conferem com a partida; jogador não gera card privado de terceiro sem regra explícita; dado ausente é omitido/identificado; imagem funciona em proporção vertical definida; correção produz nova versão; privacidade é aplicada antes da renderização.
- **Dependências:** partida finalizada, estatísticas confiáveis, premiações/overall opcionais, identidade visual e infraestrutura de cards/compartilhamento.
- **Riscos:** estatística errada viralizar, exposição de foto/nome e incentivo a comportamento individualista. Oferecer revisão, opt-out, templates neutros e não premiar somente gols.
- **Implementação:** primeiro template com placar + gols/assistências; depois prêmio/overall e múltiplos templates; medir geração e compartilhamento antes de investir em editor visual complexo.

## 7. Matriz Free vs Pro proposta

Ponto de partida para validação comercial, não decisão final de preço nem promessa ao cliente.

| Capacidade | Free | Pro por patota (proposta) |
|---|---|---|
| Membros, perfil, agenda e confirmação | Sim, experiência principal completa | Sim |
| Modalidade, código de entrada e cores dos times | Sim, configuração essencial da patota | Sim |
| Card individual pós-partida | Compartilhamento manual com template essencial | Templates/arquivo avançado apenas se valor validado |
| Link e compartilhamento manual | Sim | Sim |
| Fila e promoção básica | Sim | Regras/automação avançadas se houver custo justificável |
| Times e balanceamento | Sorteio/balanceamento essencial | Histórico avançado, alternativas e regras da patota |
| Estatísticas, overall e perfil | Resumo e histórico essencial | Evolução ampliada, filtros e relatórios avançados |
| Votação e premiações | Sim, conjunto essencial | Categorias/configurações avançadas, se valor validado |
| Temporadas, recordes e conquistas | Básico ou ciclo atual | Histórico ampliado e relatórios exportáveis |
| Retrospectiva | Texto/link compartilhável | Cards/automação configurável e arquivo avançado |
| Financeiro | Caixa manual essencial pode ser Free | Cobranças/lembretes/relatórios avançados; avaliar custo e sensibilidade |
| Notificações | Push/app e limites razoáveis | Mais regras e canais |
| WhatsApp | Compartilhamento iniciado pelo usuário | Mensagens transacionais/automação dentro de cota transparente |
| Administração/relatórios | Operação básica | Exportações, auditoria ampliada e controles avançados |
| Central do organizador | Resumo básico da próxima rodada | Alertas operacionais, atalhos e visão financeira ampliada |
| Marketplace de apoio | Descoberta/uso básico quando disponível | Benefícios comerciais a definir somente após validar oferta, demanda e custos |
| Membros | Limite inicial generoso a validar | Maior limite ou ilimitado sujeito a política de uso justo |

**Recomendação de empacotamento:** não cobrar para confirmar presença, ver informação essencial da própria rodada ou compartilhar manualmente. Vender a remoção de trabalho repetitivo, automações, conveniência administrativa e profundidade histórica. WhatsApp tem custo operacional variável; indicar franquia, excedentes ou política justa antes da contratação. O preço citado na conversa (faixa aproximada de R$14,90–29,90/mês por patota) é apenas hipótese histórica a testar, não recomendação atual sem pesquisa de custos/disposição a pagar.

### 7.1 Paywall mobile com Superwall

O app Flutter usa o SDK oficial Flutter do Superwall para placements/paywalls, ofertas e compra/restore dos produtos configurados nas lojas. Criar placements ligados a momentos de valor (por exemplo, recurso avançado do organizador), sem interromper confirmação de presença ou acesso ao básico. A atribuição de Pro por patota deve ser definida como regra de produto: o comprador precisa ser organizador autorizado; todos os membros recebem somente os entitlements compartilhados explicitamente definidos para aquela patota.

Para o primeiro corte, usar o fluxo de compra padrão gerido pelo Superwall, salvo requisito comprovado de backend de billing próprio. Vincular a identidade autenticada do usuário no SDK e sincronizar mudanças de compra/renovação/cancelamento/refund ao backend por mecanismo suportado pelo Superwall/lojas. Webhooks devem ser autenticados, deduplicados e aplicados em Edge Function; manter estado e histórico em `subscriptions`/`entitlements`. No app, o estado do SDK controla exibição do paywall; as operações Pro sempre revalidam o entitlement no Supabase. Uma falha de rede ou estado `unknown` não deve conceder permissão.

Manter produtos, período de trial, preço, período de graça, cancelamento e política para membros quando o organizador perde acesso como decisões comerciais pendentes. Antes do lançamento, verificar o processo vigente de cadastro e análise de produtos nas duas lojas e testar compra, cancelamento, renovação, restore, reembolso e conta em múltiplos dispositivos. Superwall SDK não é billing web para o site GitHub Pages.

## 8. Requisitos transversais

### Segurança e privacidade

- Modelar associação e papel por patota; verificar autorização no servidor para cada leitura/mutação.
- Minimizar dados de perfil público; links com escopo mínimo, expiração e revogação.
- Consentimento granular por canal/categoria e opt-out rápido. Separar mensagens operacionais de marketing.
- Segredos só no servidor; validar assinatura do webhook e proteger endpoints contra replay, enumeração e abuso.
- Auditoria para alteração de presença feita por admin, geração/manual override de time, edição de resultado, pagamento e mudança de assinatura.
- Definir retenção, exportação e exclusão conforme requisitos legais aplicáveis antes do lançamento.

### Acessibilidade e operação

- Fluxo de presença em poucos toques, leitura por leitor de tela, contraste e estados sem depender só de cor.
- Fuso horário explícito; tratar horário de verão conforme timezone, ainda que não seja prática atual em toda localidade.
- Logs sem telefone/token/mensagem integral desnecessária; métricas de falha, latência, fila atrasada e custo por patota.
- Painel interno para reprocessar jobs com deduplicação, consultar falhas sanitizadas e pausar uma automação.
- Suportar dimensões/texto ampliados, áreas seguras, teclado/leitor de tela e permissões de câmera/fotos sob demanda; não pedir permissões no primeiro lançamento sem contexto.
- Configurar deep links/app links para convites e retorno de autenticação; tratar app instalado, não instalado, link expirado e login em andamento. O domínio web pode exibir fallback mínimo.
- Armazenar sessão/token via mecanismo suportado pelo SDK/armazenamento seguro do sistema; persistência local de preferências não armazena permissões Pro.
- Offline no MVP é somente cache de leitura quando seguro. Presença, pagamentos e ações do jogo exigem confirmação do servidor; qualquer fila offline futura usa UUID/idempotência e resolução explícita de conflito.
- Fotos/cards usam seletor nativo e Supabase Storage com bucket privado por padrão, limites de tamanho/tipo e políticas por proprietário/patota. URLs assinadas expiram; excluir imagem também revoga referências quando aplicável.
- Compartilhamento usa share sheet nativo. Abrir o share sheet não prova que o conteúdo foi enviado. Câmera direta fica para depois de validar que seletor de galeria não basta.
- Push requer configuração de credenciais APNs/FCM, consentimento contextual, registro/rotação de token e caminhos de toque que abram a tela correta; Realtime não substitui push.
- Builds separados de desenvolvimento, homologação e produção; segredos server-side no Supabase; signing keys/perfis de publicação fora do repositório; criar pipeline de release Android/iOS antes da publicação.

### Consistência de dados

- Encerramento e correção de partida devem disparar recálculo idempotente de projeções dependentes.
- Guardar `algorithm_version`/`formula_version`; não reinterpretar resultados publicados silenciosamente.
- Preferir transações para capacidade/fila e ledger; usar constraints únicos no banco além de validação de API.

## 9. Roadmap por fases

Fases representam ordem e gates de decisão; duração depende do estado real do aplicativo, equipe e validação.

Além das fases técnicas, avaliar o produto continuamente pelo funil **Aquisição → Ativação → Partida → Retenção → Monetização**. Esse funil não substitui o roadmap abaixo: serve para impedir que novas features avancem sem medir se mais patotas chegam ao primeiro jogo, retornam para o segundo e, só então, encontram valor suficiente para assinar.

| Fase | Entrega | Critério para avançar |
|---|---|---|
| 0 — Fundação mobile/backend | Criar app Flutter Android/iOS; ambientes Supabase; migrações iniciais, Auth, profiles, patotas, RLS, navegação, tema e CI/builds; definir identidade e deep links | App instalável nas duas plataformas; sessão e políticas verificadas; projeto de produção isolado |
| 1 — Rodada confiável | Cadastro/login, criar patota, modalidade, código/convite, agenda, presença, capacidade, fila FIFO e compartilhamento manual | Organizador executa rodada real; concorrência não excede vagas; autorização revisada |
| 2 — Dados esportivos | Fechamento, gols/assistências, estatísticas, perfis, cores/identidade dos times, card individual pós-partida e premiação híbrida auditável | Integridade/reconciliação de partidas; participação em registro suficiente |
| 3 — Diferencial de carreira | Overall versionado e explicável, balanceamento dinâmico, temporadas, recordes e conquistas | Amostra por jogador suficiente; avaliação de justiça/aceitação positiva |
| 4 — Monetização e operação | Entitlements no Supabase, SDK Flutter Superwall, produtos nas lojas, placements contextuais e testes de ciclo de assinatura; financeiro conforme escopo | Compra/restore/renovação/cancelamento/refund sincronizados; autorização Pro validada no servidor; suporte pronto |
| 5 — Automação WhatsApp | Opt-in, adaptador oficial/provedor, templates, webhook, jobs, confirmação/resposta e painel | Elegibilidade/políticas confirmadas; entrega e custo por conversa medidos; opt-out e falhas testados |
| 6 — Retrospectivas avançadas | Meu Ano na Patota, Ano da Patota, cards em narrativa vertical, temporadas históricas, regras de automação e integração aprofundada | Conteúdo correto, compartilhamento voluntário e retenção incremental comprovada |
| 7 — Serviços e pagamentos assistidos | Central do organizador madura, QR Code Pix/conciliação automática e piloto de marketplace de apoio | Operação principal estável; demanda comprovada; riscos jurídicos/fiscais/moderação revisados; suporte preparado |

**Evitar no primeiro lançamento:** IA genérica no WhatsApp, leitura de mensagens de grupos como premissa, broadcasts irrestritos, smartwatch, intermediação financeira completa, marketplace aberto e um construtor universal de workflows. São superfícies caras e não necessárias para validar a proposta principal.

## 10. Métricas de sucesso

- **Ativação:** patotas que criam primeira rodada e participantes que respondem em 7 dias.
- **Funil de onboarding:** início→conclusão, onboarding→patota criada, patota criada→primeiro jogador e primeiro jogador→primeira partida, segmentados por origem e variante quando houver.
- **Retenção operacional:** primeira→segunda partida por patota; tratar este retorno como sinal central de valor recorrente, além de usuários ativos genéricos.
- **Paywall/oferta:** alcance do paywall, conversão por variante/origem, tempo até assinatura e impacto do limite Free/Pro na ativação e na segunda partida.
- **Substituição da lista manual:** fração de rodadas com presença registrada no app/link.
- **Confiabilidade:** duplicatas, conflitos de capacidade, promoção incorreta e correções após fechamento.
- **Engajamento esportivo:** jogos finalizados com estatísticas suficientes, participação em votação e retorno ao perfil/temporada.
- **Entrada por código:** tentativas válidas→associação concluída, necessidade de aprovação, regenerações e sinais de abuso; não otimizar por tentativas brutas.
- **Compartilhamento pós-partida:** jogadores elegíveis que abrem preview, geram card e acionam share sheet; quando possível medir retorno por link atribuído, sem presumir publicação em rede social.
- **Retrospectiva anual:** elegíveis que visualizam `Meu Ano`/`Ano da Patota`, concluem a sequência e acionam compartilhamento; acompanhar também erros/correções antes de publicação.
- **Qualidade do balanceamento:** diferença prevista, overrides por geração e avaliação dos participantes; observar amostras e vieses, não só soma de rating.
- **Pro:** conversão por patota, retenção, cancelamento, uso de cada entitlement, custo de mensagens e margem por patota.
- **WhatsApp:** opt-in, entrega/falha, resposta a convite, opt-out/reclamação, custo e latência; não usar “lido” se não houver sinal confiável.
- **Central do organizador:** uso dos atalhos, pendências resolvidas a partir do dashboard e redução de navegação/passos para preparar uma rodada.
- **Marketplace (quando existir):** pedidos publicados, taxa de preenchimento, tempo até confirmação, cancelamento/no-show, recorrência e incidentes/moderação; receita só depois de validar segurança e liquidez.

- **Milestones:** jogadores ativos que avançam em ao menos um milestone, desbloqueios por categoria e proporção de cards de milestone compartilhados; interpretar junto com recorrência de partidas, não como métrica isolada de vaidade.

## 11. Decisões pendentes antes da implementação

1. Definir método de autenticação inicial (e-mail, telefone/OTP, Apple/Google) e recuperação de conta; configurar redirects/deep links.
2. Definir capacidade, visitantes, prioridade da fila, janela de promoção e comparecimento/no-show.
3. Aprovar taxonomia de estatísticas, categorias de prêmios, elegibilidade, pesos e desempates.
4. Definir política de privacidade de perfil, link público, rivalidades e exibição de notas.
5. Validar nome/semântica de overall e fórmula com a patota; informar amostra/limites.
6. Delimitar financeiro (caixa manual vs processamento), permissões, exportação e retenção.
7. Selecionar provedor WhatsApp somente após confirmar capacidade oficial, elegibilidade, templates, opt-in, custos, regras de grupos e requisitos comerciais vigentes.
8. Validar preço, limites Free e cotas Pro com uso real; a faixa mencionada na conversa não é preço definido.
9. Definir produtos/SKUs, preço, trial, ciclo de cobrança, política de cancelamento, inadimplência, reembolso, imposto e comportamento do plano compartilhado por patota.
10. Definir se Pix será apenas instrução de pagamento, geração de QR Code ou conciliação automática; escolher provedor somente após comparar custo, webhook, identificação de pagador e responsabilidades.
11. Antes de abrir marketplace, definir categorias permitidas, regras de localização, moderação, reputação, cancelamento, segurança, intermediação de pagamento e responsabilidade da plataforma.
12. Definir o primeiro *magic moment* validado do onboarding (balanceamento é a hipótese inicial) e quais respostas realmente alteram a experiência.
13. Definir o ponto inicial do paywall e o plano de experimentos Free/Pro, incluindo critérios de sucesso que combinem conversão e retenção.
14. Escolher ferramenta/esquema de analytics e política de consentimento/retenção para telemetria e testes A/B, mantendo separação de eventos de domínio.
15. Web2App e compra web ficam fora do MVP; reavaliar somente com demanda e revisão das regras atuais de lojas, billing, impostos e continuidade de conta.
16. Definir modalidades inicialmente suportadas, defaults de posições/tamanho/regras e política para troca de modalidade após existir histórico.
17. Definir formato, tamanho/espaço de busca, rotação e política de aprovação do código da patota; validar UX de QR/deep link separadamente.
18. Definir paleta inicial, contraste mínimo, quantidade de times e se cores customizadas livres serão permitidas ou apenas tokens aprovados.
19. Definir conteúdo mínimo/máximo, templates, privacidade e política de correção do card individual pós-partida.
20. Definir período anual, critérios de elegibilidade/amostra e quais métricas/curiosidades podem aparecer em `Meu Ano na Patota` e `Ano da Patota`, evitando comparações negativas ou dados insuficientes.

21. Escolher serviço de push (FCM/APNs direto ou provedor), responsabilidades de envio e retenção de tokens; definir isso junto à configuração das credenciais Apple/Google.
22. Definir política de dados para fotos, consentimento, retenção e exclusão; decidir quais páginas de convite/compartilhamento continuarão no GitHub Pages.
23. Confirmar a integração Superwall escolhida para verificação de compras/webhooks e o mapeamento entre comprador e entitlement compartilhado da patota.

## 12. Glossário

- **Outbox:** tabela transacional de eventos pendentes de publicação.
- **Idempotência:** repetição da mesma solicitação produz no máximo um efeito de negócio.
- **Projeção:** leitura agregada reconstruível dos registros canônicos/eventos.
- **Entitlement:** permissão/limite derivado do plano ativo da patota.
- **Opt-in / opt-out:** consentimento / revogação de um canal ou tipo de comunicação.
- **Overall:** indicador lúdico e contextual de força estimada do jogador dentro da patota.

## 13. Referências técnicas verificadas

- [Quickstart oficial do Supabase para Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter) — inicialização do supabase_flutter, Auth, Data API, Storage e configuração básica de deep links.
- [Referência Supabase Dart: inicialização](https://supabase.com/docs/reference/dart/initializing) — uso da publishable key no cliente; não confundir com secret key de servidor.
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) — RLS e grants devem ser configurados em cada tabela exposta.
- [Documentação Superwall Flutter](https://superwall.com/docs/flutter) e [instalação do SDK](https://superwall.com/docs/flutter/quickstart/install) — SDK Flutter, plataformas e versão devem ser conferidas novamente ao iniciar a implementação.
- [Superwall Flutter: compras e status de assinatura](https://superwall.com/docs/flutter/guides/advanced-configuration) — fluxo padrão gerenciado pelo SDK e alternativa avançada de PurchaseController/status manual.
- [Superwall Flutter: usar backend próprio](https://superwall.com/docs/flutter/guides/using-your-own-backend) — identidade consistente e sincronização de entitlements com backend, se esse modo for adotado.
- [Webhooks Superwall](https://superwall.com/docs/integrations) — eventos de assinatura/pagamento; verificar formato, autenticação e eventos disponíveis na configuração escolhida antes de implementar.
- [Firebase Cloud Messaging para Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) — setup mobile, registro de token e configuração APNs para iOS.

Links consultados em 01/10/2026. Versões de SDK, requisitos das lojas e políticas podem mudar; validar novamente na implementação e no lançamento.

