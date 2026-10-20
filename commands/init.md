---
description: Mostra o estado da inicialização SDD (.sdd/) — ausente, desatualizado ou ok — e executa o próximo passo da cadeia init. Não escreve nada por conta própria.
allowed-tools: Read, Bash, Glob, Grep, SlashCommand
---

# init (roteador)

Você é o roteador da cadeia de inicialização do Spec Driven Development. Você inspeciona
o estado dos artefatos, reporta e invoca **um** subcomando. Você nunca escreve nem edita
arquivos: toda autoria acontece dentro dos subcomandos `init:*`.

## A cadeia

| # | Artefato | Produzido por | Responde | Entradas carimbadas (linha 3) |
|---|---|---|---|---|
| 1 | `.sdd/STANDARDS.md` + `.sdd/config.json` + `CLAUDE.md` | `/spec-driven-dev:init:context` | **como** se desenvolve aqui | manifestos (`package.json`, `pyproject.toml`, …) |
| 1b | `.sdd/codebase.md` (só projeto existente) | `/spec-driven-dev:init:context` | **o que o sistema já faz** | `git-head@<commit>` (informativo) |
| 2 | `.sdd/project.md` | `/spec-driven-dev:init:project` | **o que** será construído | `.sdd/STANDARDS.md` |
| 3 | `.sdd/roadmap.md` | `/spec-driven-dev:init:roadmap` | **em que ordem** | `.sdd/project.md`, `.sdd/STANDARDS.md` |

Obrigatoriedade depende de `project_mode` em `.sdd/config.json` (definido pelo passo 1):

- `greenfield` → passos 1, 2 e 3 são obrigatórios; `codebase.md` não se aplica.
- `brownfield` → passo 1 **e** `codebase.md` são obrigatórios; 2 e 3 são **opcionais** e nunca invocados
  automaticamente (o desenvolvedor chama direto se quiser).

## Fluxo

### 1 — Presença e modo

```bash
for f in .sdd/STANDARDS.md .sdd/config.json .sdd/codebase.md .sdd/project.md .sdd/roadmap.md; do
  test -f "$f" && echo "present: $f" || echo "absent: $f"
done
# CLAUDE.md pode estar na raiz ou em .claude/
if [ -f CLAUDE.md ] || [ -f .claude/CLAUDE.md ]; then echo "present: CLAUDE.md"; else echo "absent: CLAUDE.md"; fi
test -f .sdd/config.json && grep -oE '"project_mode"[[:space:]]*:[[:space:]]*"[a-z]+"' .sdd/config.json || echo "project_mode: desconhecido"
```

Sem `config.json` o modo é `desconhecido` — o passo 1 ainda não rodou e é o próximo.

### 2 — Atualidade (stamps)

A linha 3 de cada artefato carimbado tem o formato
`<!-- sdd:inputs <caminho>@sha256:<12 hex> ... -->`. Recalcule e compare:

```bash
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-12; }
for doc in .sdd/STANDARDS.md .sdd/project.md .sdd/roadmap.md; do
  [ -f "$doc" ] || continue
  if [ "$doc" = .sdd/STANDARDS.md ] && grep -q '"standards_manual"[[:space:]]*:[[:space:]]*"manter"' .sdd/config.json 2>/dev/null; then echo "manual: $doc"; continue; fi
  line3=$(sed -n '3p' "$doc")
  case "$line3" in *sdd:inputs*) ;; *) echo "nostamp: $doc"; continue ;; esac
  for pair in $(printf '%s' "$line3" | grep -oE '[A-Za-z0-9._/-]+@sha256:[0-9a-f]{12}'); do
    src="${pair%%@*}"; want="${pair##*:}"
    if [ ! -f "$src" ]; then echo "stale: $doc (entrada removida: $src)"; continue; fi
    [ "$(h "$src")" = "$want" ] || echo "stale: $doc (mudou: $src)"
  done
done
```

Não gere saída para artefatos em dia. `sdd:inputs none` significa "sem entradas" e é válido.

O `codebase.md` usa outro carimbo (`git-head@<commit>`) e **não** entra na regra de
desatualizado — todo commit o deixaria "velho". Apenas informe a distância:

```bash
if [ -f .sdd/codebase.md ]; then
  c=$(sed -n '3p' .sdd/codebase.md | grep -oE 'git-head@[0-9a-f]{12}' | cut -d@ -f2)
  [ -n "$c" ] && echo "codebase: $(git rev-list --count "$c"..HEAD 2>/dev/null || echo '?') commits desde a geração"
fi
```

### 2b — Validação estrutural e versão do plugin

Presença e carimbo não detectam formato antigo: uma atualização do plugin pode ter passado a
exigir seção nova. Rode o validador e compare as versões:

```bash
SDD_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$SDD_ROOT" ] || SDD_ROOT=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1 | sed 's|/scripts/sdd-check.sh$||')
SDD_VER=$(grep -oE '"version"[^,]*' "$SDD_ROOT/.claude-plugin/plugin.json" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
for a in standards project roadmap; do
  case "$a" in
    standards) f=.sdd/STANDARDS.md ;; project) f=.sdd/project.md ;; roadmap) f=.sdd/roadmap.md ;;
  esac
  [ -f "$f" ] || continue
  bash "$SDD_ROOT/scripts/sdd-check.sh" "$a" 2>/dev/null | grep '^FALHA' | sed "s|^|$f: |"
  v=$(sed -n '2p' "$f" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tr -d v)
  [ -z "$v" ] && echo "$f: sem versão no carimbo (gerado por plugin anterior a 2.3.0)"
  [ -n "$v" ] && [ "$v" != "$SDD_VER" ] && echo "$f: gerado pela v$v, plugin é v$SDD_VER"
done
```

Artefato com `FALHA` ou com versão diferente da do plugin entra no relatório como
**desatualizado (formato)**, e isso é motivo para reexecutar o passo que o gera — mesmo com o
carimbo `sdd:inputs` em dia. Script não encontrado: diga isso no relatório e siga só com
presença e carimbo.

### 3 — Relatório

Uma única tabela:

| Artefato | Status |
|---|---|
| `.sdd/STANDARDS.md` / `config.json` / `CLAUDE.md` | `ok` / `ausente` / `desatualizado (<entrada>)` / `desatualizado (formato)` / `sem stamp` / `manual (mantido pelo desenvolvedor)` |
| `.sdd/codebase.md` | brownfield: `ok (N commits desde a geração)` / `ausente` — greenfield: `não se aplica` |
| `.sdd/project.md` | idem, ou `opcional (ausente)` em brownfield |
| `.sdd/roadmap.md` | idem, ou `opcional (ausente)` em brownfield |

Modo do projeto: `greenfield` / `brownfield` / `desconhecido`.
Depois da tabela, cite literalmente as linhas `stale:` do passo 2.

Se `.sdd/roadmap.md` existir, acrescente uma linha com a contagem de fases por status:
`grep -cE '^- \*\*Status\*\*: pendente'` (e o mesmo para `planejada` e `implementada`).

### 4 — Próximo passo

Escolha **exatamente uma** ação (vence a primeira regra que casar) e invoque via
SlashCommand. Diga em uma linha qual comando e por quê, e invoque.

1. Algum arquivo do passo 1 ausente, ou modo `brownfield` sem `codebase.md` → `/spec-driven-dev:init:context`.
2. Modo `greenfield` e `project.md` ausente → `/spec-driven-dev:init:project`.
3. Modo `greenfield` e `roadmap.md` ausente → `/spec-driven-dev:init:roadmap`.
4. Algum artefato **presente** desatualizado (por entrada **ou por formato**, §2b) → comando
   do primeiro desatualizado, na ordem da cadeia. Reexecuções são upsert: o subcomando só pergunta sobre o que mudou. Avise
   que regenerar pode desatualizar os artefatos seguintes — rode `/init` de novo depois.
5. Tudo ok → não invoque nada. Responda:
   - greenfield: `Inicialização completa. Próximo: /spec-driven-dev:plan com a primeira fase pendente do roadmap.`
     e cite a seção **Entrada para /plan** dessa fase.
   - brownfield: `Inicialização completa. Próximo: /spec-driven-dev:plan <feature>.`
     Se `project.md`/`roadmap.md` estiverem ausentes, uma linha dizendo que são opcionais.
   Se o `codebase.md` estiver com muitos commits de distância (referência: 20+), sugira
   reexecutar `/spec-driven-dev:init:context` — sem invocar.
   Se houver artefato `sem stamp`, uma linha: a atualidade dele só poderá ser verificada
   depois que o subcomando rodar uma vez.

Se a invocação falhar (ferramenta indisponível, comando não encontrado), recomende o comando
pelo nome — nunca deixe o desenvolvedor sem próximo passo.

## Regras

- **Não escreve nada** — nunca use Write/Edit; nenhum arquivo muda nesta execução.
- **Um salto por execução** — no máximo um subcomando por `/init`.
- **Desatualização é aviso, não bloqueio** — a decisão é sempre do desenvolvedor.
- **Roteador fino** — nenhum template ou entrevista aqui; tudo vive nos subcomandos.
- **Sem escrita no git** — nunca `add`, `commit`, `reset`.
