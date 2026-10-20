#!/usr/bin/env bash
#
# sdd-check.sh — validação determinística dos artefatos SDD.
#
# Os comandos do plugin chamam este script em vez de carregar as regras de
# validação no próprio texto: o que é estrutural fica com máquina, não com a
# atenção do modelo.
#
# Uso (a partir da raiz do projeto):
#   sdd-check.sh standards            .sdd/STANDARDS.md + config.json + CLAUDE.md (+ codebase.md)
#   sdd-check.sh project              .sdd/project.md
#   sdd-check.sh roadmap              .sdd/roadmap.md
#   sdd-check.sh spec    <slug>       .sdd/specs/<slug>.md
#   sdd-check.sh plan    <slug>       .sdd/plans/<slug>.md (contra a spec)
#   sdd-check.sh revise  <slug>       spec + plano + regras de revisão
#
# Saída: linhas "FALHA: ..." (bloqueiam) e "AVISO: ..." (revisar), e um resumo.
# Código de saída: 0 sem falhas · 1 com falhas · 2 uso incorreto.

set -uo pipefail

# Falhas e avisos vão para um arquivo, para contarem também quando emitidos dentro de pipes.
RES=$(mktemp "${TMPDIR:-/tmp}/sdd-check.XXXXXX"); trap 'rm -f "$RES"' EXIT
falha() { printf 'FALHA: %s\n' "$*"; printf 'FALHA\n' >> "$RES"; }
aviso() { printf 'AVISO: %s\n' "$*"; printf 'AVISO\n' >> "$RES"; }
ok()    { printf 'ok: %s\n' "$*"; }
need()  { [ -f "$1" ] || { falha "arquivo ausente: $1"; return 1; }; }
sections_required() { local f="$1"; shift; local x
  for x in "$@"; do grep -qx "## $x" "$f" || falha "$f: falta a seção '## $x'"; done; }
SDD_VER=$(grep -oE '"version"[^,]*' "$(dirname "$0")/../.claude-plugin/plugin.json" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
banner() { # $1 arquivo ; $2 gerador
  sed -n '2p' "$1" | grep -q "sdd:generated-by $2" || { falha "$1: linha 2 sem 'sdd:generated-by $2'"; return; }
  local v; v=$(sed -n '2p' "$1" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tr -d v)
  if [ -n "$SDD_VER" ]; then
    if [ -z "$v" ]; then aviso "$1: carimbo sem versão do plugin (gerado antes da 2.3.0) — regenere para conferir o formato"
    elif [ "$v" != "$SDD_VER" ]; then aviso "$1: gerado pela v$v, plugin é v$SDD_VER — regenere se o formato mudou"; fi
  fi
}
stamp()  { sed -n '3p' "$1" | grep -qE "$2" || falha "$1: linha 3 sem o carimbo esperado (sdd:inputs)"; }
cfg_has() { [ -f .sdd/config.json ] && grep -qE "$1" .sdd/config.json; }
# Validação de JSON: usa o primeiro disponível (jq, python, node). Nenhum → aviso, nunca falha.
PY=""; for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
JSON_OK=1
json_valido() { # $1 = arquivo ; 0 válido, 1 inválido, 2 sem validador
  if command -v jq >/dev/null 2>&1; then jq -e . "$1" >/dev/null 2>&1; return $?; fi
  if [ -n "$PY" ]; then "$PY" -m json.tool "$1" >/dev/null 2>&1; return $?; fi
  if command -v node >/dev/null 2>&1; then node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$1" >/dev/null 2>&1; return $?; fi
  return 2
}
comandos_encadeados() { # imprime "chave|comando" para cada valor com && ; || ou |
  local f=.sdd/config.json
  if command -v jq >/dev/null 2>&1; then
    jq -r '(.commands // {}) | to_entries[] | .key as $k
           | (.value | if type=="array" then .[] else . end)
           | select(type=="string") | select(test("&&|\\|\\||;|\\|")) | "\($k)|\(.)"' "$f" 2>/dev/null
    return 0
  fi
  if [ -n "$PY" ]; then
    "$PY" - "$f" <<'EOF'
import json,sys,re
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
for k,v in (d.get("commands") or {}).items():
    for c in (v if isinstance(v,list) else [v]):
        if isinstance(c,str) and re.search(r'&&|\|\||;|\|', c): print(f"{k}|{c}")
EOF
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      for (const [k,v] of Object.entries(d.commands||{})) for (const c of (Array.isArray(v)?v:[v]))
        if (typeof c==="string" && /&&|\|\||;|\|/.test(c)) console.log(k+"|"+c);' "$f" 2>/dev/null
    return 0
  fi
  return 0
}

# ------------------------------------------------------------------ standards
check_codebase() {
  local c=.sdd/codebase.md l
  need "$c" || return 0
  stamp "$c" 'sdd:inputs (git-head@[0-9a-f]{12}|none)'
  sections_required "$c" 'Visão geral' 'Módulos' 'Entidades' 'Interfaces' \
    'Regras de negócio implementadas' 'Integrações externas' 'Cobertura de testes existente' 'Pontos de atenção'
  grep -E '^- \*\*RN-[0-9]{2}\*\*' "$c" | grep -vE '`[^`]+:[0-9]+`' | while IFS= read -r l; do
    falha "$c: regra sem arquivo:linha: $l"; done
}

check_standards() {
  local s=.sdd/STANDARDS.md cfg=.sdd/config.json t sem l
  need "$cfg" || return 0
  json_valido "$cfg"; JSON_OK=$?
  case "$JSON_OK" in
    1) falha "$cfg: JSON inválido" ;;
    2) aviso "nenhum validador JSON disponível (jq, python ou node) — $cfg não foi validado" ;;
  esac
  if [ "$JSON_OK" -eq 0 ]; then
    comandos_encadeados | while IFS='|' read -r k c; do
      [ -n "$k" ] && falha "$cfg: commands.$k encadeia comandos (\"$c\") — use um script único ou uma lista [\"cmd1\", \"cmd2\"]"
    done
  fi
  if cfg_has '"standards_manual"[[:space:]]*:[[:space:]]*"manter"'; then
    ok "STANDARDS.md manual: verificação estrutural pulada"
  elif need "$s"; then
    banner "$s" 'init:context'
    stamp "$s" 'sdd:inputs'
    sections_required "$s" 'Stack' 'Arquitetura' 'Convenções de código' 'Testes' 'Interface' \
      'Segurança' 'Git' 'Regras para agentes' 'Questões em aberto'
    # junta as linhas de continuação: a origem costuma ficar na quebra, não na linha do "-"
    sem=$(sed -n '/^## Questões em aberto/q;p' "$s" \
      | awk '/^[[:space:]]*[-*] /{if(i)print i; i=$0; next} /^[[:space:]]*$/{if(i){print i; i=""}; next} i{i=i" "$0; next} {if(i){print i; i=""}} END{if(i)print i}' \
      | grep -vcE '\[(observado|decidido|esqueleto)' || true)
    [ "$sem" -eq 0 ] || aviso "$s: $sem item(ns) de lista sem origem [observado|decidido|esqueleto]"
    sed -n '/^## Stack/,/^## Arquitetura/p' "$s" | grep -qiE 'não configurad|ainda não|pretendid' \
      && aviso "$s: a tabela Stack parece listar ferramenta que ainda não existe no projeto"
  fi
  t=CLAUDE.md; [ -f "$t" ] || t=.claude/CLAUDE.md
  if grep -q '@.sdd/STANDARDS.md' "$t" 2>/dev/null; then ok "import em $t"
  elif cfg_has '"claude_md_import"[[:space:]]*:[[:space:]]*"recusado"'; then ok "import recusado (registrado)"
  else falha "$t sem '@.sdd/STANDARDS.md' e sem recusa registrada"; fi
  if cfg_has '"project_mode"[[:space:]]*:[[:space:]]*"brownfield"'; then check_codebase; fi
}

# -------------------------------------------------------------------- project
check_project() {
  local f=.sdd/project.md v d
  need "$f" || return 0
  banner "$f" 'init:project'
  stamp "$f" 'sdd:inputs \.sdd/STANDARDS\.md@sha256:[0-9a-f]{12}'
  sections_required "$f" 'Visão geral' 'Atores e permissões' 'Conceitos-chave' 'Fluxos principais' \
    'Entidades principais' 'Escopo do MVP' 'Integrações e restrições' 'Requisitos não-funcionais' 'Questões em aberto'
  [ "$(grep -cE '^### F-[0-9]{2}: ' "$f" || true)" -gt 0 ] || falha "$f: nenhum fluxo F-NN"
  grep -oE '^### (F|E)-[0-9]{2}' "$f" | sort | uniq -d | while read -r d; do falha "$f: ID duplicado $d"; done
  v=$(grep -ciE '\b(rápido|adequad[oa]|etc\.|quando possível)' "$f" || true)
  [ "$v" -eq 0 ] || aviso "$f: $v linha(s) com termo vago (rápido, adequado, etc., quando possível)"
}

# -------------------------------------------------------------------- roadmap
check_roadmap() {
  local f=.sdd/roadmap.md p=.sdd/project.md n=0 k id l
  need "$f" || return 0
  banner "$f" 'init:roadmap'
  stamp "$f" 'project\.md@sha256:[0-9a-f]{12}.*STANDARDS\.md@sha256:[0-9a-f]{12}'
  for k in $(grep -oE '^## Fase [0-9]+:' "$f" | grep -oE '[0-9]+'); do
    n=$((n+1)); [ "$k" -eq "$n" ] || falha "$f: numeração de fases quebrada (esperado $n, achou $k)"
  done
  [ "$n" -gt 0 ] || falha "$f: nenhuma fase"
  grep -E '^## ' "$f" | grep -vE '^## (Fase [0-9]+: .+|Cobertura|Depois do MVP)$' | while IFS= read -r l; do
    falha "$f: seção não permitida: $l"; done
  [ "$(grep -cE '^- \*\*Status\*\*: (pendente|planejada \(.+\)|implementada \(.+\))$' "$f" || true)" -eq "$n" ] \
    || falha "$f: há fase com Status inválido ou ausente"
  if [ -f "$p" ]; then
    for id in $(grep -oE '\b[FE]-[0-9]{2}\b' "$f" | sort -u); do
      grep -qE "^### $id:" "$p" || falha "$f: cita $id, que não existe no project.md"
    done
    for id in $(grep -oE '^### [FE]-[0-9]{2}' "$p" | cut -d' ' -f2); do
      grep -qE "^\| $id \|" "$f" || aviso "$f: $id sem cobertura (aceitável só se estiver fora do MVP)"
    done
  fi
}

# ----------------------------------------------------------------------- spec
check_spec() {
  local s=".sdd/specs/$1.md" rf m f d
  need "$s" || return 0
  banner "$s" 'plan'
  stamp "$s" 'sdd:inputs'
  sed -n '4p' "$s" | grep -qE 'sdd:status (rascunho|aprovada [0-9]{4}-[0-9]{2}-[0-9]{2})' || falha "$s: linha 4 sem status válido"
  sections_required "$s" 'Objetivo' 'Escopo' 'Requisitos funcionais' 'Critérios de aceite' \
    'Impacto no código existente' 'Pontos a esclarecer' 'Como se valida'
  grep -oE '^- \*\*(RF|RNF|CA)-[0-9]{2}\*\*' "$s" | sort | uniq -d | while read -r d; do falha "$s: ID duplicado $d"; done
  for rf in $(grep -oE '^- \*\*RF-[0-9]{2}\*\*' "$s" | grep -oE 'RF-[0-9]{2}'); do
    grep -qE "^- \*\*CA-[0-9]{2}\*\* \([^)]*$rf" "$s" || falha "$s: $rf sem critério de aceite"
  done
  for rf in $(grep -oE '^- \*\*CA-[0-9]{2}\*\* \([^)]*\)' "$s" | grep -oE '(RF|RNF)-[0-9]{2}' | sort -u); do
    grep -qE "^- \*\*$rf\*\*" "$s" || falha "$s: critério cita $rf, que não existe"
  done
  m=$(grep -c '\[CLARIFICAR\]' "$s" || true)
  if [ "$m" -gt 0 ]; then
    if sed -n '4p' "$s" | grep -q 'aprovada'; then falha "$s: aprovada com $m [CLARIFICAR] em aberto"
    else aviso "$s: $m [CLARIFICAR] em aberto (bloqueiam a aprovação)"; fi
  fi
  # formato do impacto: `caminho/arquivo.ext:linha` ou `caminho:inicio-fim`
  grep -oE '`[^` :]+:[0-9]+(-[0-9]+)?`' "$s" | tr -d '`' | cut -d: -f1 | sort -u | while read -r f; do
    [ -f "$f" ] || falha "$s: impacto cita arquivo inexistente: $f"
  done
}

# ----------------------------------------------------------------------- plan
check_plan() {
  local p=".sdd/plans/$1.md" s=".sdd/specs/$1.md" n=0 k c f t l cur d
  need "$p" || return 0; need "$s" || return 0
  stamp "$p" "sdd:inputs \.sdd/specs/.*@sha256:[0-9a-f]{12}"
  for k in $(grep -oE '^- \[.\] T-[0-9]{2}' "$p" | grep -oE '[0-9]{2}$'); do
    n=$((n+1)); [ "$((10#$k))" -eq "$n" ] || falha "$p: numeração quebrada (esperado T-$(printf '%02d' "$n"), achou T-$k)"
  done
  [ "$n" -gt 0 ] || falha "$p: nenhuma tarefa"
  grep -q '^## Revisões' "$p" || [ "$n" -le 12 ] || falha "$p: $n tarefas — acima de 12, divida a fatia"
  for f in Cobre Depende Arquivos Valida; do
    c=$(grep -cE "^  - $f: " "$p" || true); [ "$c" -eq "$n" ] || falha "$p: sub-linha '$f:' em $c de $n tarefas"
  done
  awk '/^- \[.\] T-/{t=$0} /^  - Depende: /{ if ($0 !~ /nenhuma/) print t " || " $0 }' "$p" | while IFS= read -r l; do
    cur=$(printf '%s' "$l" | grep -oE 'T-[0-9]{2}' | head -1)
    for d in $(printf '%s' "${l#*||}" | grep -oE 'T-[0-9]{2}'); do
      [ "$d" \< "$cur" ] || falha "$p: $cur depende de $d (dependência para frente)"
    done
  done
  for c in $(grep -oE '^- \*\*CA-[0-9]{2}\*\*' "$s" | grep -oE 'CA-[0-9]{2}'); do
    grep -qE "^  - Cobre: .*\b$c\b" "$p" || falha "$p: $c sem tarefa"
  done
  awk '/^- \[ \] T-/{pend=1} /^- \[x\] T-/{pend=0} pend && /^  - Cobre: /' "$p" | grep -oE 'CA-[0-9]{2}' | sort -u | while read -r c; do
    grep -q "\*\*$c\*\*" "$s" || falha "$p: tarefa pendente cita $c, que não existe na spec"
  done
  t=$(grep -n '^## Tarefas' "$p" | cut -d: -f1)
  if [ -z "$t" ]; then falha "$p: falta '## Tarefas'"
  else tail -n +"$((t+1))" "$p" | grep -E '^## ' | while IFS= read -r l; do falha "$p: seção depois de Tarefas: $l"; done; fi
  grep -oE '^- \[ \] T-[0-9]{2} \[humano[^]]*\]' "$p" | grep -vE '\[humano: (verificação|acesso|aprovação)\]' | while IFS= read -r l; do
    falha "$p: motivo de [humano] inválido: $l"; done
  grep -E '^- \[ \] T-[0-9]{2} .*\b(decidir|definir com|escolher entre|avaliar qual|confirmar com)\b' "$p" | while IFS= read -r l; do
    falha "$p: decisão como tarefa (volte à spec como [CLARIFICAR]): $l"; done
  grep -E '^  - Valida: `[^`]*(&&|\|\||;|\||>)' "$p" | while IFS= read -r l; do
    falha "$p: Valida encadeia ou redireciona comandos: $l"; done
  if cfg_has '"test"[[:space:]]*:[[:space:]]*null'; then
    if grep -E '^- \[ \] T-[0-9]{2} ' "$p" | grep -qv '\[humano'; then
      grep -qE '^- \[.\] T-01 .*(teste|test)' "$p" || falha "$p: projeto sem suíte de testes e nenhuma tarefa de base mínima"
    fi
  fi
}

# --------------------------------------------------------------------- revise
check_revise() {
  local s=".sdd/specs/$1.md" p=".sdd/plans/$1.md" id r t
  check_spec "$1"; check_plan "$1"
  [ -f "$s" ] && [ -f "$p" ] || return 0
  obs() { sed -n '/^## Histórico de revisões/,$p' "$s" | grep -E '^- Obsoleto: ' | sed -E 's/^- Obsoleto: ((RF|RNF|CA)-[0-9]{2}).*/\1/' | sort -u; }
  for id in $(obs); do grep -qE "^- \*\*$id\*\*" "$s" && falha "$s: obsoleto ainda vigente: $id"; done
  for id in $(obs | grep '^CA-' || true); do
    awk '/^- \[ \] T-/{pend=1} /^- \[x\] T-/{pend=0} pend && /^  - Cobre:/' "$p" | grep -q "$id" && falha "$p: tarefa pendente cita obsoleto $id"
  done
  if grep -q '^## Histórico de revisões' "$s"; then
    [ "$(grep -E '^## ' "$s" | tail -1)" = "## Histórico de revisões" ] || falha "$s: 'Histórico de revisões' não é a última seção"
    sed -n '4p' "$s" | grep -qE 'aprovada [0-9]{4}-[0-9]{2}-[0-9]{2} \(R-[0-9]{2}\)' || falha "$s: status sem o número da revisão (R-NN)"
  fi
  r=$(grep -n '^## Revisões' "$p" | cut -d: -f1); t=$(grep -n '^## Tarefas' "$p" | cut -d: -f1)
  if [ -n "$r" ] && [ -n "$t" ] && [ "$r" -gt "$t" ]; then falha "$p: 'Revisões' depois de 'Tarefas'"; fi
  for id in $(grep -oE '^  - Revisa: T-[0-9]{2}' "$p" | grep -oE 'T-[0-9]{2}'); do
    grep -qE "^- \[x\] $id " "$p" || falha "$p: Revisa aponta para tarefa não concluída: $id"
  done
}

# ----------------------------------------------------------------------- main
cmd="${1:-}"; slug="${2:-}"
case "$cmd" in
  standards) check_standards ;;
  project)   check_project ;;
  roadmap)   check_roadmap ;;
  spec|plan|revise)
    [ -n "$slug" ] || { echo "uso: $0 $cmd <slug>"; exit 2; }
    printf '%s' "$slug" | grep -qE '^[a-z0-9][a-z0-9-]{0,59}$' || { echo "slug inválido: $slug"; exit 2; }
    "check_$cmd" "$slug" ;;
  *) sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
FAILS=$(grep -c '^FALHA' "$RES" || true); WARNS=$(grep -c '^AVISO' "$RES" || true)
printf 'resultado: %d falha(s), %d aviso(s)\n' "$FAILS" "$WARNS"
[ "$FAILS" -eq 0 ]
