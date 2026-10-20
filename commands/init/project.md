---
description: Passo 2 da cadeia init — entrevista o desenvolvedor e transforma a ideia em uma descrição estruturada do produto em .sdd/project.md (escopo do MVP, domínio, atores, fluxos, entidades).
argument-hint: "[ideia do projeto em uma linha, ou caminho de um arquivo com a descrição]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# init:project

Você transforma uma ideia em uma **descrição clara e estruturada do produto**. Este documento
define **o que** será construído e **por quê** — não como (isso é `STANDARDS.md`) nem em que
ordem (isso é `roadmap.md`). Ele vira a fonte da verdade que o roadmap e o `/plan` consultam.

Ideia inicial do desenvolvedor (pode estar vazia, ou ser um caminho de arquivo):

```
$ARGUMENTS
```

Se `$ARGUMENTS` for um caminho de arquivo existente, leia-o e trate como a ideia inicial.

## Pré-condições

- `.sdd/STANDARDS.md` existe. Se não existir, pare e recomende `/spec-driven-dev:init`.
- Leia `.sdd/STANDARDS.md` e `.sdd/config.json`: stack e arquitetura já estão definidas lá —
  **não pergunte de novo** sobre elas.
- Leia `.sdd/STATE.md` se existir (decisões já tomadas).

## Reexecução (upsert)

Se `.sdd/project.md` já existe, **atualize — nunca recrie do zero**:

- Leia o documento **antes** de entrevistar. Tudo que está escrito nele é decisão.
- Entreviste só sobre deltas: escopo novo, lacunas novas, questões em aberto que agora podem
  ser respondidas, contradições com o código/STANDARDS.
- Atualize com **Edit**. Preserve a numeração de `### F-NN` (fluxos) e `### E-NN`
  (entidades): itens novos recebem o próximo número no fim; **nunca renumere** — o roadmap
  e as specs referenciam esses IDs.
- Item removido pelo desenvolvedor não volta sem confirmação explícita. Se um fluxo sair do
  escopo, mova-o para "Fora do MVP" em vez de apagar, e diga isso no relatório.

## 1. Entender a ideia

Reformule a ideia em 2–3 frases e confirme com o desenvolvedor antes de seguir. Se a ideia
estiver vazia, pergunte primeiro: qual problema o sistema resolve e para quem.

## 2. Entrevistar para fechar lacunas

Encontre o que está indefinido e **impediria o desenvolvimento**. Não interrogue sobre o que
dá para inferir ou que não muda o formato do sistema. Cubra:

- **Propósito e público** — quem usa, que problema resolve, o que é sucesso.
- **Atores e permissões** — perfis de usuário, o que cada um pode ver e fazer.
- **Conceitos de domínio** — os substantivos do negócio, com regras, limites e números
  (ex.: "despesa acima de R$ 500 exige aprovação de dois níveis").
- **Fluxos principais** — passo a passo, incluindo estados e transições
  (ex.: rascunho → enviada → aprovada/reprovada → paga).
- **Fronteira do MVP** — o que entra na v1 e o que fica explicitamente para depois.
- **Integrações e restrições** — sistemas externos, autenticação, notificações, arquivos,
  plataforma, requisitos legais.
- **Requisitos não-funcionais conhecidos** — volume, desempenho, auditoria, LGPD.

Técnica:

- Use `AskUserQuestion` para decisões com opções claras; texto livre para perguntas abertas.
- **Agrupe** perguntas relacionadas em rodadas (no máximo ~5 por rodada), da mais estrutural
  para a mais detalhada. Não pingue uma pergunta por vez.
- Para cada fluxo, pergunte ativamente pelos caminhos infelizes: rejeição, cancelamento,
  edição após envio, prazo expirado, usuário sem permissão.
- Sempre que uma resposta usar termo vago ("rápido", "alguns", "normalmente"), peça o número
  ou a regra.
- Continue até conseguir escrever cada seção sem enrolação. O que o desenvolvedor não souber
  ou quiser adiar vira **Questão em aberto** — nunca uma resposta inventada.

## 3. Escrever `.sdd/project.md`

Escreva no idioma do desenvolvedor. As três primeiras linhas são fixas:

```markdown
# <Nome do Projeto> — Descrição do projeto
<!-- sdd:generated-by init:project v<versão do plugin> — upsert: edições manuais são preservadas; IDs F-NN/E-NN nunca são renumerados -->
<!-- sdd:inputs .sdd/STANDARDS.md@sha256:<12 hex> -->
```

Hash da linha 3:

```bash
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-12; }
echo ".sdd/STANDARDS.md@sha256:$(h .sdd/STANDARDS.md)"
```

Estrutura (exatamente estas seções `##`, nesta ordem):

```markdown
## Visão geral
<2–4 parágrafos: o que é, para quem, qual o valor central, qual a fronteira do MVP.
Negrito nas ideias-chave.>

## Atores e permissões
| Ator | Descrição | Pode | Não pode |
|---|---|---|---|

## Conceitos-chave
- **<Conceito>:** <definição com regras, limites e números quando existirem>

## Fluxos principais

### F-01: <nome do fluxo>
- **Ator(es):** <quem>
- **Gatilho:** <o que inicia>
- **Passos:**
  1. <passo>
  2. <passo>
- **Estados:** <estado → estado, se houver>
- **Regras:** <validações e regras de negócio do fluxo>
- **Caminhos alternativos:** <rejeição, cancelamento, erro, sem permissão>
- **Resultado:** <o que é verdade ao final>

### F-02: ...

## Entidades principais

### E-01: <Entidade>
- **Representa:** <uma frase>
- **Atributos essenciais:** <nome (tipo/regra), ...>
- **Relacionamentos:** <E-NN ...>
- **Usada em:** <F-NN, ...>

<Nível conceitual — não é schema de banco. Sem tipos de coluna nem índices; isso é
decidido no /plan de cada fase.>

## Escopo do MVP
- **Dentro:** <F-NN e capacidades>
- **Fora (depois do MVP):** <itens explicitamente adiados>
- **Não-objetivos:** <o que o sistema nunca fará>

## Integrações e restrições
<sistemas externos, autenticação, notificações (canais), arquivos/anexos, plataforma,
requisitos legais — ou "Nenhuma.">

## Requisitos não-funcionais
<quantificados: "até 200 solicitações/mês", "anexo de até 5 MB", nunca "rápido" — ou "Nenhum definido.">

## Questões em aberto
- **Q-01** (<afeta F-NN/E-NN>): <pergunta>. Impacto: <o que muda conforme a resposta>.
<ou "Nenhuma.">
```

Regras de conteúdo:

- Todo fluxo dentro do MVP usa pelo menos uma entidade; toda entidade é usada por pelo menos
  um fluxo (campo **Usada em**). Entidade sem fluxo → pergunte se sai ou se falta um fluxo.
- Termos proibidos sem número ou regra: "rápido", "adequado", "alguns", "etc.", "quando possível".
- Nada de detalhe de implementação (nomes de classe, tabelas, rotas, componentes) — isso vive
  em STANDARDS e nas specs.

## 4. Decisões de projeto (opcional)

Se a entrevista produziu decisão de produto **difícil de reverter, surpreendente sem contexto
e resultado de trade-off real** (ex.: "aprovação em um único nível no MVP, sem alçadas"),
acrescente `AD-NNN` ao final de `.sdd/STATE.md` no mesmo formato usado por `init:context`.
Nunca edite entradas existentes.

## 5. Verificar antes de encerrar

```bash
SDD_CHECK="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/sdd-check.sh}"
[ -f "$SDD_CHECK" ] || SDD_CHECK=$(find "$HOME/.claude/plugins" -path '*spec-driven-dev/scripts/sdd-check.sh' 2>/dev/null | head -1)
bash "$SDD_CHECK" project
```

Cada `FALHA` → corrija e rode de novo. Termo vago apontado em `AVISO` → reescreva com
número ou regra, ou transforme em questão em aberto. Confira também, à mão, que o
**Usada em** de cada entidade inclui todo fluxo que a cria, altera ou exibe.

## 6. Relatório

Responda com, no máximo:
- a reformulação da ideia em uma frase;
- contagem de fluxos (dentro/fora do MVP), entidades e atores;
- questões em aberto, destacando as que bloqueiam algum fluxo do MVP;
- em reexecução: o que mudou e o aviso de que `roadmap.md` ficará desatualizado;
- próximo passo: `/spec-driven-dev:init` (o roteador escolhe).

## Regras

- Nunca escreva código de aplicação nem schema de banco.
- Escreva somente `.sdd/project.md` e, se aplicável, `.sdd/STATE.md`.
- Nunca leia `.env`. Nenhuma escrita no git.
