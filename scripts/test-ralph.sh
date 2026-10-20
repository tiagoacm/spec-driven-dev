#!/usr/bin/env bash
#
# test-ralph.sh — testa o ralph.sh sem gastar um token.
#
# Cria repositórios temporários, um plano SDD de mentira e um binário `claude`
# falso, e verifica os caminhos críticos: sucesso, gate vermelho, revisão
# reprovando ou ilegível, pausa humana, preflight, retomada, adulteração dos
# arquivos protegidos, segredo no commit e permissões passadas ao agente.
#
# Uso: scripts/test-ralph.sh [caminho/para/ralph.sh]

set -uo pipefail
RALPH="${1:-$(cd "$(dirname "$0")" && pwd)/ralph.sh}"
[ -f "$RALPH" ] || { echo "ralph.sh não encontrado: $RALPH"; exit 1; }

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "esperado '$3', obtido '$2'"; }
has()  { printf '%s' "$2" | grep -q -- "$3" && ok "$1" || bad "$1" "não encontrado: $3"; }
done_count() { grep -c '^- \[x\] T-' .sdd/plans/f.md || true; }
calls() { grep -c '^=== CALL' calls.txt || true; }

make_repo() {
  rm -rf "$1"; mkdir -p "$1/.sdd/specs" "$1/.sdd/plans" "$1/bin"
  cd "$1" || exit 1
  git init -q; git config user.email t@t; git config user.name t
  cat > .sdd/specs/f.md <<'E'
# Spec: F
<!-- sdd:generated-by plan -->
<!-- sdd:inputs .sdd/STANDARDS.md@sha256:aaaaaaaaaaaa -->
<!-- sdd:status aprovada 2026-01-01 -->
## Critérios de aceite
- **CA-01** (RF-01): faz algo
E
  printf '# Padrões\n' > .sdd/STANDARDS.md
  printf '{"commands":{"test":"sh ./faketest.sh","install":"npm install"}}\n' > .sdd/config.json
  printf '#!/bin/sh\nexit ${FAKE_TEST_EXIT:-0}\n' > faketest.sh; chmod +x faketest.sh
  cat > bin/claude <<'E'
#!/usr/bin/env bash
# claude falso. Variáveis: FAKE_IMPL, FAKE_REVIEW, FAKE_TAMPER (plan|config), FAKE_SECRET
prompt=""; take=0; flags=""
for a in "$@"; do
  if [ "$take" = 1 ]; then prompt="$a"; take=0; continue; fi
  if [ "$a" = "-p" ]; then take=1; else flags="$flags $a"; fi
done
r() { printf '{"is_error":false,"result":%s}\n' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS="\\n"}{print}' | sed 's/\\n$//; s/^/"/; s/$/"/')"; }
if printf '%s' "$prompt" | grep -q 'sdd-ui-agent'; then
  echo "UI$flags" >> "$FAKE_ARGS"
  [ -z "${FAKE_UI_LOG:-}" ] || printf '%s\n' "$prompt" >> "$FAKE_UI_LOG"
  r "${FAKE_UI-INTERFACE: APROVADA}"
elif printf '%s' "$prompt" | grep -q 'sdd-review-agent'; then
  echo "REVIEW$flags" >> "$FAKE_ARGS"
  [ -z "${FAKE_REVIEW_LOG:-}" ] || printf '%s\n' "$prompt" >> "$FAKE_REVIEW_LOG"
  if printf '%s' "$prompt" | grep -q 'modo feature'; then r "${FAKE_FINAL_REVIEW-VEREDITO: APROVADO}"
  else r "${FAKE_REVIEW-APROVADO}"; fi
else
  echo "IMPL$flags" >> "$FAKE_ARGS"
  { echo "=== CALL"; echo "$prompt"; } >> "$FAKE_CALLS"
  printf 'implementado %s\n' "$RANDOM$RANDOM" >> impl.txt
  case "${FAKE_TAMPER:-}" in
    plan)   sed -i.bak 's/sh \.\/faketest\.sh/true/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak ;;
    config) printf '{"commands":{"test":"true"}}\n' > .sdd/config.json ;;
  esac
  [ -z "${FAKE_SECRET:-}" ] || printf 'aws = "AKIAABCDEFGHIJKLMNOP"\n' > chaves.txt
  if [ -n "${FAKE_FRONT:-}" ]; then mkdir -p resources/js; printf 'export {}\n' > "resources/js/p$RANDOM$RANDOM.tsx"; fi
  [ -z "${FAKE_WRITE_CONFIG:-}" ] || printf '%s\n' "$FAKE_WRITE_CONFIG" > .sdd/config.json
  r "${FAKE_IMPL:-implementei a tarefa}"
fi
E
  chmod +x bin/claude
  export PATH="$PWD/bin:$PATH"
  export FAKE_CALLS="$PWD/calls.txt" FAKE_ARGS="$PWD/args.txt"; : > "$FAKE_CALLS"; : > "$FAKE_ARGS"
  printf 'calls.txt\nargs.txt\nreview_prompts.txt\n' >> .git/info/exclude
}

plan_2_tasks() {
  h=$( (command -v sha256sum >/dev/null && sha256sum .sdd/specs/f.md || shasum -a 256 .sdd/specs/f.md) | cut -c1-12)
  cat > .sdd/plans/f.md <<E
# Plano: F
<!-- sdd:generated-by plan -->
<!-- sdd:inputs .sdd/specs/f.md@sha256:$h -->

## Tarefas

- [ ] T-01 primeira tarefa
  - Cobre: CA-01
  - Depende: nenhuma
  - Arquivos: \`a.txt\`
  - Valida: \`sh ./faketest.sh\`

- [ ] T-02 segunda tarefa
  - Cobre: CA-01
  - Depende: T-01
  - Arquivos: \`b.txt\`
  - Valida: \`sh ./faketest.sh\`
E
  git add -A >/dev/null; git commit -qm base
}

TMP=$(mktemp -d)

echo "== 1. caminho feliz"
make_repo "$TMP/t1"; plan_2_tasks
out=$(bash "$RALPH" f -y 2>&1); rc=$?
check "exit 0" "$rc" "0"
check "duas tarefas marcadas" "$(done_count)" "2"
check "dois commits de tarefa" "$(git log --oneline | grep -c 'ralph(f)')" "2"
check "log fora do git" "$(git log --stat | grep -c '.sdd/logs' || true)" "0"
check "lock removido" "$([ -e .sdd/.ralph-f.lock ] && echo sim || echo nao)" "nao"
has "lista os comandos de gate" "$out" "Comandos que este script vai executar"
has "rodou suíte final" "$out" "suíte completa"

echo "== 2. permissões passadas ao agente"
check "implementação sem skip-permissions" "$(grep '^IMPL' args.txt | grep -c 'dangerously' || true)" "0"
has "implementação com lista restrita" "$(grep '^IMPL' args.txt | head -1)" "--allowedTools"
has "lista inclui o comando de teste" "$(grep '^IMPL' args.txt | head -1)" "Bash(sh ./faketest.sh:\*)"
check "lista não inclui install" "$(grep '^IMPL' args.txt | grep -c 'npm install' || true)" "0"
check "revisão nunca com skip-permissions" "$(grep '^REVIEW' args.txt | grep -c 'dangerously' || true)" "0"
has "revisão só com leitura" "$(grep '^REVIEW' args.txt | head -1)" "Read,Grep,Glob,Task"
make_repo "$TMP/t2b"; plan_2_tasks
bash "$RALPH" f -y --permissoes-totais --max-iter 1 >/dev/null 2>&1
has "--permissoes-totais usa skip" "$(grep '^IMPL' args.txt | head -1)" "dangerously-skip-permissions"
has "--permissoes-totais bloqueia push" "$(grep '^IMPL' args.txt | head -1)" "git push"

echo "== 1b. fecho: roadmap, revisão final e E2E"
make_repo "$TMP/t1b"; plan_2_tasks
printf '# R\n\n## Fase 1: F\n- **Status**: planejada (f)\n' > .sdd/roadmap.md
git add -A >/dev/null; git commit -qm r
bash "$RALPH" f -y >/dev/null 2>&1; check "exit 0" "$?" "0"
has "roadmap marcado como implementada" "$(cat .sdd/roadmap.md)" "implementada (f)"
check "roadmap commitado" "$(git status --porcelain .sdd/roadmap.md | wc -l | tr -d ' ')" "0"
check "revisão final chamada" "$(grep -c '^REVIEW' args.txt)" "3"
make_repo "$TMP/t1c"; plan_2_tasks
printf '# R\n\n## Fase 1: F\n- **Status**: planejada (f)\n' > .sdd/roadmap.md
git add -A >/dev/null; git commit -qm r
out=$(FAKE_FINAL_REVIEW='VEREDITO: REPROVADO' bash "$RALPH" f -y 2>&1); rc=$?
check "revisão final reprovada: exit 5" "$rc" "5"
has "roadmap continua planejada" "$(cat .sdd/roadmap.md)" "planejada (f)"
make_repo "$TMP/t1d"; plan_2_tasks
FAKE_FINAL_REVIEW='ok, tudo certo' bash "$RALPH" f -y >/dev/null 2>&1
check "revisão final sem veredito: exit 5" "$?" "5"
make_repo "$TMP/t1e"; plan_2_tasks
printf '{"commands":{"test":"sh ./faketest.sh","e2e":"sh ./fakee2e.sh"}}\n' > .sdd/config.json
printf '#!/bin/sh\nexit ${FAKE_E2E_EXIT:-0}\n' > fakee2e.sh; chmod +x fakee2e.sh
sed -i.bak 's/^  - Valida: `sh .\/faketest.sh`$/  - Valida: `sh .\/fakee2e.sh` — roda no fecho da feature/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm e
out=$(FAKE_E2E_EXIT=1 bash "$RALPH" f -y 2>&1); rc=$?
check "E2E vermelho no fecho: exit 5" "$rc" "5"
has "rodou o E2E" "$out" "Rodando os testes E2E"

PORT=$((20000 + RANDOM % 20000))
ui_config() { # $1 = com|sem ambiente de verificação
  local env='"verify_url":"http://127.0.0.1:'"$PORT"'","verify_users":{"colaborador":"c@verify.test"}'
  local cmds='"verify_prepare":"sh ./fakeprep.sh","verify_serve":"python3 -m http.server '"$PORT"' --bind 127.0.0.1"'
  [ "$1" = sem ] && { env='"verify_url":null'; cmds='"verify_prepare":null'; }
  printf '{"paths":{"frontend":["resources/js/**"]},"preferences":{"ui_verify":"aceito"},"environment":{%s},"commands":{"test":"sh ./faketest.sh",%s}}\n' "$env" "$cmds" > .sdd/config.json
  printf '#!/bin/sh\necho preparado > .verify_ok\n' > fakeprep.sh; chmod +x fakeprep.sh
  printf '.verify_ok\n' >> .git/info/exclude
  git add -A >/dev/null; git commit -qm ui
}
port_free() { ! curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORT"; }

echo "== 1f. verificação de interface"
make_repo "$TMP/u1"; plan_2_tasks; ui_config com
out=$(FAKE_FRONT=1 bash "$RALPH" f -y 2>&1); rc=$?
check "frontend tocado, interface aprovada: exit 0" "$rc" "0"
check "agente de interface chamado (2 tarefas + fecho)" "$(grep -c '^UI' args.txt)" "3"
has "sessão de interface com o MCP" "$(grep '^UI' args.txt | head -1)" "mcp__playwright"
check "sessão de interface sem skip-permissions" "$(grep '^UI' args.txt | grep -c dangerously || true)" "0"
check "verify_prepare rodou" "$([ -f .verify_ok ] && echo sim || echo nao)" "sim"
port_free && ok "servidor de verificação derrubado" || bad "servidor de verificação derrubado"
make_repo "$TMP/u2"; plan_2_tasks; ui_config com
FAKE_FRONT=1 FAKE_UI='INTERFACE: REPROVADA: menu sem link para a tela' bash "$RALPH" f -y >/dev/null 2>&1; rc=$?
check "interface reprovada: exit 5" "$rc" "5"
check "nenhuma marcada" "$(done_count)" "0"
grep -q 'menu sem link' calls.txt && ok "motivo volta para o ciclo de correção" || bad "motivo volta para o ciclo de correção"
port_free && ok "servidor derrubado após reprovação" || bad "servidor derrubado após reprovação"
make_repo "$TMP/u3"; plan_2_tasks; ui_config com
FAKE_FRONT=1 FAKE_UI='olhei e parece ok' bash "$RALPH" f -y >/dev/null 2>&1; check "veredito ilegível: exit 5" "$?" "5"
make_repo "$TMP/u4"; plan_2_tasks; ui_config sem
out=$(FAKE_FRONT=1 bash "$RALPH" f -y 2>&1); rc=$?
check "ambiente não configurado: exit 5" "$rc" "5"
has "diz o que falta" "$out" "verificação indisponível"
make_repo "$TMP/u4b"; plan_2_tasks; ui_config sem
out=$(FAKE_FRONT=1 bash "$RALPH" f -y --sem-ui 2>&1); check "--sem-ui segue: exit 0" "$?" "0"
has "--sem-ui avisa que a interface não foi verificada" "$out" "NÃO foi verificada"
make_repo "$TMP/u5"; plan_2_tasks; ui_config com
bash "$RALPH" f -y >/dev/null 2>&1; check "sem frontend tocado: exit 0" "$?" "0"
check "agente de interface não chamado" "$(grep -c '^UI' args.txt || true)" "0"
make_repo "$TMP/u6"; plan_2_tasks; ui_config sem
sed -i.bak 's/^  - Valida: `sh .\/faketest.sh`$/&\
  - Altera config: sim/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm cfg
FAKE_WRITE_CONFIG='{"commands":{"test":"sh ./faketest.sh"},"novo":"gravado pela tarefa"}' bash "$RALPH" f -y --max-iter 1 >/dev/null 2>&1
has "Altera config: sim preserva a gravação" "$(cat .sdd/config.json)" "gravado pela tarefa"

echo "== 1g. comandos em lista"
make_repo "$TMP/u7"; plan_2_tasks
printf '#!/bin/sh\necho segunda >> .lista\nexit ${FAKE_SEG:-0}\n' > seg.sh; chmod +x seg.sh; printf '.lista\n' >> .git/info/exclude
printf '{"commands":{"test":["sh ./faketest.sh","sh ./seg.sh"]}}\n' > .sdd/config.json
sed -i.bak 's/^  - Valida: `sh .\/faketest.sh`$/  - Valida: nenhum comando próprio/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm l
bash "$RALPH" f -y >/dev/null 2>&1; check "lista de comandos: exit 0" "$?" "0"
has "os dois comandos da lista rodaram" "$(cat .lista 2>/dev/null)" "segunda"
has "cada item vira permissão" "$(grep '^IMPL' args.txt | head -1)" "Bash(sh ./seg.sh:\*)"
make_repo "$TMP/u8"; plan_2_tasks
printf '#!/bin/sh\nexit 1\n' > seg.sh; chmod +x seg.sh
printf '{"commands":{"test":["sh ./faketest.sh","sh ./seg.sh"]}}\n' > .sdd/config.json
sed -i.bak 's/^  - Valida: `sh .\/faketest.sh`$/  - Valida: nenhum comando próprio/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm l
bash "$RALPH" f -y >/dev/null 2>&1; check "item da lista falhando reprova: exit 5" "$?" "5"

echo "== 1h. pendências não bloqueantes"
make_repo "$TMP/u9"; plan_2_tasks
FAKE_FINAL_REVIEW='VEREDITO: APROVADO COM RESSALVAS

Bloqueantes
- nenhum

Ressalvas
- texto genérico nas notificações — notifications-menu.tsx
- helpers de teste duplicados — tests/Feature' bash "$RALPH" f -y >/dev/null 2>&1
check "exit 0" "$?" "0"
check "pendências registradas" "$(grep -c '^- \[ \]' .sdd/pendencias.md 2>/dev/null || echo 0)" "2"
has "pendência traz data e slug" "$(cat .sdd/pendencias.md)" "· f · texto genérico"
check "pendências commitadas" "$(git status --porcelain .sdd/pendencias.md | wc -l | tr -d ' ')" "0"

echo "== 2b. gate de segurança no fecho"
make_repo "$TMP/t2s"; plan_2_tasks
printf '{"commands":{"test":"sh ./faketest.sh","security":"sh ./fakesec.sh"}}\n' > .sdd/config.json
printf '#!/bin/sh\necho "1 vulnerabilidade alta"\nexit ${FAKE_SEC_EXIT:-0}\n' > fakesec.sh; chmod +x fakesec.sh
git add -A >/dev/null; git commit -qm s
out=$(FAKE_SEC_EXIT=1 bash "$RALPH" f -y 2>&1); rc=$?
check "segurança vermelha: exit 5" "$rc" "5"
has "avisa a falha de segurança" "$out" "GATE DE SEGURANÇA FALHOU"
has "comando de segurança listado no preflight" "$out" "sh ./fakesec.sh"
has "comando de segurança na lista de permissões" "$(grep '^IMPL' args.txt | head -1)" "Bash(sh ./fakesec.sh:\*)"
check "tarefas concluídas mesmo assim" "$(done_count)" "2"

echo "== 2c. tarefa sensível avisa o revisor"
make_repo "$TMP/t2c"; plan_2_tasks
sed -i.bak 's/^  - Valida: `sh .\/faketest.sh`$/&\
  - Sensível: sim — autorização por área/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm sens
FAKE_REVIEW_LOG="$PWD/review_prompts.txt" bash "$RALPH" f -y --max-iter 1 >/dev/null 2>&1
has "prompt da revisão cita Sensível" "$(cat .sdd/logs/f.md; cat review_prompts.txt 2>/dev/null)" "autorização por área"

echo "== 3. gate vermelho: 3 ciclos e aborta"
make_repo "$TMP/t3"; plan_2_tasks
FAKE_TEST_EXIT=1 bash "$RALPH" f -y >/dev/null 2>&1; rc=$?
check "exit 5" "$rc" "5"
check "nenhuma marcada" "$(done_count)" "0"
check "três ciclos" "$(calls)" "3"
grep -q 'INICIO_SAIDA' calls.txt && ok "saída do teste cercada como dado" || bad "saída do teste cercada como dado"

echo "== 4. agente adultera o plano para burlar o gate"
make_repo "$TMP/t4"; plan_2_tasks
out=$(FAKE_TAMPER=plan FAKE_TEST_EXIT=1 bash "$RALPH" f -y 2>&1); rc=$?
check "exit 5" "$rc" "5"
check "plano restaurado" "$(grep -c 'Valida: `true`' .sdd/plans/f.md || true)" "0"
check "nenhuma marcada" "$(done_count)" "0"
has "acusa violação" "$out" "VIOLAÇÃO"

echo "== 5. agente adultera o config.json"
make_repo "$TMP/t5"; plan_2_tasks
FAKE_TAMPER=config bash "$RALPH" f -y >/dev/null 2>&1; rc=$?
check "exit 5" "$rc" "5"
has "config restaurado" "$(cat .sdd/config.json)" "faketest"

echo "== 6. revisão reprova"
make_repo "$TMP/t6"; plan_2_tasks
FAKE_REVIEW='REPROVADO: CA-01 sem evidência' bash "$RALPH" f -y >/dev/null 2>&1; rc=$?
check "exit 5" "$rc" "5"; check "nenhuma marcada" "$(done_count)" "0"

echo "== 7. revisão ilegível NÃO aprova (fail-closed)"
make_repo "$TMP/t7"; plan_2_tasks
FAKE_REVIEW='não consegui chamar o agente' bash "$RALPH" f -y >/dev/null 2>&1; rc=$?
check "exit 5" "$rc" "5"; check "nenhuma marcada" "$(done_count)" "0"
make_repo "$TMP/t7b"; plan_2_tasks
FAKE_REVIEW='' bash "$RALPH" f -y >/dev/null 2>&1; rc=$?
check "revisão vazia: exit 5" "$rc" "5"
make_repo "$TMP/t7c"; plan_2_tasks
bash "$RALPH" f -y --no-review >/dev/null 2>&1; rc=$?
check "--no-review com gate verde conclui" "$rc" "0"

echo "== 8. segredo bloqueia o commit"
make_repo "$TMP/t8"; plan_2_tasks
out=$(FAKE_SECRET=1 bash "$RALPH" f -y 2>&1); rc=$?
check "exit 6" "$rc" "6"
check "nenhuma marcada" "$(done_count)" "0"
check "nenhum commit" "$(git log --oneline | grep -c 'ralph(f)' || true)" "0"
has "aponta o arquivo" "$out" "chaves.txt"
check "não imprime o segredo" "$(printf '%s' "$out" | grep -c 'AKIAABCDEFGHIJKLMNOP' || true)" "0"
check "nada ficou em stage" "$(git diff --cached --name-only | wc -l | tr -d ' ')" "0"

echo "== 9. pausas humanas"
make_repo "$TMP/t9"; plan_2_tasks
FAKE_IMPL='SDD_NEEDS_HUMAN a spec não diz o formato' bash "$RALPH" f -y >/dev/null 2>&1; check "SDD_NEEDS_HUMAN: exit 2" "$?" "2"
make_repo "$TMP/t9b"; plan_2_tasks
sed -i.bak 's/^- \[ \] T-01 primeira/- [ ] T-01 [humano: verificação] primeira/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm h
out=$(bash "$RALPH" f -y 2>&1); rc=$?
check "tarefa humana: exit 2" "$rc" "2"
check "claude não chamado" "$(calls)" "0"
has "preflight diz onde vai parar" "$out" "parar já na primeira tarefa"

echo "== 10. preflight"
make_repo "$TMP/t10"; plan_2_tasks
echo sujeira > novo.txt
bash "$RALPH" f -y >/dev/null 2>&1; check "árvore suja aborta" "$?" "1"
rm -f novo.txt
bash "$RALPH" ../../etc -y >/dev/null 2>&1; check "slug malicioso recusado" "$?" "1"
bash "$RALPH" inexistente -y >/dev/null 2>&1; check "slug inexistente aborta" "$?" "1"
sed -i.bak 's/sh \.\/faketest\.sh`$/sh .\/faketest.sh; echo x`/' .sdd/plans/f.md; rm -f .sdd/plans/f.md.bak
git add -A >/dev/null; git commit -qm v
out=$(bash "$RALPH" f -y --dry-run 2>&1)
has "marca comando fora do config" "$out" "não vem do config.json"
printf '{"commands":{"test":null}}\n' > .sdd/config.json; git add -A >/dev/null; git commit -qm c
bash "$RALPH" f -y --no-review >/dev/null 2>&1; check "sem gate e sem revisão recusa" "$?" "1"

echo "== 11. --dry-run não altera nada"
make_repo "$TMP/t11"; plan_2_tasks
before=$(git rev-parse HEAD)
bash "$RALPH" f -y --dry-run >/dev/null 2>&1; check "exit 0" "$?" "0"
check "sem commit novo" "$(git rev-parse HEAD)" "$before"
check "claude não chamado" "$(calls)" "0"

echo "== 12. retomada e descarte"
make_repo "$TMP/t12"; plan_2_tasks
out=$(FAKE_TEST_EXIT=1 bash "$RALPH" f -y 2>&1)
has "imprime como retomar" "$out" "Como retomar"
has "sugere descartar" "$out" "--descartar-tentativa"
bash "$RALPH" f -y >/dev/null 2>&1; check "retomar sem limpar aborta" "$?" "1"
bash "$RALPH" f -y --descartar-tentativa </dev/null >/dev/null 2>&1; check "-y NÃO confirma descarte" "$?" "1"
check "nada foi apagado" "$([ -n "$(git status --porcelain)" ] && echo sujo || echo limpo)" "sujo"
RALPH_CONFIRM_DISCARD=1 bash "$RALPH" f -y --descartar-tentativa >/dev/null 2>&1; rc=$?
check "descarte confirmado conclui" "$rc" "0"
check "duas marcadas após retomada" "$(done_count)" "2"
check "árvore limpa ao fim" "$([ -n "$(git status --porcelain)" ] && echo sujo || echo limpo)" "limpo"

cd /; rm -rf "$TMP"
echo; echo "Resultado: $PASS ok, $FAIL falha(s)"
[ "$FAIL" -eq 0 ]
