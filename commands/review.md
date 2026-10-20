---
description: Roda a revisão independente de uma feature (ou de um diff qualquer) contra os critérios de aceite da spec e os padrões do projeto, sem alterar nada.
argument-hint: "<slug> | --diff <range git> [--spec <slug>]"
allowed-tools: Read, Grep, Glob, Bash, Task
---

# review

Revisão independente sob demanda. Mesmo agente que o `/implement` usa no fecho, disponível
para rodar sozinho — inclusive sobre código escrito fora do harness. **Nada é alterado.**

Entrada: `$ARGUMENTS`.

## 1. Resolver o alvo

- **`<slug>`** → spec `.sdd/specs/<slug>.md` e plano `.sdd/plans/<slug>.md`. O diff é o
  intervalo dos commits da feature. Sem como determiná-lo, use os commits que citam as
  tarefas (`git log --oneline --grep="T-[0-9]"`) ou pergunte o range.
- **`--diff <range>`** (ex.: `main..HEAD`, `HEAD~5..HEAD`) → revisa esse diff. Com `--spec`,
  usa aquela spec como referência; sem ela, a referência é só o `.sdd/STANDARDS.md` — diga
  isso no relatório, porque sem spec não há verificação de critérios.

```bash
d=.sdd/logs/review-<slug-ou-diff>.diff; mkdir -p .sdd/logs
git diff <range> > "$d"
git diff --stat <range> | tail -1
```

Diff vazio → informe e pare. O revisor não roda comandos: ele recebe o **caminho** desse
arquivo e lê tudo de lá.

## 2. Delegar

Invoque o `sdd-review-agent` via Task, em modo `feature`, passando slug, o caminho do
arquivo de diff e os caminhos da spec, do plano e do `STANDARDS.md`. Você não revisa por conta própria: a revisão
só vale feita por quem não escreveu o código, e nesta sessão isso é o subagente.

Diff grande (mais de ~40 arquivos): divida por módulo em invocações separadas e junte os
vereditos, informando o agrupamento usado.

## 3. Reportar

Se a primeira linha do parecer não for um veredito (`APROVADO`, `APROVADO COM RESSALVAS` ou
`REPROVADO`), diga que a revisão **não foi concluída** — nunca apresente como aprovação.
Repasse o parecer como veio, sem suavizar: veredito, cobertura critério a critério,
bloqueantes e ressalvas. Depois acrescente, em no máximo três linhas, o que fazer:

- Bloqueantes com a feature ainda aberta → `/spec-driven-dev:implement <slug>` resolve nos
  ciclos de correção.
- Bloqueantes com a feature já fechada → decida com o desenvolvedor: correção pontual agora
  ou `/spec-driven-dev:revise <slug>` se a spec também mudar.
- Critério não atendido que na verdade nunca foi pedido → é lacuna de spec, não de código:
  `/spec-driven-dev:revise <slug>`.

## Regras

- Não escreva, edite nem corrija nada. Não rode testes, build ou instalação.
- Não aprove por educação: o veredito do agente vai como está.
- Não leia arquivos de segredo.
