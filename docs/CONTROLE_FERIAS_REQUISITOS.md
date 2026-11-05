# Controle de Férias — Documento de Requisitos

> Melhorias solicitadas para a tela **Controle de Férias** (`ferias.html`) e os
> endpoints n8n de apoio (`n8n_ferias_*.sql`). Cada item traz o **ponto do código
> atual** onde a mudança encaixa, para servir de base à implementação.
>
> Data: 2026-07-01 · Solicitante: Direção Geral

---

## Contexto atual (como funciona hoje)

- **Frontend:** [ferias.html](ferias.html) — duas abas: **⚙️ Configuração & Lançamentos**
  (`#view-config`) e **📊 Dashboard do time** (`#view-dash`).
- **Cadastro de colaborador:** modal `modalColaborador()` (`ferias.html:1053`) — hoje só
  captura **nome, cargo, e-mail e banco de férias**.
- **Cards de configuração:** `renderConfig()` (`ferias.html:815`); cards do dashboard:
  `renderDash()` (`ferias.html:877`).
- **Lançamento de férias:** modal `modalLancamento()` (`ferias.html:999`) — só período
  corrido (início → fim).
- **Exclusão de colaborador:** handler em `ferias.html:1210` (`data-delcol`), hoje usa um
  `confirm()` simples e o botão 🗑️ aparece em todo card.
- **Backend (n8n):**
  - Schema: [n8n_ferias_schema.sql](n8n_ferias_schema.sql) — tabelas
    `ferias_colaboradores` e `ferias_lancamentos`.
  - Salvar colaborador: [n8n_ferias_salvar_colaborador.sql](n8n_ferias_salvar_colaborador.sql)
  - Salvar lançamento: [n8n_ferias_salvar_lancamento.sql](n8n_ferias_salvar_lancamento.sql)
  - Excluir colaborador: [n8n_ferias_excluir_colaborador.sql](n8n_ferias_excluir_colaborador.sql)
  - Listar: [n8n_ferias_listar.sql](n8n_ferias_listar.sql)

---

## 1. Cadastro de colaborador: adicionar **Unidade** e **Segmento**

**Pedido:** No botão **＋ Colaborador**, ao cadastrar um novo colaborador, hoje só há
os campos *nome, cargo, e-mail e banco de férias*. É necessário também informar a
**unidade** em que o colaborador trabalha e o **segmento** em que atua, para poder
incluí-lo corretamente.

**Onde mexe:**
- Modal `modalColaborador()` (`ferias.html:1053`) — acrescentar dois campos:
  - **Unidade** (seleção; ideal usar a lista de unidades da plataforma).
  - **Segmento de atuação** (Educação Infantil, Anos Iniciais, Anos Finais, Ensino
    Médio, Bilinguismo) — permitir mais de um.
- `acaoSalvarColaborador()` deve enviar `unidade_id` e `segmentos` no payload.
- **Schema** ([n8n_ferias_schema.sql](n8n_ferias_schema.sql)): adicionar em
  `ferias_colaboradores` as colunas `unidade_id uuid` e `segmentos text[]`
  (ou `segmento_codigo`).
- **Endpoint** [n8n_ferias_salvar_colaborador.sql](n8n_ferias_salvar_colaborador.sql):
  ler e gravar os novos campos no upsert.

---

## 2. Filtros nos cards por **Unidade**, **Cargo** e **Segmento**

**Pedido:** No controle de férias, onde ficam os cards de todos os gestores, poder
**filtrar por unidade, por cargo e por segmento de atuação**. Exemplos: ver apenas
Supervisores de Segmento, apenas Coordenadores de Área, apenas Diretores de Unidade,
apenas Diretores Pedagógicos.

**Onde mexe:**
- Toolbars das duas abas (`#view-config` `ferias.html:584` e `#view-dash`
  `ferias.html:611`) — hoje só têm busca por texto (`colsFiltrados()`, `ferias.html:807`).
- Adicionar controles de filtro (dropdowns/chips): **Unidade**, **Cargo**, **Segmento**.
- `colsFiltrados()` passa a considerar os filtros ativos além do termo de busca.
- Depende dos dados de unidade/segmento por colaborador (ver item 1 e o endpoint de
  listagem [n8n_ferias_listar.sql](n8n_ferias_listar.sql) retornando esses campos).

---

## 3. Exclusão de colaborador com **senha de administrador**

**Pedido:** Ao clicar em **excluir colaborador**, exigir a **senha de login do
administrador** — apenas os **dois administradores** podem excluir. O botão de excluir
**não deve ficar visível para nenhum outro gestor** da rede.

**Onde mexe:**
- **Visibilidade:** no `renderConfig()` (`ferias.html:842`) só renderizar o botão 🗑️
  (`data-delcol`) quando o usuário logado for um dos dois administradores. Hoje o botão aparece
  em todos os cards.
- **Confirmação por senha:** substituir o `confirm()` de `ferias.html:1213` por um modal
  que pede a **senha do administrador** e valida antes de excluir.
- **Backend:** [n8n_ferias_excluir_colaborador.sql](n8n_ferias_excluir_colaborador.sql)
  já tem a allowlist `editores(email)` (linhas 30–36) preparada para restringir aos
  administradores — basta **preencher os e-mails**. Além disso, a exclusão deve **revalidar
  a senha** (conferir o hash em `login_sessoes`/`app_usuarios`) no payload.

> **Decisão pendente:** confirmar os e-mails de login dos dois administradores para
> travar a allowlist (aparecem comentados como `usuario1@exemplo.edu.br` /
> `usuario2@exemplo.edu.br` nos SQLs — confirmar os reais).

---

## 4. Dois tipos de lançamento: **férias corridas** e **desconto avulso**

**Pedido:** Poder lançar **férias corridas** (data de início e data de fim) e também
fazer **desconto de dias avulsos** — quando se concede 1 ou 2 dias a um gestor que não
são férias corridas, mas que precisam ser **debitados do saldo** de dias a gozar.

**Onde mexe:**
- Modal `modalLancamento()` (`ferias.html:999`) — adicionar um seletor de **tipo de
  lançamento**:
  - **Férias corridas** → início + fim (comportamento atual).
  - **Desconto avulso** → informar apenas a **quantidade de dias** (e data/observação),
    sem exigir período corrido.
- **Schema** ([n8n_ferias_schema.sql](n8n_ferias_schema.sql)): adicionar
  `tipo text not null default 'ferias'` em `ferias_lancamentos` (valores: `ferias` /
  `avulso`). Para avulso, `data_inicio`/`data_fim` podem ser a mesma data ou nulas.
- **Endpoint** [n8n_ferias_salvar_lancamento.sql](n8n_ferias_salvar_lancamento.sql):
  aceitar `tipo` e não exigir `data_fim >= data_inicio` quando for avulso.
- O saldo já é derivado da **soma dos dias** dos lançamentos (`usados()`,
  `ferias.html:699`), então o desconto avulso entra naturalmente no cálculo.

---

## 5. Dashboard do time: **overlay** ao clicar no card do gestor

**Pedido:** No dashboard do time, ao **clicar no card** de um gestor, abrir um
**overlay** com as informações de férias daquele gestor: **datas em que foram tiradas,
quanto ainda resta (pendente) para tirar**, e assim por diante.

**Onde mexe:**
- `renderDash()` (`ferias.html:877`) — tornar o card clicável.
- Criar um modal `modalDetalhe(colId)` (nos moldes de `modalLancamento`,
  `ferias.html:999`) mostrando:
  - Banco total, dias já gozados, **dias restantes/pendentes**.
  - **Histórico de períodos** (cada lançamento: início → fim, dias, tipo, observação).
  - Próximo período agendado.
  - Unidade e segmentos (flags — ver item 7).

---

## 6. Configuração & Lançamentos: **agrupar por cargo em seções**

**Pedido:** Na tela principal de Controle de Férias, na parte de **Configuração e
Lançamentos**, os gestores devem vir **separados em seções por cargo**:
- **Direção Pedagógica**
- **Direção de Unidade**
- **Supervisores de Segmento e Bilinguismo** (juntos na mesma seção)

**Onde mexe:**
- `renderConfig()` (`ferias.html:815`) — em vez de uma grade única, agrupar os
  colaboradores por cargo e renderizar um **cabeçalho de seção** por grupo.
- Reaproveitar o mapa `CARGO_LABELS` (`ferias.html:1276`) / `rotuloCargo()`
  (`ferias.html:1283`) para os títulos.
- Definir a **ordem** das seções (ex.: Direção Pedagógica → Direção de Unidade →
  Supervisão de Segmento e Bilinguismo → demais).

---

## 7. Flags de **Unidade** e **Segmento** nos cards

**Pedido:** Em cada card de gestor, exibir um **flag da unidade** em que ele atua e
**outro flag dos segmentos** que atua: Educação Infantil, Anos Iniciais, Anos Finais,
Ensino Médio ou Bilinguismo.

**Onde mexe:**
- Cabeçalho dos cards em `renderConfig()` (`ferias.html:842`) e `renderDash()`
  (`ferias.html:910`) — adicionar, abaixo/ao lado do cargo (`.cc-cargo`), duas linhas
  de badges: **unidade** e **segmento(s)**.
- Depende dos campos de unidade/segmento por colaborador (item 1 + listagem).
- Reaproveitar o estilo de pílulas já existente (ex.: `.tb-pill`, `ferias.html:163`).

---

## 8. Nova seção-resumo: **saldo simplificado de todos os gestores**

**Pedido:** Na tela inicial de configuração (dos cards), ter uma **seção simplificada**
listando **todos os gestores** com: **dias pendentes para tirar**, **dias já tirados**
e **saldo**. Separar quem **já realizou o agendamento** das férias de quem **ainda não
agendou** (duas listas/blocos).

**Onde mexe:**
- Nova seção no `#view-config` (`ferias.html:582`), acima ou abaixo dos cards atuais.
- Renderizar uma **tabela/lista enxuta** (nome · cargo · dias tirados · pendentes ·
  saldo), reutilizando `usados()` (`ferias.html:698`) e `restantes()` (`ferias.html:699`).
- **Dois grupos:**
  - **Já agendados** — colaboradores com ao menos um lançamento (`c.lancamentos.length > 0`).
  - **Sem agendamento** — colaboradores sem nenhum lançamento.

---

## Resumo de impacto por arquivo

| Arquivo | Mudanças |
|---|---|
| [ferias.html](ferias.html) | Itens 1–8: campos no modal, filtros, agrupamento por cargo, flags nos cards, overlay de detalhe, tipo de lançamento, seção-resumo, visibilidade + senha na exclusão |
| [n8n_ferias_schema.sql](n8n_ferias_schema.sql) | `ferias_colaboradores`: `unidade_id`, `segmentos`. `ferias_lancamentos`: `tipo` |
| [n8n_ferias_salvar_colaborador.sql](n8n_ferias_salvar_colaborador.sql) | Gravar unidade e segmentos |
| [n8n_ferias_salvar_lancamento.sql](n8n_ferias_salvar_lancamento.sql) | Aceitar `tipo` (férias/avulso) |
| [n8n_ferias_excluir_colaborador.sql](n8n_ferias_excluir_colaborador.sql) | Allowlist dos administradores + revalidação de senha |
| [n8n_ferias_listar.sql](n8n_ferias_listar.sql) | Retornar unidade, segmentos e `tipo` do lançamento |

---

## ✅ Status de implementação (2026-07-01)

Todos os 8 itens foram implementados em [ferias.html](ferias.html) e nos SQLs.
Decisões aplicadas: implementar tudo; unidade/segmento via **dropdown** (servido pelo
`/ferias/listar`); exclusão liberada a **qualquer ADMIN**; trava da exclusão por
**OTP** (código no e-mail do admin, já que o login é sem senha).

| Item | Estado |
|---|---|
| 1. Unidade + segmentos no cadastro | ✅ modal com dropdown de unidade e checkboxes de segmento (+ botão editar no card) |
| 2. Filtros unidade/cargo/segmento | ✅ barra de filtros nas abas Configuração e Dashboard |
| 3. Exclusão ADMIN + OTP | ✅ botão só p/ ADMIN; modal envia código ao e-mail e valida antes de excluir |
| 4. Férias corridas + desconto avulso | ✅ toggle no modal de lançamento; avulso debita dias soltos |
| 5. Overlay de detalhe | ✅ clique no card do Dashboard abre overlay com saldo e histórico |
| 6. Seções por cargo | ✅ Configuração agrupa em Direção Geral, DP, DU, Supervisão+Bilinguismo, Coordenação |
| 7. Flags unidade/segmento | ✅ pílulas 📍unidade e de segmentos nos cards e no overlay |
| 8. Seção-resumo | ✅ blocos "Já agendadas" x "Sem agendamento" com tirados/pendentes/saldo |

### ⚠️ Para funcionar no ambiente real (deploy no n8n/PostgreSQL)
1. Rodar [n8n_ferias_schema.sql](n8n_ferias_schema.sql) no banco (adiciona
   `unidade_id`, `segmentos` em colaboradores e `tipo` em lançamentos — os `alter … if
   not exists` são idempotentes).
2. Republicar os endpoints alterados: **listar**, **salvar_colaborador**,
   **salvar_lancamento** (o SQL de cada nó "Code/Postgres" no n8n).
3. Sem o deploy, a tela continua funcional em **modo local** e em **?demo=1**
   (dados de exemplo já mostram unidade, segmentos e um lançamento avulso).

---

## Pendências a confirmar

1. **E-mails de login** dos dois administradores (para travar a allowlist de exclusão).
2. **Origem das unidades/segmentos** no cadastro: usar as listas já existentes na
   plataforma (dropdown) ou digitação livre?
3. **Filtro de cargo** — usar os códigos internos (`SUPERVISAO_SEGMENTO`,
   `COORDENACAO_AREA`, `DIRECAO_UNIDADE`, `DIRECAO_PEDAGOGICA`) já usados nos outros
   endpoints.
4. **Desconto avulso** — deve exigir uma data de referência ou basta a quantidade de
   dias + observação?
