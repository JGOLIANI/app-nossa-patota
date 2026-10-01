# Decisões do primeiro corte

Base: especificação v1.5. Decisões iniciais, sujeitas à validação de produto.

| Tema | Escolha | Consequência |
|---|---|---|
| Plataformas | Flutter Android/iOS | Web fora deste corte |
| Identidade | E-mail/senha, mínimo de 8 caracteres | Confirmação e recuperação com callback mobile; configurar regras também no Supabase |
| Estado/navegação | ChangeNotifier, InheritedNotifier e go_router | Repositórios separam os dados; sessão protege rotas |
| Modalidades | Futsal, Society, Campo | Sugestão de 10/14/22 participantes; capacidade ajustável por rodada |
| Fuso | IANA, persistência UTC | Horário exibido/construído no fuso da patota |
| Participação | Membros ativos autenticados | Visitantes e aprovação de entrada virão depois |
| Código | 8 símbolos de alfabeto de 32 caracteres; 40 bits | Privado, aleatório, revogável; 10 tentativas por conta a cada 15 minutos |
| Fila | FIFO com sequência monotônica | Promoção automática informada; sem janela de aceite ou prioridade neste corte |
| Presença | Aberta até início da rodada | Prazo e estado revalidados sob lock do servidor |
| Idempotência | UUID por comando; receipt privado por ator | Replay de confirmação antiga não desfaz desistência posterior; UI recarrega dados canônicos |
| Compartilhamento | Código via share sheet/cópia | Sem mensagem automática ou link público |
| Offline | Demonstração isolada; real exige servidor | Sem fila offline para mutações |
| Monetização | Fase 4 do roadmap | Superwall após definir produtos, comprador e entitlements no servidor |

## Pendências antes de uso real/publicação

- Conectar Supabase de desenvolvimento; homologar Auth, Data API e deep links em ambos os sistemas. Os testes atuais simulam o contrato de Auth em PostgreSQL.
- Verificar isolamento com organizadores/jogadores em patotas diferentes no serviço hospedado.
- Acrescentar proteção por IP/dispositivo/CAPTCHA para entrada e cadastro antes de exposição ampla. O limite por conta não cobre criação abusiva de múltiplas contas.
- Definir ícone/identidade final, application IDs, assinatura e separação dev/homologação/produção.
- Implementar edição/cancelamento pela UI com RPC/auditoria, visitantes e presença efetiva antes de estatísticas.
- Definir exclusão/exportação/retenção. Não há exclusão de conta exposta; remover organizador referenciado exige transferência/tratamento do histórico.
- Adicionar Realtime/push; a atualização entre aparelhos ainda é manual.
- Integrar Superwall e webhooks verificados na fase de monetização. Pro será por patota e autorizado pelo backend.

Este corte ainda não conclui os gates das fases 0/1: faltam projeto remoto configurado, homologação nos dois sistemas e uma rodada real.
