---
description: Gera a spec de uma feature, conduz a aprovação com você e emenda o plano de tarefas executável pelo ralph.sh. Retoma de onde parou se a spec já existir.
argument-hint: "<descrição da feature> | <slug existente> | fase <N> [--so-spec] [--simples|--completa] [--forcar-escopo]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# plan

Você conduz uma feature de "ideia" até "plano executável", em uma única execução:
**spec → perguntas → aprovação → plano**. Você nunca escreve código de aplicação; só
escreve dentro de `.sdd/` (e o campo Status da fase em `.sdd/roadmap.md`).

Entrada do desenvolvedor:

```
$ARGUMENTS
```

Flags: `--so-spec` (para após a aprovação da spec, sem gerar o plano) ·
`--simples` / `--completa` (força o nível) · `--forcar-escopo` (ignora a guarda de escopo).

## 1. Resolver a entrada

1. **`fase <N>`** → leia `.sdd/roadmap.md`, pegue a seção `## Fase N:` e use a **Entrada
   para /plan** (slug sugerido + descrição). Fase inexistente → pare e liste as fases.
2. **Slug existente** (casa com `.sdd/specs/<arg>.md`) → é retomada; siga o estado (§2).
3. **Descrição livre** → derive o slug: kebab-case, sem acento, 2–4 palavras, até 40
   caracteres. Confirme o slug junto com a primeira pergunta que fizer.

## 2. Estado (decide o que esta execução faz)

```bash
slug=<slug>; s=.sdd/specs/$slug.md; p=.sdd/plans/$slug.md
test -f "$s" && sed -n '4p' "$s" || echo "sem spec"
test -f "$p" && echo "plano existe"
```

| Situação | O que fazer |
|---|---|
| Sem spec | §3 (sobreposição + guarda de escopo) → §4 → §5 → §6 |
| Spec `rascunho` | §4 (perguntas/aprovação) → §5 → §6 |
| Spec `aprovada`, sem plano | §6 |
| Spec `aprovada`, com plano | **Não sobrescreva.** Informe que a feature já está planejada e recomende `/spec-driven-dev:revise <slug>`. Só refaça se o desenvolvedor confirmar explicitamente que quer descartar o plano atual. |

## 3. Escrever a spec

### 3.1 Contexto (leia antes de escrever)

- `.sdd/STANDARDS.md` — obrigatório. Ausente → pare e recomende `/spec-driven-dev:init`.
- `.sdd/config.json` — `commands.test` define como a feature será validada.
- `.sdd/codebase.md`, se existir — o que o sistema já faz.
- `.sdd/project.md` e `.sdd/roadmap.md`, se existirem — fluxos `F-NN`, entidades `E-NN`, fase.
- Specs vizinhas em `.sdd/specs/` que tocam a mesma área.
- **O código real da área afetada** (Glob/Grep/Read). Nunca descreva impacto sem abrir o arquivo.

### 3.2 O que já existe (antes de especificar)

Só se aplica quando `config.json` → `project_mode` é `brownfield` (ou quando há
`.sdd/codebase.md`). Objetivo: não replanejar o que o sistema já faz.

1. Procure a capacidade pedida no `codebase.md` (módulos, `RN-NN`, interfaces) e confirme no
   código com Glob/Grep — nomes de rota, tela, método, coluna. O `codebase.md` é um resumo:
   a palavra final é o código.
2. Classifique o que encontrou:
   - **Não existe** → siga normalmente.
   - **Existe parcialmente** (a base está lá, falta o comportamento pedido) → informe o que
     achou, com `arquivo:linha`, e trate a feature como **extensão**: o que já funciona entra
     em **Fora** do escopo e em **Impacto no código existente**, nunca como requisito novo.
   - **Já existe por completo** → **não escreva a spec**. Mostre a evidência e pergunte:
     é para estender, substituir ou o comportamento atual está com defeito? Correção de
     defeito também vira spec, mas com o comportamento atual descrito no Objetivo.
3. Registre o resultado em uma linha no Objetivo da spec
   (ex.: "estende o upload de anexos já existente em `app/Uploads/…:32`").

Nunca escreva um requisito que descreva comportamento já implementado como se fosse novo.

### 3.3 Guarda de escopo (antes de escrever qualquer coisa)

Uma spec cobre **uma fatia entregável**, nunca um sistema inteiro. Antes de escrever, esboce
mentalmente os requisitos que a entrada geraria e conte os sinais de escopo grande:

- a entrada cobre **mais de um fluxo** `F-NN` do `project.md` (ou, sem project.md, mais de um
  fluxo de ponta a ponta);
- o esboço passa de **~6 requisitos funcionais** ou de **~12 tarefas**;
- envolve **mais de um ator** com jornadas distintas, ou mais de um módulo com regras próprias;
- a descrição nomeia o sistema/produto em vez de uma capacidade
  (ex.: "sistema de despesas" vs. "envio de solicitação de despesa").

**Zero sinais** → siga para §3.3. **Um sinal** → siga, mas registre o recorte adotado em
**Fora** do escopo. **Dois ou mais sinais** → **não escreva a spec**. Faça o seguinte, na ordem:

1. **Existe `.sdd/roadmap.md`** → identifique a(s) fase(s) que cobrem a entrada. Mostre a lista
   (número, título, objetivo em uma linha) e pergunte com `AskUserQuestion` qual planejar
   agora. Escolhida a fase, siga o fluxo normal com a **Entrada para /plan** dela.
2. **Existe `.sdd/project.md` sem roadmap** → pare e recomende `/spec-driven-dev:init`
   (passo `init:roadmap`), explicando em uma linha que o roadmap divide o produto em fases
   do tamanho de um plano.
3. **Nenhum dos dois** (projeto existente, sem cadeia init) → proponha você mesmo o recorte:
   liste de 3 a 6 fatias entregáveis, em ordem de dependência, cada uma com título, objetivo
   em uma linha e o que ela deixa de fora. Pergunte qual planejar agora e siga só com ela.
   Ofereça, em uma linha, rodar `/spec-driven-dev:init` para registrar esse recorte como
   roadmap — sem insistir.

Nunca escreva a spec "mesmo assim, resumindo". Escopo grande demais é motivo de parada, não
de compressão. O desenvolvedor pode forçar com `--forcar-escopo`; nesse caso, registre no
Objetivo que o escopo foi ampliado por decisão explícita.

### 3.4 Nível

- **simples**: até 3 RF, um módulo, nenhum RNF relevante, sem mudança de contrato externo.
- **completa**: o resto.

Classifique, diga o nível em uma linha junto da primeira pergunta e siga. `--simples` /
`--completa` sobrescrevem sem perguntar. Em nível simples, omita as seções marcadas
`(completa)` no gabarito.

### 3.5 Conteúdo

Idioma do desenvolvedor. Quatro primeiras linhas fixas:

```markdown
# Spec: <título da feature>
<!-- sdd:generated-by plan v<versão do plugin> -->
<!-- sdd:inputs .sdd/STANDARDS.md@sha256:<12 hex> [.sdd/codebase.md@sha256:<12 hex>] -->
<!-- sdd:status rascunho -->
```

```bash
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-12; }
for f in .sdd/STANDARDS.md .sdd/codebase.md; do [ -f "$f" ] && printf '%s@sha256:%s ' "$f" "$(h "$f")"; done; echo
SDD_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$SDD_ROOT" ] || SDD_ROOT=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1 | sed 's|/scripts/sdd-check.sh$||')
grep -oE '"version"[^,]*' "$SDD_ROOT/.claude-plugin/plugin.json" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
```

Seções (exatamente estas `##`, nesta ordem):

```markdown
## Objetivo
<2–3 frases: o que resolve e para quem. Cite F-NN/fase do roadmap quando houver.>

## Escopo
- **Dentro:** <capacidades desta feature>
- **Fora:** <o que fica para depois>
- **Não-objetivos:** <o que nunca será feito aqui>

## Requisitos funcionais
- **RF-01** — QUANDO <gatilho>, O sistema DEVE <resposta observável>.
- **RF-02** — SE <condição de exceção>, ENTÃO O sistema DEVE <resposta>.
- **RF-03** — ENQUANTO <estado>, O sistema DEVE <resposta>.

## Requisitos não-funcionais (completa — ou sempre que houver requisito de segurança)
- **RNF-01** — <sempre quantificado: número, unidade, limite>
- **RNF-02** (segurança) — <quem pode o quê, e o que acontece com quem não pode>

## Critérios de aceite
- **CA-01** (RF-01): <condição binária, verificável sem interpretação>

## Impacto no código existente
- `<arquivo>:<linha>` — <o que muda ou é reaproveitado>
<ou "Nenhum — área nova.">

## Pontos a esclarecer
- **[CLARIFICAR]** <pergunta>. Opções: <A> | <B>. Afeta: <RF-NN/CA-NN>.
<ou "Nenhum.">

## Como se valida
Comando: `<commands.test do config.json>`
<Sem comando de teste no projeto, use: "Não há teste automatizado neste projeto — ver §
Validação sem suíte de testes no plano.">
```

Regras de conteúdo:

- **Só três formas de RF** (evento, exceção, estado), sempre com resposta **observável**.
  Nada de "o sistema deve ser robusto".
- **Todo CA é binário** e cita os RF que verifica. Todo RF tem pelo menos um CA.
- **Ambiguidade nunca vira palpite** — vira `[CLARIFICAR]` com as opções em jogo.
- **Impacto exige evidência**: abra o arquivo e cite a linha. Caminho que não existe no
  disco não entra (ou entra como "novo").
- **Sem detalhe de implementação** (nomes de classe, assinatura de método, SQL): isso é §6.
- **Interface é requisito, não só aparência.** Se a feature tem tela, a spec traz, para
  cada capacidade visível, critérios de:
  - **ponto de entrada** — por onde o ator chega à tela, pela navegação existente
    (ex.: "**CA-10**: colaborador acessa *Nova solicitação* pelo menu lateral");
  - **retorno após a ação** — o que o usuário vê depois de agir (mensagem de sucesso,
    redirecionamento, lista atualizada, formulário limpo);
  - **estados** — vazio (sem itens), erro (falha ao salvar) e, quando houver espera
    perceptível, carregando;
  - **estado do item na tela** — quando a tela age sobre algo que muda de estado, um
    critério por estado terminal dizendo **o que a tela mostra e o que ela esconde**
    (ex.: "**CA-16**: solicitação já decidida não mostra os botões aprovar/reprovar;
    mostra o estado atual e, se reprovada, o motivo"). Sem isso, o gate aprova uma tela
    que oferece ação impossível — o servidor recusa e o usuário não entende;
  - **erro de validação visível no campo** correspondente, não só a rejeição no servidor.
  Tela que o usuário não consegue alcançar, ou ação sem retorno, é defeito — e só vira
  teste se estiver escrita aqui.
- **Segurança é requisito, não só revisão.** Se a feature toca autenticação, autorização,
  dados pessoais, upload, pagamento, valores monetários ou montagem de consulta com entrada
  do usuário, escreva `RNF` de segurança explícitos, marcados `(segurança)`, com `CA`
  **negativos** — ex.: "**CA-06** (RNF-02): usuário de outra área que acessa a URL da
  solicitação recebe acesso negado e nenhum dado dela". Mesmo em nível simples, essa
  seção existe quando houver requisito de segurança. Na dúvida sobre a regra de acesso,
  é `[CLARIFICAR]`, nunca suposição.
- **Conflito com o STANDARDS** (a feature exige quebrar um padrão): **pare** e pergunte
  antes de continuar; registre a resposta como RNF ou nota no Objetivo.

## 4. Perguntas e aprovação

Na mesma execução, sem gerar nada de plano ainda:

1. **Resolva os `[CLARIFICAR]`.** Use `AskUserQuestion` com as opções que você mesmo
   levantou; agrupe todos numa rodada. Aplique as respostas com **Edit**: o marcador some,
   o RF/CA fica explícito. Se alguma resposta for "decidir depois", o item **permanece**
   como `[CLARIFICAR]` e a spec não pode ser aprovada.
2. **Mais de 3 marcadores em aberto** → não ofereça aprovação. Diga que a feature está pouco
   definida e resolva os marcadores primeiro (ou sugira reduzir o escopo).
3. **Resumo + aprovação.** Mostre: nível, contagem de RF/RNF/CA, arquivos impactados, o que
   ficou **Fora** e os riscos que você enxerga. Pergunte se aprova.
4. **Ajustes** → edite a spec e repita o resumo. Quantas voltas forem necessárias.
5. **Ao aprovar**:
   - `<!-- sdd:status aprovada AAAA-MM-DD -->` (linha 4, via Edit);
   - se veio de fase do roadmap, mude **só** a linha de status da fase:
     `- **Status**: pendente` → `- **Status**: planejada (<slug>)`;
   - **questões resolvidas voltam para a origem**: se a spec respondeu (ou constatou já
     resolvida) alguma `Q-NN` do `project.md`, edite lá a linha da questão para
     `- **Q-NN** (resolvida em <slug>): <a resposta em uma linha>` e remova a menção dela
     dos **Bloqueios** da fase no `roadmap.md`. Sem isso, a questão reaparece na próxima
     entrevista e o roadmap segue anunciando um bloqueio que não existe mais;
   - se `--so-spec`, pare aqui e informe que `/plan <slug>` gera o plano depois.

## 5. Verificar a spec

As regras estruturais estão no validador do plugin:

```bash
SDD_CHECK="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/sdd-check.sh}"
[ -f "$SDD_CHECK" ] || SDD_CHECK=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1)
bash "$SDD_CHECK" spec <slug>
```

Cada `FALHA` → corrija e rode de novo. Script não encontrado → **pare** e avise: nunca
aprove uma spec sem validar. `[CLARIFICAR]` em aberto impede a aprovação (§4).

## 6. Gerar o plano

Releia a spec aprovada do disco. Escreva `.sdd/plans/<slug>.md`:

```markdown
# Plano: <título da feature>
<!-- sdd:generated-by plan v<versão do plugin> -->
<!-- sdd:inputs .sdd/specs/<slug>.md@sha256:<12 hex> -->

## Abordagem técnica
<Onde a feature encaixa na arquitetura do STANDARDS; que dados/entidades entram; que
interfaces surgem. Liste **Novo:** e **Alterado:**. Em nível simples, 3–5 linhas bastam.>

## Riscos
- <risco> — <mitigação> <ou "Nenhum relevante.">

## Tarefas

- [ ] T-01 <descrição objetiva e autocontida, citando o arquivo/módulo afetado>
  - Cobre: CA-01, CA-02
  - Depende: nenhuma
  - Arquivos: `<caminho>`, `<caminho>` (novo)
  - Valida: `<comando executável>`

- [ ] T-02 [humano: verificação] <tarefa que só uma pessoa pode executar>
  - Cobre: CA-04
  - Depende: T-01
  - Arquivos: `<caminho>`
  - Valida: <critério manual>
```

Sub-linhas **opcionais**, sempre depois de `Valida:`:

- `Sensível: sim — <área>` quando a tarefa toca autenticação, autorização, dados pessoais,
  upload, pagamento, valores monetários ou consulta montada com entrada do usuário
  (ex.: `Sensível: sim — autorização por área`). Ela faz a revisão aplicar o checklist de
  segurança com atenção redobrada. Omitir em tarefa sensível é erro; marcar tudo como
  sensível também — dilui o sinal.
- ``Interface: `<rota>` — referência: `<arquivo da tela existente>` `` em toda tarefa que
  cria ou altera tela — sempre com crases nos dois, e a rota começando por `/`. A referência é uma tela que já existe e representa o padrão a seguir
  (a seção **Interface** do STANDARDS indica uma). O verificador de interface compara com ela.
- `Altera config: sim` na **única** tarefa autorizada a alterar `.sdd/config.json` (a de
  base da verificação de interface, §6). Sem essa linha, qualquer mudança no `config.json`
  durante a execução é desfeita e conta como falha.
- `Revisa: T-NN` (só em tarefa de ajuste, criada pelo `/revise`).

Contrato de formato (o `ralph.sh` recorta o **bloco inteiro**, não só a primeira linha):

- A tarefa começa em `- [ ] T-NN ` (numeração contínua a partir de 01) e termina na próxima
  linha em branco. As quatro sub-linhas são indentadas com 2 espaços, exatamente nesta
  ordem: `Cobre:`, `Depende:`, `Arquivos:`, `Valida:`.
- `## Tarefas` é a **última** seção `##` do arquivo.
- `[humano: <motivo>]` logo após o ID marca tarefa que o ralph não executa. Motivos válidos:
  `verificação` (conferir algo observável), `acesso` (credencial, ambiente, dado de terceiro),
  `aprovação` (autorização de alguém). Nenhum outro valor é aceito.

Regras de decomposição:

- **Até 12 tarefas.** Passou de 12, a fatia está grande demais: **não escreva o plano**.
  Mostre a decomposição proposta agrupada em 2–3 fatias menores, cada uma com os `CA-NN` que
  cobre, e pergunte qual virar plano agora (as outras viram fases novas no roadmap, se ele
  existir, ou specs futuras). Planos de 2–3 tarefas são legítimos em nível simples.
- Cada tarefa é uma **fatia verificável**: termina com algo que passa num teste ou numa
  verificação observável. Nada de "criar as models" sem uso.
- `Depende:` só aponta para tarefas **anteriores**.
- **Navegação antes da tela que depende dela.** Tarefa que será verificada na interface só
  entra depois das tarefas que criam o que ela precisa para ser alcançada e para onde ela
  volta: item de menu, listagem de origem, rota de destino do redirect. Uma tela de detalhe
  vem depois da listagem que leva a ela; o item de menu vem junto da primeira tela do fluxo.
  Ordem invertida força um contorno temporário (voltar para a própria tela porque o destino
  ainda não existe) que vira retrabalho na revisão seguinte.
- `Valida:` traz um comando derivado de `config.json` → `commands` (tipicamente
  `commands.test` ou `commands.test_filter` com o filtro preenchido) ou, em tarefa
  `[humano: ...]`, o critério manual. **Nunca** comandos arbitrários, encadeamentos (`;`,
  `&&`, `|`) ou redirecionamentos: o `ralph.sh` executa esse texto, e marca como suspeito
  tudo o que não começa por um comando do `config.json`.
- Toda tarefa cita pelo menos um `CA-NN`; todo `CA-NN` aparece em pelo menos uma tarefa.
- Tarefas que **escrevem o teste** de um CA são explícitas — testes não são subentendidos.

### Decisão não é tarefa

Uma tarefa nunca pode ser "decidir", "definir", "escolher", "avaliar qual" ou "confirmar com
alguém qual regra vale". Isso é lacuna de requisito, e requisito se resolve **na spec, antes
da aprovação**. Encontrou uma ao decompor?

1. **Volte à spec**: transforme em `[CLARIFICAR]` com as opções em jogo.
2. Pergunte ao desenvolvedor (§4) e aplique a resposta no RF/CA correspondente.
3. Só então escreva o plano.

Se a decisão depender de alguém que não está aqui agora, a spec não está pronta: registre o
`[CLARIFICAR]`, informe que o plano fica bloqueado por ele e pare. Um plano com decisão
pendente dentro vira retrabalho na implementação.

### Onde ficam as tarefas humanas

- `[humano: acesso]` → no **início**, como pré-requisito, antes de qualquer tarefa que dependa
  daquele acesso.
- `[humano: verificação]` e `[humano: aprovação]` → no **fim**, junto do fecho da feature.
- Dependência técnica que obrigue uma tarefa humana a ficar no meio é exceção: mantenha, e
  diga no relatório que o `ralph.sh` vai parar ali.

O objetivo é deixar o miolo do plano contínuo, para a execução autônoma não ser interrompida.

### Validação sem suíte de testes

Se `config.json` → `commands.test` for `null` (ou o comando existir mas a área afetada não
tiver nenhum teste, o que o `codebase.md` mostra em "Cobertura de testes existente"):

1. **Não invente um comando.** `Valida:` com comando inexistente quebra o `ralph.sh` e faz o
   agente declarar sucesso sem verificação.
2. **Proponha a base mínima** como `T-01`: instalar/configurar o runner (quando não houver) e
   escrever o primeiro teste que cobre o caminho principal da área afetada — nada além do
   necessário para esta feature. Explique em uma linha por que ela existe e confirme com o
   desenvolvedor antes de escrever o plano.
3. **Recusada a base mínima**, toda tarefa vira `[humano: verificação]` com critério de verificação
   observável em `Valida:` (passo a passo na tela, comando manual, consulta ao banco). Deixe
   explícito no relatório que o `ralph.sh` **não** pode rodar este plano de forma autônoma.
4. Se o runner existir mas a área não tiver testes, a base mínima é só o primeiro teste —
   não configure nada de novo.

### Verificação de interface

A feature altera arquivos em `config.json` → `paths.frontend` e `preferences.ui_verify` é
`"aceito"`? Então cada tarefa que toca frontend será verificada num navegador pelo
`sdd-ui-agent` — e isso precisa de um ambiente pronto.

**Ambiente ainda não configurado** (`commands.verify_prepare` ou `environment.verify_url`
vazios): a **primeira** tarefa do plano é a base, obrigatória, não uma oferta:

```markdown
- [ ] T-01 Prepara o ambiente de verificação de interface: banco próprio (ex.: SQLite em
  arquivo separado), carga com um usuário por ator com senha fictícia, comando para recriar
  e popular, comando para servir a aplicação numa porta própria, e registro no config.json
  - Cobre: <CA de ponto de entrada da feature>
  - Depende: nenhuma
  - Arquivos: `<arquivo de ambiente de verificação>`, `<seeder/fixture de usuários>`, `.sdd/config.json`
  - Valida: `<comando de teste que confere a carga de usuários>`
  - Altera config: sim
```

A carga precisa permitir verificar também os **critérios negativos**: pelo menos **dois
usuários de cada papel que age sobre dados de outro** (ex.: dois gestores, cada um com seu
colaborador) e registros cruzados entre eles, para que "o usuário A tenta acessar o dado de
B" seja verificável na tela, e não só no teste de backend. Inclua também ao menos um
registro em cada estado que as telas exibem.

A tarefa grava `commands.verify_prepare` (recria e popula o banco de verificação),
`commands.verify_serve` (sobe a aplicação apontando para ele), `environment.verify_url` e
`environment.verify_users` (`{"colaborador": "<email>", ...}` e a senha fictícia). Cada
comando é **um** comando, sem encadeamento. O banco de desenvolvimento nunca é usado pela
verificação.

Se montar esse ambiente exigir pacote novo, a instalação é uma tarefa `[humano: aprovação]`
antes desta, com o comando literal em `Valida:`.

**`preferences.ui_verify` recusado:** não há verificação por navegador; os critérios de
interface ficam cobertos por teste automatizado quando possível e, o que não for, por uma
tarefa `[humano: verificação]` no fim do plano.

**`commands.e2e` existente** (testes E2E versionados que o projeto já tenha): continuam
rodando no fecho da feature; não substituem a verificação de interface por tarefa.

## 7. Verificar o plano

```bash
SDD_CHECK="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/sdd-check.sh}"
[ -f "$SDD_CHECK" ] || SDD_CHECK=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1)
bash "$SDD_CHECK" plan <slug>
```

Cada `FALHA` → corrija e rode de novo. Script não encontrado → **pare** e avise.

## 8. Relatório

No máximo:
- nível, slug e caminhos dos dois artefatos;
- contagem de RF/CA e de tarefas, com as `[humano: ...]` destacadas;
- riscos e o que ficou fora do escopo;
- próximo passo: `/spec-driven-dev:implement <slug>` (interativo) ou
  `ralph.sh <slug>` (ver README) (automatizado).

## Regras

- Nunca escreva código de aplicação, migration, teste ou configuração do projeto.
- Escreve apenas: `.sdd/specs/<slug>.md`, `.sdd/plans/<slug>.md` e a linha de status da fase
  em `.sdd/roadmap.md`.
- Nunca leia arquivos de segredo (`.env` e equivalentes).
- Nenhuma escrita no git: nunca `add`, `commit`, `reset`.
