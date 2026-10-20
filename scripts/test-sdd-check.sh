#!/usr/bin/env bash
#
# test-sdd-check.sh — testa o sdd-check.sh com artefatos corretos e com defeitos plantados.
# Uso: scripts/test-sdd-check.sh [caminho/para/sdd-check.sh]

set -uo pipefail
CHK="${1:-$(cd "$(dirname "$0")" && pwd)/sdd-check.sh}"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FALHA %s\n        %s\n' "$1" "${2:-}"; }
expect_ok()   { out=$(bash "$CHK" "$@" 2>&1); [ $? -eq 0 ] && ok "limpo: $*" || bad "limpo: $*" "$(printf '%s' "$out" | grep -E '^FALHA' | head -3)"; }
expect_fail() { local msg="$1"; shift; out=$(bash "$CHK" "$@" 2>&1); rc=$?
  if [ $rc -eq 1 ] && printf '%s' "$out" | grep -q -- "$msg"; then ok "detecta: $msg"; else bad "detecta: $msg" "rc=$rc; $(printf '%s' "$out" | tail -3)"; fi; }
expect_warn() { local msg="$1"; shift; out=$(bash "$CHK" "$@" 2>&1)
  printf '%s' "$out" | grep -q "AVISO: .*$msg" && ok "avisa: $msg" || bad "avisa: $msg" "$(printf '%s' "$out" | tail -3)"; }
h() { (command -v sha256sum >/dev/null && sha256sum "$1" || shasum -a 256 "$1") | cut -c1-12; }

base() {
  rm -rf "$1"; mkdir -p "$1/.sdd/specs" "$1/.sdd/plans" "$1/app"; cd "$1" || exit 1
  echo '<?php' > app/Foo.php
  printf '{"project_mode":"greenfield","commands":{"test":"php artisan test","lint":["composer lint","npm run check"]}}\n' > .sdd/config.json
  printf '# CLAUDE.md\n@.sdd/STANDARDS.md\n' > CLAUDE.md
  cat > .sdd/STANDARDS.md <<'E'
# Padrões
<!-- sdd:generated-by init:context — upsert -->
<!-- sdd:inputs composer.json@sha256:aaaaaaaaaaaa -->
## Stack
| Componente | Versão | Origem |
|---|---|---|
| PHP | 8.3 | [observado: composer.json] |
## Arquitetura
- Controllers em app/Http. [observado: app/Foo.php]
## Convenções de código
- Pint. [observado: pint.json]
## Testes
- Pest. [observado: composer.json]
## Interface
- Layout padrão com sidebar. [observado: resources/js/layouts/app-layout.tsx]
## Segurança
- Fortify. [observado: composer.json]
## Git
- Conventional Commits. [decidido]
## Regras para agentes
- Nunca ler .env. [decidido]
## Questões em aberto
Nenhuma.
E
  cat > .sdd/project.md <<E
# P — Descrição do projeto
<!-- sdd:generated-by init:project -->
<!-- sdd:inputs .sdd/STANDARDS.md@sha256:$(h .sdd/STANDARDS.md) -->
## Visão geral
x
## Atores e permissões
x
## Conceitos-chave
x
## Fluxos principais
### F-01: Solicitar
x
### F-02: Aprovar
x
## Entidades principais
### E-01: Solicitação
x
## Escopo do MVP
x
## Integrações e restrições
x
## Requisitos não-funcionais
x
## Questões em aberto
Nenhuma.
E
  cat > .sdd/roadmap.md <<E
# P — Roadmap
<!-- sdd:generated-by init:roadmap -->
<!-- sdd:inputs .sdd/project.md@sha256:$(h .sdd/project.md) .sdd/STANDARDS.md@sha256:$(h .sdd/STANDARDS.md) -->

## Fase 1: Solicitar
- **Status**: planejada (sol)
- **Cobre**: F-01, E-01

## Fase 2: Aprovar
- **Status**: pendente
- **Cobre**: F-02

## Cobertura
| Item | Fases |
|---|---|
| F-01 | 1 |
| F-02 | 2 |
| E-01 | 1 |

## Depois do MVP
- Nada.
E
  cat > .sdd/specs/sol.md <<'E'
# Spec: Solicitar
<!-- sdd:generated-by plan -->
<!-- sdd:inputs .sdd/STANDARDS.md@sha256:aaaaaaaaaaaa -->
<!-- sdd:status aprovada 2026-09-21 -->
## Objetivo
x
## Escopo
x
## Requisitos funcionais
- **RF-01** — QUANDO a, O sistema DEVE b.
- **RF-02** — SE c, ENTÃO O sistema DEVE d.
## Requisitos não-funcionais
- **RNF-01** (segurança) — só o dono vê.
## Critérios de aceite
- **CA-01** (RF-01): x
- **CA-02** (RF-02): y
- **CA-03** (RNF-01): outro usuário recebe 403
## Impacto no código existente
- `app/Foo.php:1` — reaproveitado
## Pontos a esclarecer
Nenhum.
## Como se valida
Comando: `php artisan test`
E
  cat > .sdd/plans/sol.md <<E
# Plano: Solicitar
<!-- sdd:generated-by plan -->
<!-- sdd:inputs .sdd/specs/sol.md@sha256:$(h .sdd/specs/sol.md) -->

## Abordagem técnica
x

## Tarefas

- [ ] T-01 criar a base em \`app/Foo.php\`
  - Cobre: CA-01
  - Depende: nenhuma
  - Arquivos: \`app/Foo.php\`
  - Valida: \`php artisan test --filter=Foo\`

- [ ] T-02 exceção e acesso
  - Cobre: CA-02, CA-03
  - Depende: T-01
  - Arquivos: \`app/Foo.php\`
  - Valida: \`php artisan test --filter=Bar\`
  - Sensível: sim — autorização
  - Interface: /despesas — referência: /settings/profile
E
}
TMP=$(mktemp -d)

echo "== artefatos corretos"
base "$TMP/ok"
expect_ok standards; expect_ok project; expect_ok roadmap; expect_ok spec sol; expect_ok plan sol

echo "== standards"
base "$TMP/s1"; printf '{"commands":{"lint":"composer lint && npm run check"}}\n' > .sdd/config.json
expect_fail "encadeia comandos" standards
base "$TMP/s2"; sed -i '/^## Interface/,+1d' .sdd/STANDARDS.md
expect_fail "falta a seção '## Interface'" standards
base "$TMP/s3"; printf '# CLAUDE.md\n' > CLAUDE.md
expect_fail "sem '@.sdd/STANDARDS.md'" standards
base "$TMP/s4"; sed -i 's/^| PHP .*/&\n| Playwright | ainda não configurado | [decidido] |/' .sdd/STANDARDS.md
expect_warn "Stack parece listar" standards
base "$TMP/s5"; printf '{"project_mode":"brownfield","commands":{}}\n' > .sdd/config.json
expect_fail "arquivo ausente: .sdd/codebase.md" standards

base "$TMP/s6"
expect_warn "carimbo sem versão do plugin" standards
base "$TMP/s7"; sed -i 's/sdd:generated-by init:context/sdd:generated-by init:context v0.9.0/' .sdd/STANDARDS.md
expect_warn "gerado pela v0.9.0" standards

echo "== project e roadmap"
base "$TMP/p1"; sed -i 's/^### F-02: Aprovar/### F-01: Aprovar/' .sdd/project.md
expect_fail "ID duplicado" project
base "$TMP/r1"; sed -i 's/^## Fase 2:/## Fase 3:/' .sdd/roadmap.md
expect_fail "numeração de fases quebrada" roadmap
base "$TMP/r2"; sed -i 's/Cobre\*\*: F-02/Cobre**: F-02, F-09/' .sdd/roadmap.md
expect_fail "cita F-09" roadmap
base "$TMP/r3"; sed -i 's/- \*\*Status\*\*: pendente/- **Status**: talvez/' .sdd/roadmap.md
expect_fail "Status inválido" roadmap

echo "== spec"
base "$TMP/e1"; sed -i '/^- \*\*CA-02\*\*/d' .sdd/specs/sol.md
expect_fail "RF-02 sem critério" spec sol
base "$TMP/e2"; sed -i 's/(RNF-01): outro/(RNF-09): outro/' .sdd/specs/sol.md
expect_fail "cita RNF-09" spec sol
base "$TMP/e3"; sed -i 's/`app\/Foo.php:1`/`app\/Nao.php:1`/' .sdd/specs/sol.md
expect_fail "arquivo inexistente: app/Nao.php" spec sol
base "$TMP/e4"; sed -i 's/^Nenhum\.$/- **[CLARIFICAR]** formato? Opções: a | b./' .sdd/specs/sol.md
expect_fail "aprovada com 1 \[CLARIFICAR\]" spec sol

echo "== plano"
base "$TMP/l1"; sed -i 's/^  - Depende: T-01$/  - Depende: T-02/' .sdd/plans/sol.md
expect_fail "dependência para frente" plan sol
base "$TMP/l2"; sed -i 's/  - Cobre: CA-02, CA-03/  - Cobre: CA-02/' .sdd/plans/sol.md
expect_fail "CA-03 sem tarefa" plan sol
base "$TMP/l3"; sed -i 's/--filter=Bar`/--filter=Bar; echo x`/' .sdd/plans/sol.md
expect_fail "Valida encadeia" plan sol
base "$TMP/l4"; sed -i 's/^- \[ \] T-02 exceção/- [ ] T-02 [humano: revisar] exceção/' .sdd/plans/sol.md
expect_fail "motivo de \[humano\] inválido" plan sol
base "$TMP/l5"; sed -i 's/^- \[ \] T-02 exceção e acesso/- [ ] T-02 decidir com o financeiro o limite/' .sdd/plans/sol.md
expect_fail "decisão como tarefa" plan sol
base "$TMP/l6"; sed -i '/^  - Valida: `php artisan test --filter=Bar`/d' .sdd/plans/sol.md
expect_fail "sub-linha 'Valida:' em 1 de 2" plan sol
base "$TMP/l7"; printf '\n## Extra\nx\n' >> .sdd/plans/sol.md
expect_fail "seção depois de Tarefas" plan sol

echo "== revisão"
base "$TMP/v1"
sed -i 's/sdd:status aprovada 2026-09-21/sdd:status aprovada 2026-09-22 (R-01)/' .sdd/specs/sol.md
printf '\n## Histórico de revisões\n\n### R-01 — 2026-09-22 — ajuste\n- Obsoleto: CA-02 — "y" — substituído por CA-03\n' >> .sdd/specs/sol.md
expect_fail "obsoleto ainda vigente: CA-02" revise sol

cd /; rm -rf "$TMP"
echo; echo "Resultado: $PASS ok, $FAIL falha(s)"
[ "$FAIL" -eq 0 ]
