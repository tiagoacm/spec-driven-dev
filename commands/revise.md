---
description: Aplica uma mudança de requisito a uma feature já especificada — mostra o diff da spec, conduz a aprovação e acrescenta ao plano só as tarefas novas e de ajuste, sem reescrever o que já foi feito.
argument-hint: "<slug> <descrição da mudança>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# revise

Você aplica uma **mudança de requisito** a uma feature existente. Isto é uma revisão, não
uma spec nova: a spec e o plano atuais são a base da verdade, e o que já foi implementado é
preservado. Você só escreve em `.sdd/` (spec, plano e a linha de status da fase no roadmap).

Entrada: `$ARGUMENTS` — primeiro token é o slug; o resto é a descrição da mudança. Sem
descrição, pergunte o que mudou antes de qualquer outra coisa.

## 1. Carregar o estado atual

- `.sdd/specs/<slug>.md` — ausente → pare e recomende `/spec-driven-dev:plan`.
- `.sdd/plans/<slug>.md` — ausente → a feature nem foi planejada: recomende
  `/spec-driven-dev:plan <slug>`, que retoma a spec existente.
- `.sdd/STANDARDS.md`, `.sdd/config.json` e, se existirem, `.sdd/codebase.md` e `.sdd/roadmap.md`.
- As tarefas já `[x]` e o **código que elas produziram** (commits da feature ou os caminhos
  em `Arquivos:`). Nunca avalie impacto sem abrir o código.
- Número da revisão: `R-NN` = quantidade de entradas em `## Revisões` do plano + 1.

```bash
slug=<slug>; s=.sdd/specs/$slug.md; p=.sdd/plans/$slug.md
echo "revisão: R-$(printf '%02d' $(( $(grep -cE '^- \*\*R-[0-9]{2}\*\*' "$p" || true) + 1 )))"
for t in RF RNF CA; do
  m=$(grep -oE "\b$t-[0-9]{2}\b" "$s" | grep -oE '[0-9]{2}$' | sort -n | tail -1)
  echo "próximo $t: $t-$(printf '%02d' $(( 10#${m:-0} + 1 )))"
done
m=$(grep -oE '^- \[.\] T-[0-9]{2}' "$p" | grep -oE '[0-9]{2}$' | sort -n | tail -1)
echo "próxima tarefa: T-$(printf '%02d' $(( 10#${m:-0} + 1 )))"
```

A contagem de IDs olha o arquivo **inteiro**, inclusive o histórico: um ID que já existiu
nunca volta a ser usado.

## 2. Entender a mudança

Reformule a mudança em 1–2 frases e confirme. Se não estiver claro **o que** muda (um
critério? um fluxo? um limite?), pergunte antes de seguir.

### Guarda de tamanho

Revisão ajusta uma feature; não cria outra. Pare e recomende outro caminho se a mudança:

- introduz um **fluxo novo** ou um **ator novo** → spec nova (`/spec-driven-dev:plan`) ou,
  se houver roadmap, fase nova (`/spec-driven-dev:init:project` + `init:roadmap`);
- geraria **mais de ~6 tarefas** novas ou de ajuste → proponha dividir: o essencial entra
  nesta revisão, o resto vira spec própria.

O desenvolvedor pode forçar com "seguir como revisão"; registre isso no resumo da revisão.

## 3. Diff da spec (nada é escrito ainda)

Monte e **mostre** o diff, seção por seção. Seção sem mudança: uma linha dizendo "sem mudanças".

```
Requisitos funcionais
  + RF-05  QUANDO o valor ultrapassar R$ 1.000, O sistema DEVE exigir aprovação do diretor.
  ~ RF-02  antes: SE ... ENTÃO ... reprovar   →   depois: SE ... ENTÃO ... devolver para ajuste
  - RF-03  (obsoleto) aprovação única para qualquer valor

Critérios de aceite
  + CA-07 (RF-05): solicitação de R$ 1.200 aprovada pelo gestor fica "aguardando diretor"
  - CA-03 (obsoleto) — substituído por CA-07
```

Regras do diff:

- **Novos** recebem o próximo ID livre (§1). **Nunca** reutilize nem renumere.
- **Alterados** mantêm o ID; mostre antes e depois.
- **Obsoletos** saem das seções principais e vão para `## Histórico de revisões` (§5). Nunca
  somem sem registro.
- Todo RF novo ou alterado tem pelo menos um CA; todo CA é binário.
- Ambiguidade vira `[CLARIFICAR]` com as opções; decisão nunca vira tarefa.
- Conflito com o `STANDARDS.md` → pare e pergunte.

## 4. Impacto no que já foi implementado

Para cada tarefa `[x]`, verifique no código se ela ficou desalinhada com a spec revisada.
Liste só as afetadas:

```
T-03 (concluída) — app/Approvals/Policy.php:28 aprova em nível único; RF-05 exige segundo nível.
T-05 (concluída) — tests/Feature/ApprovalTest.php:41 testa CA-03, que ficou obsoleto.
```

**Nunca desmarque tarefa concluída.** Cada desalinhamento vira uma **tarefa de ajuste**
proposta (§6), que você confirma antes de entrar no plano.

Tarefas **pendentes** (`[ ]`) que citam critérios obsoletos ou alterados também entram
na lista: elas precisam ser ajustadas no texto (§6).

## 5. Perguntas e aprovação

1. Resolva os `[CLARIFICAR]` com `AskUserQuestion`, numa rodada só. "Decidir depois" mantém
   o marcador e impede a aprovação.
2. Mostre o resumo: diff consolidado, tarefas concluídas afetadas e as tarefas de ajuste
   propostas. Pergunte se aprova; ajustes → refaça o resumo.
3. **Ao aprovar**, e só então, escreva a spec revisada com **Edit**:
   - aplique adições e alterações nas seções principais;
   - remova os obsoletos das seções principais;
   - acrescente (ou crie, como **última** seção) `## Histórico de revisões`:

   ```markdown
   ## Histórico de revisões

   ### R-01 — AAAA-MM-DD — <resumo da mudança em uma linha>
   - Adicionados: RF-05, CA-07
   - Alterado: RF-02 — antes: "SE ... ENTÃO ... reprovar"
   - Obsoleto: RF-03 — "aprovação única para qualquer valor" — substituído por RF-05
   - Obsoleto: CA-03 — "<texto antigo>" — substituído por CA-07
   ```

   Formato fixo, lido por máquina: **um item obsoleto por linha**, começando com
   `- Obsoleto: <ID> —`. As linhas do histórico nunca começam com `- **ID**`, então não
   contam como requisito vigente nas validações.
   - Linha 3: recalcule os carimbos (`STANDARDS.md` e `codebase.md`, se existir).
   - Linha 4: `<!-- sdd:status aprovada AAAA-MM-DD (R-NN) -->`.

A spec final continua **autocontida**: quem ler as seções principais vê só o que vale hoje.

## 6. Plano incremental

Releia a spec revisada do disco. No plano:

**a) Registro da revisão** — seção `## Revisões`, criada logo **antes** de `## Tarefas` se
não existir:

```markdown
## Revisões
- **R-01** AAAA-MM-DD — <resumo> · tarefas: T-08 a T-10 · spec: RF-05, CA-07 (novos); RF-03, CA-03 (obsoletos)
```

**b) Tarefas novas e de ajuste** — acrescentadas **ao final de `## Tarefas`**, continuando
a numeração, no mesmo formato de bloco do `/plan`:

```markdown
- [ ] T-08 Ajustar a política de aprovação para dois níveis acima de R$ 1.000 em `app/Approvals/Policy.php`
  - Cobre: CA-07
  - Depende: nenhuma
  - Arquivos: `app/Approvals/Policy.php`
  - Valida: `<commands.test> --filter ApprovalPolicy`
  - Revisa: T-03
```

- Tarefa de ajuste tem a sub-linha extra `Revisa: T-NN`, **depois** de `Valida:`, apontando
  a tarefa concluída que ela corrige.
- Teste de critério obsoleto: tarefa de ajuste para removê-lo ou reescrevê-lo — teste velho
  passando por um comportamento que não vale mais é pior que teste nenhum.
- Mesmas regras do `/plan`: fatia verificável, `Depende:` só para trás (pode apontar para
  tarefas antigas), `[humano: acesso]` no início do bloco novo e verificação/aprovação no fim.

**c) Tarefas pendentes antigas** que citam critério obsoleto ou alterado: edite **só** as
sub-linhas afetadas (`Cobre:`, `Valida:`) para refletir a spec nova. Não mude o ID nem a
posição. Tarefa pendente que perdeu todo o sentido: substitua a descrição por
`(cancelada em R-NN: <motivo>)`, marque `[x]` e cite no relatório — ela não gera trabalho
nem commit.

**d) Carimbo** — linha 3 do plano com o sha da spec revisada, para `/implement` e `ralph.sh`
pararem de avisar divergência:

```bash
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-12; }
echo "<!-- sdd:inputs .sdd/specs/<slug>.md@sha256:$(h .sdd/specs/<slug>.md) -->"
```

**e) Roadmap e questões** — se a fase estava `implementada (<slug>)`, volte-a para
`planejada (<slug>)`. Se a revisão respondeu alguma `Q-NN` do `project.md`, marque-a lá como
`- **Q-NN** (resolvida em <slug> R-NN): <resposta>` e tire a menção dela dos **Bloqueios**
da fase. Nada mais desses dois arquivos muda.

## 7. Verificar

```bash
SDD_CHECK="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/sdd-check.sh}"
[ -f "$SDD_CHECK" ] || SDD_CHECK=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1)
bash "$SDD_CHECK" revise <slug>
```

Valida spec, plano e as regras da revisão (obsoletos fora das seções principais, nenhuma
pendente citando obsoleto, histórico como última seção, `Revisões` antes de `Tarefas`,
`Revisa:` apontando tarefa concluída, status com `R-NN`). Cada `FALHA` → corrija e rode de
novo. Script não encontrado → **pare** e avise.

## 8. Relatório

No máximo:
- número da revisão e resumo da mudança;
- IDs adicionados, alterados e obsoletos;
- tarefas concluídas afetadas e as tarefas de ajuste criadas;
- tarefas pendentes editadas ou canceladas;
- fase do roadmap reaberta, se for o caso;
- próximo passo: `/spec-driven-dev:implement <slug>` ou `ralph.sh <slug>` (ver README) — a execução
  continua da primeira tarefa pendente.

## Regras

- Nada é escrito antes da aprovação do diff.
- Nunca desmarque tarefa concluída; nunca reutilize nem renumere IDs.
- Nunca reescreva o plano inteiro: só a seção `## Revisões`, o fim de `## Tarefas`, sub-linhas
  de tarefas pendentes afetadas e a linha 3.
- Nunca escreva código de aplicação. Nunca leia arquivos de segredo. Nenhuma escrita no git.
