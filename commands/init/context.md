---
description: Passo 1 da cadeia init — confirma se o projeto é novo ou existente, descobre stack, ambiente e convenções e gera .sdd/STANDARDS.md, .sdd/config.json, CLAUDE.md e, em projetos existentes, o retrato do sistema atual em .sdd/codebase.md.
argument-hint: "[--novo | --existente] [observações opcionais]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# init:context

Você define **como** se desenvolve neste projeto e, se ele já existe, registra **o que ele
já faz**. Este comando é agnóstico de tecnologia: tudo vem do que existe no repositório ou do
que o desenvolvedor decide — nunca de uma stack presumida.

| Arquivo | Conteúdo | Quando |
|---|---|---|
| `.sdd/STANDARDS.md` | stack, arquitetura, convenções, testes — cada regra com origem | sempre |
| `.sdd/config.json` | modo do projeto, ambiente e comandos exatos (legível por máquina) | sempre |
| `CLAUDE.md` | redirecionamento enxuto para STANDARDS | sempre |
| `.sdd/codebase.md` | retrato do sistema atual: módulos, entidades, interfaces, regras | só projeto **existente** |
| `.mcp.json` | navegador (Playwright MCP) para a verificação de interface | projeto com interface, com sua aprovação |

Argumentos do desenvolvedor:

```
$ARGUMENTS
```

## 1. Descobrir antes de perguntar

Não pergunte o que dá para detectar. Leia:

- **Manifestos e lockfiles** de qualquer ecossistema (ex.: `package.json`, `composer.json`,
  `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml`,
  `build.gradle*`, `*.csproj`, `pubspec.yaml`, `mix.exs`). Versões vêm do manifesto/lockfile,
  nunca de suposição.
- **Configuração de build, qualidade e testes** encontrada na raiz e nos manifestos
  (scripts declarados, configs de linter/formatter/test runner, `Makefile`, `justfile`, `Taskfile*`).
- **Ambiente**: `Dockerfile`, `docker-compose*.yml`/`compose*.yml`, `.devcontainer/`, wrappers
  de container do próprio framework.
- **CI**: `.github/workflows/*`, `.gitlab-ci.yml`, `azure-pipelines.yml`, etc. — costuma
  revelar os comandos reais de teste e build.
- **Documentação**: `README*`, `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `CONTRIBUTING*`,
  `docs/`. Nunca `CLAUDE.local.md` (é pessoal do desenvolvedor).
- **Variáveis de ambiente**: somente arquivos de exemplo (`.env.example`, `.env.sample`).
  Nunca leia `.env` nem equivalentes com segredos.
- **Histórico** (somente leitura): `git log --oneline -20` e `git rev-list --count HEAD`.
- **Frontend**: onde vive o código de interface (páginas, componentes, estilos, templates).
  Vira `paths.frontend` no `config.json` e decide quando a verificação de interface roda.
- **Padrões de interface**: layout usado pelas páginas autenticadas (qual componente de
  navegação é o padrão — sidebar, header), biblioteca de componentes, padrão de formulário,
  retorno após ação (toast, flash), estados vazios. Abra pelo menos uma página existente e
  o layout que ela usa: é daqui que sai a seção **Interface** do STANDARDS.

Ordem de confiança para qualquer afirmação técnica: código → documentação do projeto →
documentação oficial da ferramenta → "não tenho certeza" (marcado como tal). Nunca invente.

## 2. Modo do projeto: novo ou existente

O modo muda toda a cadeia, por isso é **sempre confirmado** — mas com evidência e em um clique.

**Ordem de decisão** (vence a primeira que se aplicar):

1. `$ARGUMENTS` contém `--novo` → `greenfield`; `--existente` → `brownfield`. Não pergunte.
2. `.sdd/config.json` já tem `project_mode` → mantenha. Não pergunte (reexecução).
3. Caso contrário, colete a evidência e **confirme** com `AskUserQuestion`.

**Evidência** (agnóstica de stack — colete e mostre):

```bash
echo "commits: $(git rev-list --count HEAD 2>/dev/null || echo 'sem git')"
echo "arquivos versionados: $(git ls-files 2>/dev/null | wc -l)"
git ls-files 2>/dev/null | grep -viE '(^|/)(vendor|node_modules|dist|build|public|storage|\.git)/|lock|\.(md|json|ya?ml|toml|lock|svg|png|jpg|ico)$' | wc -l | sed 's/^/arquivos de código: /'
```

Complemente lendo a estrutura: existe código de **domínio próprio** (entidades, telas,
serviços, regras que falam a língua do negócio) ou só o esqueleto gerado pelo
framework/starter kit (arquivos de exemplo, autenticação padrão, página de boas-vindas)?

- Nenhum arquivo de código, ou só esqueleto → sugira `greenfield`.
- Código de domínio próprio → sugira `brownfield`.

**Pergunta** (uma só, na primeira rodada, com a sugestão como primeira opção):

> Detectei um projeto **<novo|existente>**: <evidência em uma linha — ex.: "12 commits,
> apenas o esqueleto do framework, nenhuma entidade de negócio">. Confirma?
> Opções: `Novo — vou descrever o produto do zero` / `Existente — documentar o que já há`

Grave a resposta em `config.json` → `project_mode`.

## 3. Reexecução (upsert)

Se os arquivos já existem, **atualize — nunca recrie do zero**:

- Leia `.sdd/STANDARDS.md` e `.sdd/config.json` **antes** de qualquer pergunta.
- Regras `[decidido]` são decisões do desenvolvedor: preserve o texto. Só questione se o
  código atual as contradisser.
- Regras `[observado]` podem ser atualizadas para refletir o código atual.
- Regra apagada pelo desenvolvedor continua apagada, salvo confirmação.
- Pergunte **apenas** sobre deltas. Use **Edit** para mudanças pontuais.
- `STANDARDS.md` **sem** a linha de identificação (linha 2) foi escrito à mão: não
  sobrescreva. Se `preferences.standards_manual` = `"manter"`, apenas leia o arquivo como
  fonte e não pergunte. Caso contrário, mostre o que geraria e pergunte:
  - **mesclar** → todo o conteúdo manual é preservado como `[decidido]`, o arquivo ganha as
    linhas 2–3 e passa a ser gerenciado por este comando;
  - **manter** → grave `"manter"` e não pergunte de novo. Neste caso o STANDARDS fica fora
    do upsert e sem carimbo; `codebase.md`, `config.json` e `CLAUDE.md` seguem normalmente.
- `.sdd/codebase.md` é **sempre regenerado por completo** (é um retrato do código, não
  guarda decisões). Observações manuais sobre o sistema pertencem ao STANDARDS como
  `[decidido]` ou ao `STATE.md`.
- Para trocar o modo (ex.: o MVP ficou pronto e o projeto passa a ser tratado como
  existente), o desenvolvedor passa `--existente` explicitamente.

## 4. Entrevistar para fechar lacunas

Pergunte só o que muda o formato do projeto e não pôde ser detectado. `AskUserQuestion` para
escolhas com opções claras; texto livre para perguntas abertas. **Agrupe** perguntas
relacionadas numa mesma rodada, junto com a confirmação do modo.

- **Novo, sem nenhum código**: linguagem/stack e versões-alvo, tipo de aplicação,
  gerenciador de pacotes, framework de testes, estilo de arquitetura, padrão de commit/branch.
- **Novo, com esqueleto**: confirme o que o esqueleto já define; pergunte só o que ele não
  define (camadas extras, framework de testes, padrão de commit).
- **Existente**: confirme padrões que parecerem inconsistentes no código (ex.: metade da
  validação em um lugar, metade em outro — qual é o padrão a seguir?).

O que continuar indefinido vira item em **Questões em aberto**, nunca uma resposta inventada.

### Verificação de interface

Projeto com interface de usuário e `preferences.ui_verify` ainda não definido? Pergunte,
nesta mesma rodada, se o desenvolvedor quer a **verificação de interface**: um agente que
abre a aplicação num navegador e percorre os critérios de cada tarefa que toca o frontend.

Aceito (`preferences.ui_verify: "aceito"`), são necessárias três coisas — só a primeira é
feita aqui; as outras duas viram tarefa de base no primeiro `/plan` com interface, porque
são código do projeto:

1. **Navegador (este comando):** proponha o `.mcp.json` da raiz do projeto com o servidor
   Playwright MCP, em **versão fixada** — confira a versão atual com o desenvolvedor antes
   de escrever (`npm view @playwright/mcp version`), porque o `npx` baixa o pacote:

   ```json
   {
     "mcpServers": {
       "playwright": {
         "command": "npx",
         "args": ["@playwright/mcp@<versão>", "--headless", "--output-dir", ".sdd/logs/ui"]
       }
     }
   }
   ```

   `.mcp.json` existente: nunca sobrescreva; mescle só a entrada `playwright`. Confira na
   documentação da versão escolhida os nomes das opções e, se houver, a que restringe as
   origens permitidas — use-a para limitar a navegação à URL de verificação.
2. **Ambiente de verificação separado (tarefa do /plan):** servidor e banco próprios, para
   o agente não criar dados no banco de desenvolvimento. Ficam registrados como
   `commands.verify_prepare`, `commands.verify_serve`, `environment.verify_url` e
   `environment.verify_users`.
3. **Usuários de verificação por ator (tarefa do /plan):** criados pelo `verify_prepare`,
   com senha fictícia conhecida, só no banco de verificação.

Recusado (`"recusado"`): registre em **Interface** do STANDARDS
`[decidido] sem verificação de interface por navegador` e não pergunte de novo.

## 5. Escrever `.sdd/STANDARDS.md`

Idioma do desenvolvedor. Três primeiras linhas fixas:

```markdown
# Padrões de desenvolvimento — <Nome do Projeto>
<!-- sdd:generated-by init:context v<versão do plugin> — upsert: regras [decidido] são preservadas em reexecuções -->
<!-- sdd:inputs <manifesto>@sha256:<12 hex> ... -->
```

Linha 2: a versão é a do plugin que está gerando o arquivo — o roteador usa isso para avisar
quando o formato mudou numa atualização:

```bash
SDD_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$SDD_ROOT" ] || SDD_ROOT=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1 | sed 's|/scripts/sdd-check.sh$||')
SDD_VER=$(grep -oE '"version"[^,]*' "$SDD_ROOT/.claude-plugin/plugin.json" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
echo "plugin v${SDD_VER:-?} · check: $SDD_ROOT/scripts/sdd-check.sh"
```

Linha 3: carimbe **cada manifesto principal encontrado na raiz** (nunca lockfiles). Sem
manifesto: `<!-- sdd:inputs none -->`.

```bash
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-12; }
for f in package.json composer.json pyproject.toml requirements.txt go.mod Cargo.toml Gemfile pom.xml build.gradle build.gradle.kts pubspec.yaml mix.exs *.csproj; do
  [ -f "$f" ] && printf '%s@sha256:%s ' "$f" "$(h "$f")"
done; echo
```

**Origem obrigatória em toda regra:**

- `[observado: <arquivo>]` — padrão visto no código, com um arquivo real de exemplo.
- `[decidido]` — definido pelo desenvolvedor.
- `[esqueleto: <framework/starter kit>]` — herdado do esqueleto, ainda sem código próprio.

**Seções (exatamente estas `##`, nesta ordem):**

```markdown
## Stack
<tabela: Componente | Versão | Origem>

## Arquitetura
<estilo, organização de pastas, responsabilidade de cada camada, fronteiras que não podem ser cruzadas>

## Convenções de código
<nomenclatura, formatação/linters, padrões recorrentes — em projeto existente, no mínimo 3
padrões [observado] com arquivo de exemplo>

## Testes
<framework, localização, tipos (unitário/integração/e2e), nomenclatura, dados de teste,
banco/serviços de teste. Comandos: config.json → commands>

## Interface
<padrões observados da interface, cada um com origem: layout padrão das páginas
autenticadas e onde fica a navegação (ex.: sidebar em `app-sidebar.tsx`, não o header),
biblioteca de componentes e onde ficam, padrão de formulário (componente, exibição de
erro por campo), retorno após ação (toast, flash), estados vazio/carregando, **idioma da interface e das
mensagens de validação** (o que o usuário lê hoje — se as mensagens do framework aparecem
em inglês e a interface está em português, registre isso e trate como decisão a tomar),
uma **tela de referência** que representa bem o padrão (rota e arquivo). Projeto sem interface: uma linha
dizendo isso.>

## Segurança
<como o projeto se protege hoje, cada item com origem: autenticação (onde é exigida),
autorização (policies, middlewares, checagem de dono), validação de entrada no servidor,
escape de saída, CSRF, upload, tratamento de erro em produção, onde ficam os segredos.
Em projeto novo, o que o esqueleto já traz como [esqueleto] e o que o desenvolvedor decidiu
como [decidido]. Lacunas visíveis viram itens em Questões em aberto.>

## Git
<padrão de commit e branch>

## Regras para agentes
<nunca ler arquivos de segredo; nunca push/deploy; nunca comandos destrutivos de dados fora
do ambiente de teste; comandos sempre com environment.exec_prefix; etc.>

## Questões em aberto
<Q-01, Q-02... ou "Nenhuma.">
```

## 6. Escrever `.sdd/codebase.md` (somente projeto existente)

Retrato do **sistema como ele é hoje**, para que `/plan` saiba o que já existe, o que será
tocado e o que não deve ser replanejado. Documenta realidade, nunca intenção: não leia nem
cite `.sdd/project.md`, `.sdd/roadmap.md`, specs ou planos.

Três primeiras linhas fixas:

```markdown
# Sistema atual — <Nome do Projeto>
<!-- sdd:generated-by init:context v<versão do plugin> — regenerado por completo a cada execução; não edite à mão -->
<!-- sdd:inputs git-head@<12 hex> -->
```

Linha 3: `git rev-parse --short=12 HEAD` (sem git: `<!-- sdd:inputs none -->`).

Como levantar (amostragem guiada, não leitura integral do repositório):

1. Mapeie a estrutura de pastas até 2–3 níveis, ignorando dependências e artefatos de build.
2. Identifique onde vivem entidades/dados (models, schemas, migrations, entidades ORM, DTOs),
   interfaces (rotas, controllers, handlers, resolvers, comandos CLI, consumidores de fila,
   jobs agendados) e telas.
3. Leia os arquivos centrais de cada módulo e **extraia regras de negócio** de validações,
   estados, permissões e cálculos — sempre com `arquivo:linha`.
4. Liste integrações pelos clientes HTTP/SDKs usados e pelas variáveis do arquivo de exemplo.
5. Veja quais áreas têm testes (pelos nomes/pastas dos testes), sem rodá-los.

**Seções (exatamente estas `##`, nesta ordem):**

```markdown
## Visão geral
<2–3 parágrafos: o que o sistema faz hoje, para quem, fluxo macro>

## Módulos
| Módulo | Responsabilidade | Onde fica |
|---|---|---|

## Entidades

### E-01: <Entidade>
- **Representa:** <uma frase>
- **Campos relevantes:** <nome — regra/observação>
- **Relacionamentos:** <E-NN ...>
- **Fonte:** `<arquivo>`

## Interfaces
<rotas/APIs, telas, comandos, jobs, filas — agrupadas por módulo, com arquivo de origem.
Resuma por grupo quando houver muitas; não liste centenas de itens>

## Regras de negócio implementadas
- **RN-01** (<módulo>): <regra como está implementada> — `arquivo:linha`

## Integrações externas
<serviço, finalidade, onde é usado — ou "Nenhuma.">

## Cobertura de testes existente
<áreas com testes e áreas sem testes, pela estrutura — sem percentual inventado>

## Pontos de atenção
<inconsistências, duplicações, código morto aparente, dívida técnica visível — cada item com arquivo>
```

Regras:

- Todo item cita arquivo (e linha, para regras). Sem evidência → não entra.
- IDs `E-NN` e `RN-NN` sequenciais a partir de 01, regenerados a cada execução.
- Alvo de tamanho: até ~5 mil tokens. Projeto maior → resuma por módulo e aponte arquivos,
  em vez de detalhar tudo. Profundidade extra é trabalho do `/plan`, na área que ele tocar.
- Nunca proponha melhorias aqui (isso não é plano); só registre em **Pontos de atenção**.

## 7. Escrever `.sdd/config.json`

```json
{
  "schema_version": 1,
  "project_mode": "brownfield",
  "environment": {
    "exec_prefix": "",
    "notes": "",
    "verify_url": null,
    "verify_users": {}
  },
  "paths": {
    "frontend": []
  },
  "preferences": {},
  "commands": {
    "install": null,
    "test": null,
    "test_filter": null,
    "e2e": null,
    "security": null,
    "lint": null,
    "format": null,
    "typecheck": null,
    "build": null,
    "dev": null,
    "verify_prepare": null,
    "verify_serve": null
  }
}
```

- `environment.exec_prefix`: prefixo para rodar comandos quando o projeto executa dentro de
  container (ex.: `docker compose exec app`, ou o wrapper de container do framework). Vazio se
  roda no host. Se houver dúvida, pergunte.
- Preencha cada comando **somente** se ele existir de fato (script declarado no manifesto,
  alvo de Makefile/Taskfile, binário do projeto como `vendor/bin/…` ou `node_modules/.bin/…`,
  passo de CI). Inexistente → `null`. Comandos já incluem o `exec_prefix`, prontos para executar.
- **Um comando por valor, nunca encadeado.** Nada de `&&`, `;` ou `|`: a lista de
  permissões do `ralph.sh` avalia comando por comando, e um valor encadeado nunca casa.
  Existe um script do manifesto que já faz tudo? Use-o. Precisa de mais de um? Use uma
  lista: `"lint": ["composer lint:check", "npm run check"]`. O `sdd-check.sh` reprova
  valores encadeados.
- `test_filter` usa o marcador `{filter}` onde entra o nome/padrão do teste.
- `test` é o comando que o `ralph.sh` roda por fora do agente para decidir se a tarefa
  passou: se houver mais de um candidato, confirme com o desenvolvedor.
- `security` é o gate mecânico de segurança do fecho da feature: auditoria de dependências
  do gerenciador de pacotes e/ou analisador estático que o projeto **já** use (script no
  manifesto, passo de CI). Nunca invente nem sugira instalar um analisador aqui; mais de
  um vira lista.
- `e2e` é o comando de testes ponta a ponta **versionados** que o projeto já tenha
  (configuração de runner na raiz, script no manifesto, passo de CI). Não encontrou → `null`.
  Não confunda com a verificação de interface por navegador, que não depende disso.
- `paths.frontend`: lista de padrões de caminho do código de interface
  (ex.: `["resources/js/**", "resources/css/**", "resources/views/**"]`). Tarefa que altera
  qualquer um deles aciona a verificação de interface. Projeto sem interface → `[]`.
- `verify_prepare`, `verify_serve`, `environment.verify_url`, `environment.verify_users`:
  ambiente da verificação de interface. Ficam `null`/vazios aqui; quem preenche é a tarefa
  de base do primeiro `/plan` com interface.
- `preferences` guarda respostas que não devem ser perguntadas de novo. Chaves usadas por
  este comando: `claude_md_import` (`aceito`/`recusado`), `claude_md_migration` (`manter`),
  `agents_md_reference` (`aceito`/`recusado`), `standards_manual` (`manter`),
  `ui_verify` (`aceito`/`recusado`), `claude_settings_deny` (`aceito`/`recusado`). Chave ausente =
  ainda não perguntado. O desenvolvedor pode apagar uma chave para ser perguntado de novo.
- Em reexecução, preserve chaves editadas à mão e chaves desconhecidas.
- Valide o JSON com o primeiro disponível: `jq .` → `python3 -m json.tool` →
  `python -m json.tool` → `node -e "JSON.parse(require('fs').readFileSync('.sdd/config.json'))"`.

## 8. `CLAUDE.md`

O `CLAUDE.md` é só um ponteiro: o conteúdo vive no STANDARDS. Este passo garante o import
`@.sdd/STANDARDS.md` sem nunca destruir o que o desenvolvedor já escreveu.

### 8.1 Localizar o arquivo

```bash
for f in CLAUDE.md .claude/CLAUDE.md; do test -f "$f" && echo "existe: $f"; done
```

- Existe `CLAUDE.md` na raiz → ele é o alvo.
- Só existe `.claude/CLAUDE.md` → ele é o alvo; **não** crie outro na raiz.
- Existem os dois → alvo é o da raiz; pergunte se o import também deve ir para o outro.
- Nenhum → crie `CLAUDE.md` na raiz (8.2).
- `CLAUDE.local.md` e `~/.claude/CLAUDE.md` são pessoais: **nunca** leia para migrar nem edite.

### 8.2 Não existe → criar

Idioma do desenvolvedor:

```markdown
# CLAUDE.md

Este projeto segue Spec Driven Development (SDD).
Padrões de desenvolvimento, arquitetura e regras para agentes:
@.sdd/STANDARDS.md

Comandos do projeto: `.sdd/config.json` → `commands`.
Retrato do sistema atual (ler ao planejar ou alterar módulos existentes): `.sdd/codebase.md`.
Specs em `.sdd/specs/`, planos em `.sdd/plans/`. Use os comandos do plugin spec-driven-dev.
```

Omita a linha do `codebase.md` em projeto novo. O `codebase.md` é referenciado por caminho,
**não** importado com `@`, para não carregar o retrato inteiro em toda sessão.

### 8.3 Existe → nunca sobrescrever

Leia o alvo por completo (ele já foi usado como fonte na descoberta, §1) e siga em ordem.
Toda alteração é feita com **Edit**, só depois de mostrar o diff e receber confirmação.
Agrupe as perguntas deste passo numa única rodada.

**a) Import**

- Já contém `@.sdd/STANDARDS.md` → nada a fazer, nada a perguntar.
- `config.json` → `preferences.claude_md_import` = `"recusado"` → não pergunte. Apenas
  lembre no relatório, em uma linha, que sessões fora do plugin não enxergam os padrões.
- Caso contrário → proponha inserir, **logo após a primeira linha de título** (`# ...`; sem
  título, na primeira linha do arquivo), o bloco:

  ```markdown

  Padrões de desenvolvimento deste projeto (Spec Driven Development):
  @.sdd/STANDARDS.md
  ```

  Mostre o diff. Aceito → aplique e grave `"aceito"`. Recusado → grave `"recusado"` e avise
  que, sem o import, o Claude Code fora dos comandos do plugin não carrega os padrões.

**b) Blocos de terceiros**

Regiões no formato `<tag>...</tag>` (ex.: `<laravel-boost-guidelines>`) são preservadas byte a
byte, na mesma posição. Nunca edite, mova, migre ou insira texto dentro delas. O import nunca
é inserido dentro de um bloco desses.

**c) Duplicações e contradições**

Compare as regras do `CLAUDE.md` (fora dos blocos de terceiros) com o que foi para o STANDARDS:

- **Duplicada** (mesma regra nos dois) → mostre o trecho e pergunte: migrar ou manter?
  Migrar = o trecho sai do `CLAUDE.md` e a regra fica no STANDARDS como
  `[decidido: migrado do CLAUDE.md]`.
- **Contraditória** (o `CLAUDE.md` diz uma coisa e o código mostra outra — ex.: "use a
  biblioteca X" e todo o código usa Y) → não migre nem escolha sozinho. Pergunte qual vale:
  - vale o `CLAUDE.md` → a regra entra no STANDARDS como `[decidido: migrado do CLAUDE.md]`
    e o desvio do código vai para **Pontos de atenção** do `codebase.md` (se houver);
  - vale o código → a regra entra como `[observado: <arquivo>]` e pergunte se o trecho
    contraditório deve sair do `CLAUDE.md`.
- **Só existe no `CLAUDE.md`** (sem equivalente no código) → trate como decisão do
  desenvolvedor: pergunte se copia para o STANDARDS como `[decidido: migrado do CLAUDE.md]`.
- `preferences.claude_md_migration` = `"manter"` → não pergunte mais sobre duplicações;
  contradições **sempre** são perguntadas, porque mudam a regra efetiva.
- Se o desenvolvedor responder "manter tudo como está", grave `"manter"`.

**d) `AGENTS.md`**

Se existir, ele já foi usado como fonte (§1). Se o alvo ainda não o referencia e
`preferences.agents_md_reference` não estiver definido, pergunte se o `CLAUDE.md` deve
importá-lo (`@AGENTS.md`). Grave `"aceito"` ou `"recusado"`.

## 9. Preparar o repositório

```bash
if git rev-parse --git-dir >/dev/null 2>&1; then
  ex="$(git rev-parse --git-dir)/info/exclude"; mkdir -p "$(dirname "$ex")"; touch "$ex"
  for p in '.sdd/logs/' '.sdd/.ralph-*.lock'; do grep -qxF "$p" "$ex" || echo "$p" >> "$ex"; done
fi
```

- Sem git: avise que o `ralph.sh` depende de git para commits por tarefa.
- Não crie `.sdd/specs/`, `.sdd/plans/` nem `.sdd/logs/` vazios.
- Nenhuma escrita no histórico git: nunca `add`, `commit`, `reset`.

## 9b. Barreira de permissões do Claude Code

As regras "nunca leia `.env`" e "nunca faça push" dos comandos são instruções ao modelo. Para
que valham também como barreira técnica, proponha regras de bloqueio no arquivo de
configurações **do projeto**, `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.local)",
      "Read(./.env.production)",
      "Read(./.env.staging)",
      "Read(./**/*.pem)",
      "Read(./**/*.key)",
      "Bash(git push:*)"
    ]
  }
}
```

- Ajuste a lista ao que existe no projeto: acrescente outros arquivos de segredo que você
  encontrou (sem lê-los). **Não** bloqueie `.env.example`: ele é lido na descoberta.
- Arquivo existente: nunca sobrescreva. Mostre o que falta e **mescle** só na lista `deny`,
  preservando todo o resto.
- Pergunte antes de escrever. Grave a resposta em `preferences.claude_settings_deny`
  (`aceito` / `recusado`) e não pergunte de novo.
- Recusado → registre em **Regras para agentes** do STANDARDS:
  `[decidido] sem bloqueio técnico de segredos — proteção apenas por instrução`.

## 10. Decisões de projeto (opcional)

Se a entrevista produziu decisão **difícil de reverter, surpreendente sem contexto e
resultado de trade-off real**, acrescente ao final de `.sdd/STATE.md` (crie só se houver ao
menos uma):

```markdown
### AD-NNN
- **Decisão**: <uma frase>
- **Motivo**: <por quê>
- **Trade-off**: <o que se abriu mão>
- **Escopo**: <o que isso governa>
- **Data**: AAAA-MM-DD
- **Status**: ativa
```

Nunca apague nem reescreva entradas existentes.

## 11. Verificar antes de encerrar

Rode o validador do plugin — as regras estruturais estão nele, não aqui:

```bash
SDD_CHECK="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/sdd-check.sh}"
[ -f "$SDD_CHECK" ] || SDD_CHECK=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1)
bash "$SDD_CHECK" standards
```

- Cada `FALHA` → corrija e rode de novo até não sobrar nenhuma.
- `AVISO` → revise; itens sem origem só são aceitáveis quando puramente descritivos.
- Script não encontrado → **pare** e avise o desenvolvedor. Nunca encerre sem validar.
- Por fim, releia as seções **Segurança**, **Interface** e **Regras para agentes** juntas:
  nenhuma pode contradizer a outra (ex.: uma dizendo que há bloqueio técnico de segredos e
  outra dizendo que não há).

## 12. Relatório

No máximo:
- modo confirmado e `exec_prefix`;
- `CLAUDE.md`: criado / import adicionado / já tinha import / import recusado; trechos migrados e contradições resolvidas;
- contagem de regras por origem (`observado` / `decidido` / `esqueleto`);
- comandos registrados e os que ficaram `null`;
- projeto existente: contagem de módulos, entidades, regras e pontos de atenção;
- questões em aberto;
- próximo passo: `/spec-driven-dev:init` (o roteador escolhe).
