---
description: Passo 3 da cadeia init — divide o projeto descrito em .sdd/project.md em fases numeradas e entregáveis, cada uma pronta para virar a entrada de um /plan, em .sdd/roadmap.md.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# init:roadmap

Você define **em que ordem** o produto será construído. Cada fase do roadmap é uma fatia
entregável e verificável, do tamanho certo para um único `/plan`. O roadmap **não** contém
tarefas técnicas — elas nascem no `/plan` de cada fase.

## Pré-condições

- `.sdd/project.md` e `.sdd/STANDARDS.md` existem. Se não, pare e recomende `/spec-driven-dev:init`.
- Leia os dois por completo, além de `.sdd/config.json`, `.sdd/STATE.md` (se existir) e
  `.sdd/design/` (se existir — referências de telas; nunca é obrigatório).
- Em brownfield, amostre o código para saber o que **já existe** e não planejar de novo.

## Reexecução (upsert)

Se `.sdd/roadmap.md` já existe:

- Leia-o antes de qualquer coisa. Descubra o que mudou em `project.md` (fluxos/entidades
  novos, removidos ou alterados) comparando com a seção **Cobertura**.
- Fases com status `planejada` ou `implementada` são **congeladas**: não renumere, não mude
  o título nem o escopo. Se a mudança no projeto afetar uma delas, **não a edite** — liste
  no relatório e recomende `/spec-driven-dev:revise <slug>` para aquela feature.
- Fases `pendente` podem ser ajustadas com **Edit**. Fases novas recebem o próximo número
  no fim, a menos que a dependência obrigue a vir antes de outra `pendente` — nesse caso,
  pergunte antes de renumerar pendentes.
- Nunca altere o campo **Status** de nenhuma fase (quem altera é `/plan` e `/implement`).

## 1. Montar as fases

Princípios:

1. **Fatia vertical entregável.** Cada fase termina com algo que pode ser demonstrado de
   ponta a ponta (tela → regra → persistência → teste), não com "a camada de models pronta".
2. **Fundação só quando necessária.** Uma fase inicial de fundação (autenticação, layout
   base, perfis/permissões, estrutura compartilhada) só existe se várias fases dependerem
   dela — e ela também precisa de uma entrega demonstrável.
3. **Dependências primeiro.** Uma fase só depende de fases anteriores (número menor).
4. **Tamanho de um /plan.** Uma fase deve gerar, estimadamente, de 4 a 12 tarefas. Mais
   que isso → divida em fronteira real de dependência. Menos que 3 → junte com a vizinha.
5. **Caminho feliz antes das bordas**, quando o fluxo for grande: F-01 básico numa fase,
   rejeição/cancelamento/notificações em outra — desde que cada uma seja entregável.
6. **Questões em aberto bloqueiam.** Se uma questão de `project.md` afeta uma fase, a fase
   indica isso em **Bloqueios**. Prefira ordenar fases bloqueadas depois das livres.
7. Só o que está **Dentro** do MVP entra no roadmap. Itens "Fora" aparecem apenas na seção
   **Depois do MVP**.

Se houver mais de uma divisão razoável (ex.: por ator vs. por fluxo), apresente as opções
com `AskUserQuestion` antes de escrever. Apresente a lista de fases (número, título, uma
linha de objetivo, dependências) e **só escreva após confirmação** ou ajustes.

## 2. Escrever `.sdd/roadmap.md`

Idioma do desenvolvedor. Três primeiras linhas fixas:

```markdown
# <Nome do Projeto> — Roadmap
<!-- sdd:generated-by init:roadmap v<versão do plugin> — upsert: fases planejadas/implementadas são congeladas; Status é atualizado por /plan e /implement -->
<!-- sdd:inputs .sdd/project.md@sha256:<12 hex> .sdd/STANDARDS.md@sha256:<12 hex> -->
```

```bash
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-12; }
echo ".sdd/project.md@sha256:$(h .sdd/project.md) .sdd/STANDARDS.md@sha256:$(h .sdd/STANDARDS.md)"
```

Contrato de formato (lido por máquina):

- Cada fase começa com `## Fase N: <título>` — dois-pontos, numeração contínua a partir de 1.
- As **únicas** outras seções `##` permitidas são `## Cobertura` e `## Depois do MVP`,
  ambas **depois** da última fase.
- O campo de status é exatamente `- **Status**: pendente` (valores válidos: `pendente`,
  `planejada (<slug>)`, `implementada (<slug>)`).

```markdown
## Fase 1: <título curto>
- **Status**: pendente
- **Objetivo**: <1–2 frases: o que passa a funcionar ao fim da fase>
- **Cobre**: F-01 (caminho feliz), E-01, E-02
- **Depende de**: nenhuma | Fase N, ...
- **Bloqueios**: nenhum | Q-NN (<resumo>)
- **Entrega verificável**: <o que se demonstra ao final, de forma observável —
  ex.: "colaborador cria e envia uma solicitação; ela aparece como 'enviada' na listagem">
- **Telas de referência**: <caminhos em .sdd/design/ ou "nenhuma">
- **Entrada para /plan**:
  - slug sugerido: `<kebab-case>`
  - descrição: <2–4 frases autocontidas, citando os F-NN/E-NN e o que está fora desta fase>

## Fase 2: ...

## Cobertura
| Item | Fases |
|---|---|
| F-01 | 1, 3 |
| E-01 | 1 |

## Depois do MVP
- <itens "Fora" do project.md, sem fase atribuída — ou "Nenhum.">
```

Regras de conteúdo:

- Todo F-NN e E-NN **dentro do MVP** aparece em pelo menos uma fase na tabela Cobertura.
- Nenhuma fase cita um ID que não existe em `project.md`.
- A **Entrada para /plan** tem que funcionar sozinha: quem ler só ela entende o escopo da fase.
- Nada de tarefas técnicas, nomes de classes, tabelas ou rotas.

## 3. Verificar antes de encerrar

```bash
SDD_CHECK="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/sdd-check.sh}"
[ -f "$SDD_CHECK" ] || SDD_CHECK=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1)
bash "$SDD_CHECK" roadmap
```

Cada `FALHA` → corrija e rode de novo. `AVISO` de item sem cobertura só é aceitável para o
que está fora do MVP. Confira também, à mão, que o **Cobre** de cada fase inclui toda
entidade que a **Entrega verificável** dela menciona (ex.: fase que notifica cobre a
entidade de notificação).

## 4. Relatório

Responda com, no máximo:
- lista das fases (número, título, dependências, bloqueios);
- itens do MVP sem cobertura (deve ser nenhum);
- em reexecução: fases alteradas, fases novas e fases congeladas afetadas (com o `/revise` recomendado);
- próximo passo: `/spec-driven-dev:plan` com a **Entrada para /plan** da primeira fase `pendente` sem bloqueio.

## Regras

- Nunca escreva código, spec ou plano de tarefas.
- Escreva somente `.sdd/roadmap.md`.
- Nunca altere o campo Status. Nenhuma escrita no git.
