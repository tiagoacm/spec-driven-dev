# spec-driven-dev

Plugin para Claude Code que implementa um fluxo de **Spec Driven Development (SDD)**
agnóstico de tecnologia: serve para qualquer stack, porque tudo o que ele sabe do projeto
vem do próprio repositório ou das suas respostas — nunca de uma stack presumida.

Princípio central: **o agente implementa, a validação decide.** Nenhuma tarefa é dada como
concluída pelo relato do agente; ela passa por um teste rodado por fora e por uma revisão
feita por quem não escreveu o código.

## Instalação

O repositório é um marketplace local. No Claude Code:

```
/plugin marketplace add <caminho>/sdd-marketplace
/plugin install spec-driven-dev@sdd-local
```

Os comandos ficam disponíveis com o prefixo do plugin: `/spec-driven-dev:init`,
`/spec-driven-dev:plan` etc.

O `ralph.sh` é um script, não um comando: rode-o **a partir da raiz do projeto**, pelo
caminho do plugin, ou copie-o para o projeto uma vez:

```bash
<caminho>/sdd-marketplace/plugins/spec-driven-dev/scripts/ralph.sh <slug>
```

No Windows, rode o `ralph.sh` no **Git Bash** ou no **WSL** (o PowerShell não executa bash).

## Comandos

| Comando | O que faz |
|---|---|
| `/spec-driven-dev:init` | Roteador: mostra o estado de `.sdd/`, roda o `sdd-check` e chama o próximo passo. Não escreve nada. |
| `/spec-driven-dev:init:context` | **Como** se desenvolve aqui: `STANDARDS.md` (com a seção Interface), `config.json`, `CLAUDE.md`, `.mcp.json` do navegador de verificação e, em projeto existente, `codebase.md`. |
| `/spec-driven-dev:init:project` | **O que** será construído: entrevista e gera `project.md` (fluxos `F-NN`, entidades `E-NN`, escopo do MVP). |
| `/spec-driven-dev:init:roadmap` | **Em que ordem**: divide o projeto em fases, cada uma pronta para um `/plan`. |
| `/spec-driven-dev:plan` | Spec → perguntas → aprovação → plano, numa execução. Retoma de onde parou. |
| `/spec-driven-dev:implement` | Executa o plano com você acompanhando, tarefa por tarefa. |
| `/spec-driven-dev:revise` | Aplica mudança de requisito como diff; acrescenta só tarefas novas e de ajuste. |
| `/spec-driven-dev:review` | Revisão independente de uma feature ou de qualquer diff, sem alterar nada. |
| `scripts/ralph.sh` | Executa o plano de forma autônoma, com os mesmos gates do `/implement`. |

## Fluxos

**Projeto novo**

```
/init → init:context → init:project → init:roadmap
      → /plan fase 1 → /implement ou ralph.sh → /plan fase 2 → ...
```

**Projeto existente**

```
/init → init:context (gera codebase.md) → /plan <funcionalidade> → /implement ou ralph.sh
```

`project.md` e `roadmap.md` são opcionais em projeto existente. Terminado o MVP de um
projeto novo, rode `init:context --existente` para passar a trabalhar com o `codebase.md`.

**Nova funcionalidade**

```
já está no roadmap? ───────────────────→ /plan fase N
muda fluxo, ator, entidade ou regra? ──→ init:project → init:roadmap → /plan fase N
capacidade isolada? ───────────────────→ /plan <descrição>
altera algo já planejado ou feito? ────→ /revise <slug> <mudança>
```

## O que acontece em cada tarefa (`/implement` e `ralph.sh`)

1. **Implementar** — só nos arquivos declarados na tarefa.
2. **Testar** — `sdd-test-agent` escreve os testes a partir dos critérios da spec.
3. **Gate mecânico** — o comando de teste roda por fora do agente; vale o código de saída.
4. **Interface** — se a tarefa alterou `paths.frontend`, o `sdd-ui-agent` abre a aplicação
   num navegador (Playwright MCP), chega à tela pela navegação, percorre os critérios e
   compara com a tela de referência. Erro de console, requisição 4xx/5xx ou critério que
   não se completa pela tela reprovam.
5. **Revisão** — `sdd-review-agent` (somente leitura) aprova ou reprova com motivo.
6. Falhou 3, 4 ou 5 → até 3 ciclos de correção com a causa real. Passou → marca `[x]`,
   registra no log e commita (nessa ordem).

No fecho da feature (igual no `/implement` e no `ralph.sh`): suíte completa, verificação de
interface da feature inteira (todos os critérios com tela, com cada ator), E2E versionado (se
o projeto tiver), gate de segurança (`commands.security`, se configurado),
revisão de toda a feature (primeira linha `VEREDITO: ...`, senão não fecha) e fase do roadmap
marcada como `implementada`.

## Agentes

- **`sdd-test-agent`** — lê a spec antes do código; escolhe o nível de teste pelo tipo do
  critério (unitário, integração, E2E só se `commands.e2e` existir); escreve só arquivos de
  teste; nunca corrige a implementação.
- **`sdd-ui-agent`** — modelo `sonnet`, só `Read`, `Glob`, `Grep` e o navegador via MCP.
  Navega só na URL de verificação, com usuários de verificação por ator, num banco separado
  do de desenvolvimento. Veredito na primeira linha: `INTERFACE: APROVADA` ou
  `INTERFACE: REPROVADA: <motivo>`; diferença visual é ressalva, com captura de tela.
- **`sdd-review-agent`** — modelo `haiku`, somente leitura. Modo tarefa (diff da tarefa) e
  modo feature (diff acumulado, cobertura critério a critério). Aplica um checklist de
  segurança agnóstico de stack (injeção, autenticação, autorização/IDOR, atribuição em massa,
  upload, exposição de dados, credenciais, proteções desligadas, redirect aberto, dependência
  nova). Reprova só por motivo objetivo: critério sem evidência, violação do STANDARDS,
  teste tautológico, segredo no código ou vulnerabilidade com o caminho da entrada ao ponto
  perigoso demonstrado em `arquivo:linha`.

## `ralph.sh`

```bash
ralph.sh <slug> [--max-iter N] [--timeout S] [--test-cmd "<cmd>"] [--no-review]
                [--from T-NN] [--allow-dirty] [--descartar-tentativa] [--no-commit] [--sem-ui]
                [--permissoes-totais] [--dry-run] [-y]
```

| Código | Significado |
|---|---|
| 0 | Plano concluído |
| 1 | Erro de preflight ou de execução |
| 2 | Precisa de decisão humana (`SDD_NEEDS_HUMAN` ou tarefa `[humano: ...]`) |
| 3 | Limite de iterações |
| 4 | Timeout |
| 5 | Validação não passou após os ciclos de correção (ou revisão sem veredito) |
| 6 | Possível segredo nos arquivos a commitar — nada foi commitado |

**Retomar** é rodar o mesmo comando: ele continua da primeira tarefa pendente. Ao parar, o
script imprime as opções com os comandos prontos. Se a tentativa falhada ficou na árvore de
trabalho, use `--descartar-tentativa` (sempre pede confirmação — o `-y` não vale para
descarte; em CI, `RALPH_CONFIRM_DISCARD=1`) ou `--allow-dirty`.

**Verificação de interface:** o ralph lê `paths.frontend`, `environment.verify_url`,
`environment.verify_users`, `commands.verify_prepare` e `commands.verify_serve` do
`config.json`; recria o banco de verificação, sobe o servidor, roda o `sdd-ui-agent` e derruba
o servidor ao final. Ambiente não configurado com frontend alterado → a tarefa não passa
(código 5). `--sem-ui` pula a verificação e registra isso no log.

**Primeira vez num projeto:** rode com `--dry-run` e depois `--max-iter 1` antes de soltar o
plano inteiro.

**Billing:** com `ANTHROPIC_API_KEY` definida, o Claude Code usa a API paga em vez da sua
assinatura. O script avisa e pede confirmação.

**Permissões:** por padrão o agente roda com uma **lista restrita** de ferramentas: editar
arquivos, ferramentas de leitura, git somente leitura e os comandos do `config.json` (o
`install` fica de fora de propósito). Precisa de mais? `RALPH_EXTRA_TOOLS="Bash(npx prettier:*)"`.
`--permissoes-totais` volta ao `--dangerously-skip-permissions` — use só em container.

Variáveis: `RALPH_MAX_CYCLES` (3), `RALPH_LIMIT_WAIT` (segundos de espera ao bater limite de
uso, 300), `RALPH_LIMIT_MAX_WAITS` (12), `RALPH_EXTRA_TOOLS`, `RALPH_CONFIRM_DISCARD`.

## Segurança

O harness parte do princípio de que o agente pode errar **ou ser manipulado** por texto que
lê (código de terceiros, dependências, páginas web). Por isso, as garantias são mecânicas:

| Risco | Proteção |
|---|---|
| Agente altera plano, spec ou `config.json` para o teste passar | O ralph copia esses arquivos antes de cada chamada, compara depois, restaura e conta como falha |
| Revisão falha e a tarefa passa mesmo assim | Só `APROVADO` explícito na primeira linha aprova; qualquer outra coisa reprova |
| "Revisor somente leitura" que escreve | O agente de revisão só tem `Read`, `Grep` e `Glob`; o diff chega pronto em arquivo |
| Prompt injection executando comandos | Lista restrita de ferramentas por padrão; permissões totais só por opção explícita |
| Segredo no commit automático | Varredura de nomes e padrões de chave antes do commit; encontrou, não commita (código 6) |
| Comando de gate gerado pelo modelo | Preflight lista os comandos e marca os que não vêm do `config.json` |
| Saída de ferramenta como instrução | Saída de teste é cercada e marcada como dado nos ciclos de correção |
| Dependência instalada pelo agente | Instalação é sempre tarefa `[humano: aprovação]` |
| Descarte acidental de trabalho | `--descartar-tentativa` exige confirmação humana |
| Leitura de `.env` | `init:context` propõe regras `deny` no `.claude/settings.json` do projeto |

A segurança **do código produzido** é tratada em quatro camadas:

| Camada | Onde |
|---|---|
| Requisito | O `/plan` escreve `RNF` de segurança com `CA` negativos quando a feature toca área sensível |
| Teste | O `sdd-test-agent` prova que o indevido é recusado (usuário B não acessa registro de A) |
| Revisão | Checklist de segurança do `sdd-review-agent`, com atenção redobrada em tarefa `Sensível: sim` |
| Gate mecânico | `commands.security` (auditoria de dependências, análise estática) no fecho da feature |

O `STANDARDS.md` ganhou a seção **Segurança**, que registra como o projeto se protege hoje e
dá ao revisor regras explícitas para cobrar.

O que **não** está coberto: a varredura de segredos procura padrões conhecidos, não todos os
segredos possíveis; o log (`.sdd/logs/`) guarda a saída integral do modelo em texto puro, fora
do git; e com `--permissoes-totais` o agente pode executar qualquer comando.

## Artefatos em `.sdd/`

```
.sdd/
  STANDARDS.md     como se desenvolve (cada regra com origem: observado, decidido, esqueleto)
  config.json      modo, comandos (um por valor, ou lista), paths.frontend, ambiente de
                   verificação de interface e preferências lembradas
  codebase.md      retrato do sistema atual (só projeto existente)
  project.md       descrição do produto (F-NN, E-NN, escopo do MVP)
  roadmap.md       fases, cada uma com a entrada pronta para /plan
  STATE.md         decisões de projeto AD-NNN (criado só quando há decisão)
  specs/<slug>.md  RF-NN, RNF-NN, CA-NN, impacto, histórico de revisões
  plans/<slug>.md  abordagem técnica, riscos, revisões, tarefas T-NN
  logs/<slug>.md   execução (fora do git)
  pendencias.md    ressalvas não bloqueantes acumuladas no fecho das features
```

## Contratos de formato

Os comandos e o `ralph.sh` dependem destes formatos — edite os arquivos à mão respeitando-os.

- **Linhas 2–4 dos artefatos gerados:** identificação, carimbo `sdd:inputs <arquivo>@sha256:<12>`
  (detecta artefato desatualizado) e, nas specs, `sdd:status rascunho|aprovada AAAA-MM-DD`.
- **IDs** (`F-NN`, `E-NN`, `RF-NN`, `CA-NN`, `T-NN`, `R-NN`) nunca são renumerados nem reutilizados.
- **Tarefa** é um bloco que termina na linha em branco:

  ```markdown
  - [ ] T-03 <descrição>
    - Cobre: CA-02, CA-05
    - Depende: T-01
    - Arquivos: `<caminho>`
    - Valida: `<comando>`
    - Sensível: sim — <área> (opcional: auth, autorização, dados pessoais, upload, pagamento...)
    - Interface: <rota> — referência: <tela existente>   (opcional: tarefa que cria/altera tela)
    - Altera config: sim    (opcional: única tarefa que pode gravar o config.json)
    - Revisa: T-01          (opcional, só em tarefa de ajuste)
  ```

- **Tarefa humana:** `[humano: verificação|acesso|aprovação]` logo após o ID. Decisão nunca é
  tarefa — vira `[CLARIFICAR]` na spec, antes da aprovação.
- `## Tarefas` é a última seção do plano; `## Histórico de revisões` é a última da spec.

## Validação dos artefatos

`scripts/sdd-check.sh` concentra as regras estruturais (seções obrigatórias, IDs, cobertura,
dependências, formato de tarefa, motivo de `[humano]`, decisão disfarçada de tarefa, comandos
encadeados no config, obsoleto de volta na spec). Os comandos do plugin o chamam no fim de
cada etapa, e você pode rodá-lo à mão da raiz do projeto:

```bash
sdd-check.sh standards | project | roadmap
sdd-check.sh spec|plan|revise <slug>
```

Saída: `FALHA:` bloqueia, `AVISO:` pede revisão. Código 0 sem falhas, 1 com falhas. Ele
também avisa quando um artefato foi gerado por outra versão do plugin — o sinal de que o
formato mudou numa atualização.

## Testar o harness

```bash
scripts/test-ralph.sh       # ralph.sh com um claude falso: gates, interface, segurança, retomada
scripts/test-sdd-check.sh   # sdd-check.sh com artefatos corretos e com defeitos plantados
```

Nenhum dos dois gasta tokens.

## Mudanças da 2.3.0 (ordem, estados e pendências)

- `/plan`: navegação criada antes da tela que depende dela; critério obrigatório por estado
  terminal do item na tela; carga de verificação com atores duplicados, para verificar os
  critérios negativos na interface; sub-linha `Interface:` com formato fixo.
- Questão respondida volta para a origem: `/plan` e `/revise` marcam a `Q-NN` como resolvida
  no `project.md` e tiram o bloqueio da fase no `roadmap.md`.
- Ressalvas não bloqueantes acumulam em `.sdd/pendencias.md`, em vez de ficarem só no log
  da feature.
- Artefatos carimbam a versão do plugin, e o roteador `/init` roda o `sdd-check` e compara
  versões — formato antigo passa a aparecer como `desatualizado (formato)`.
- `init:context` registra o idioma da interface e das mensagens de validação.

## Mudanças da 2.2.1 (correções)

- `sdd-check.sh` e `ralph.sh` leem JSON com jq, python **ou node** — sem nenhum dos três, o
  check avisa em vez de reprovar e o ralph para com mensagem clara, em vez de rodar sem gate.
- A contagem de regras sem origem no STANDARDS passa a juntar linhas de continuação (a origem
  costuma ficar na quebra, e virava aviso falso).

## Mudanças da 2.2.0 (verificação de interface)

- Novo `sdd-ui-agent`: verificação por navegador (Playwright MCP) em toda tarefa que altera
  frontend e no fecho da feature, com ambiente e banco de verificação separados.
- `init:context` registra `paths.frontend`, a seção **Interface** do STANDARDS e propõe o
  `.mcp.json`; comandos passam a ser um por valor (ou lista), nunca encadeados.
- `/plan` exige critérios de ponto de entrada, retorno após a ação e estados; tarefa de base
  do ambiente de verificação; sub-linhas `Interface:` e `Altera config:`. Sai a oferta de
  ferramenta declarada (`e2e_runner`).
- Validações movidas para `scripts/sdd-check.sh`, com suíte de testes própria.

## Mudanças da 2.1.1 (consistência)

- `ralph.sh` passa a fazer o mesmo fecho do `/implement`: E2E, revisão final da feature
  (fail-closed) e atualização da fase no roadmap.
- Marcadores `[humano]` sem motivo removidos do `/plan` e do `/implement`.

## Mudanças da 2.1.0 (segurança do código produzido)

- Checklist de segurança no `sdd-review-agent`, com exigência de evidência para bloquear.
- `RNF` de segurança com critérios negativos na spec; testes negativos no `sdd-test-agent`.
- Sub-linha opcional `Sensível:` nas tarefas.
- `commands.security` como gate mecânico no fecho (`/implement` e `ralph.sh`).
- Seção **Segurança** no `STANDARDS.md`.

## Mudanças da 2.0.1 (segurança)

- Arquivos protegidos (plano, spec, `config.json`) restaurados se o agente os alterar.
- Revisão *fail-closed*: sem `APROVADO` explícito, não aprova.
- `sdd-review-agent` sem `Bash`; diff entregue pronto em arquivo; sessão de revisão sem
  permissões totais.
- Lista restrita de ferramentas por padrão; `--permissoes-totais` como opção.
- Varredura de segredos antes do commit (código de saída 6).
- Comandos de gate listados no preflight; os que não vêm do `config.json` são marcados.
- Saída de ferramenta cercada como dado; `-y` não confirma descarte.
- Instalação de dependências vira tarefa `[humano: aprovação]`.
- `init:context` propõe bloqueio de leitura de segredos no `.claude/settings.json`.
- Slug validado, lock atômico, arquivos temporários com `mktemp`.

## Mudanças da 2.0

- `/init` virou uma cadeia (`context` → `project` → `roadmap`) com roteador, modo novo/existente
  confirmado e `codebase.md` para projetos existentes.
- Specs com IDs rastreáveis, `[CLARIFICAR]` bloqueando a aprovação, guarda de escopo e checagem
  do que já existe no código.
- Tarefas em bloco com `Cobre`, `Depende`, `Arquivos` e `Valida`.
- Gate de teste mecânico e revisão independente no `/implement` e no `ralph.sh`; novo
  `sdd-review-agent` e comando `/review`.
- `ralph.sh` reescrito: quem marca a tarefa é o script, saída em JSON, ciclos de correção, espera
  de limite de uso, retomada guiada, log e lock fora dos commits, suíte de testes própria.
- `/revise` alinhado aos IDs e ao formato de bloco, com histórico de revisões na spec.
