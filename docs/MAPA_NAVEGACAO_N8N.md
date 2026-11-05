# Mapa de navegação das telas → migração para o n8n

Objetivo: substituir os "botões" (links de navegação entre telas) pelos webhooks do n8n.

## A grande simplificação

Toda a navegação entre telas do portal aponta para **13 nomes de arquivo `.html`** — e só isso.
Não existem centenas de destinos diferentes: os ~275 pontos de navegação sempre caem em um
destes 13 arquivos. Então **migrar = mapear 13 arquivos para 13 URLs de webhook** e trocar as
referências.

Os destinos vêm de 4 mecanismos, todos embutidos (inline) e **iguais em todas as telas**:

1. **Menu lateral roxo (`portal_nav` embutido)** — um `switch(go(...))` idêntico em cada tela:
   `inicio → index.html`, `dash-completo → dashboard_geral_v1.html`,
   `form-docente → FORMULARIO.html`, `form-supervisao → formulario_supervisao.html`,
   `form-du → formulario_du.html`, `form-dp → formulario_dp.html`, `ferias → ferias.html`.
2. **Seletor "Dashboard Individual – Liderado" (`seletor_individual` embutido)** — função `rota(p)`:
   `DOC → dashboard_doc_individual.html`, `SUP/BIL → dashboard_sup_individual.html`,
   `DU → dashboard_du_individual.html`, `DP → dashboard_dp_individual.html`.
3. **`window.location.href = "xxx.html?param=..."`** direto em alguns botões (Avaliar, Voltar).
4. **Botão "Voltar"** — `history.back()` e, no fallback, `index.html`.

> ⚠️ **Cuidado com link relativo no n8n:** quando o n8n serve uma página em
> `.../webhook/portal`, um link relativo `href="ferias.html"` é resolvido pelo navegador como
> `.../webhook/ferias.html` — que **não é um webhook** e dá 404. Por isso todo destino precisa
> virar **URL absoluta do webhook** (ou passar por um resolvedor central — ver a seção final).

---

## Tabela mestre de substituição (13 telas)

| # | Arquivo hoje | Tela (papel) | Webhook sugerido (você define o slug no n8n) |
|---|---|---|---|
| 1 | `index.html` | Portal inicial: login + cards + menu | `/webhook/portal` |
| 2 | `FORMULARIO.html` | Acompanhamento Docente | `/webhook/tela/acompanhamento-docente` |
| 3 | `formulario_supervisao.html` | Avaliação da Supervisão | `/webhook/tela/avaliacao-supervisao` |
| 4 | `formulario_du.html` | Avaliação Direção de Unidade | `/webhook/tela/avaliacao-direcao-unidade` |
| 5 | `formulario_dp.html` | Avaliação Direção Pedagógica | `/webhook/tela/avaliacao-direcao-pedagogica` |
| 6 | `dashboard_geral_v1.html` | Dashboard Geral do Gestor | `/webhook/tela/dashboard-geral` |
| 7 | `dashboard_doc_individual.html` | Dashboard Individual – Docente | `/webhook/tela/dashboard-docente` |
| 8 | `dashboard_sup_individual.html` | Dashboard Individual – Supervisão | `/webhook/tela/dashboard-supervisao` |
| 9 | `dashboard_du_individual.html` | Dashboard Individual – Direção de Unidade | `/webhook/tela/dashboard-unidade` |
| 10 | `dashboard_dp_individual.html` | Dashboard Individual – Direção Pedagógica | `/webhook/tela/dashboard-direcao-pedagogica` |
| 11 | `ferias.html` | Controle de Férias | `/webhook/tela/ferias` |
| 12 | `dashboard_unico_sup.html` | **LEGADO** (162 linhas) — verificar se ainda é usado | *(provável descarte)* |
| 13 | `dashboards.html` | **VAZIO** (0 bytes) — não é tela | *(descartar)* |

Base atual dos webhooks: `https://SEU-N8N/webhook`.

---

## Detalhe por tela: o que sai (botões) e o que entra (parâmetros)

### 1. index.html — Portal inicial
- **Saídas:** menu → todas as telas; cards de gestão/relatórios → formulários (map `URL_FORMULARIOS`);
  cards de dashboard → `dashboard_geral_v1.html?recorte=<...>`; seletor individual → 4 dashboards individuais.
- **Entradas:** `professor_id`/`supervisor_id`/`unidade_id`/`diretor_id` (pré-seleção da barra individual),
  `avaliador_id`, `demo_avaliadores` (flag de DEMO — remover em produção).

### 2. FORMULARIO.html — Acompanhamento Docente
- **Saídas:** menu (switch padrão); botão "abrir individual" → `dashboard_doc_individual.html?professor_id=<id>&professor=<nome>` (L5125).
- **Entradas:** parâmetros do docente selecionado (confirmar na auditoria completa).

### 3. formulario_supervisao.html — Avaliação da Supervisão
- **Saídas:** menu; → `dashboard_sup_individual.html?supervisor_id=<id>&supervisor=<nome>` (L4405).

### 4. formulario_du.html — Avaliação Direção de Unidade
- **Saídas:** menu; → `dashboard_du_individual.html?unidade_id=<id>&diretor=<nome>` (L4374).

### 5. formulario_dp.html — Avaliação Direção Pedagógica
- **Saídas:** menu; → `dashboard_dp_individual.html?diretor_id=<id>&diretor=<nome>` (L4388).

### 6. dashboard_geral_v1.html — Dashboard Geral
- **Saídas:** menu; seletor individual → 4 dashboards individuais; Voltar → `history.back()`/`index.html` (L2366).
- **Entradas:** `recorte`, `avaliador_id`, `demo_avaliadores`, ids da barra individual.

### 7–10. dashboard_{doc,sup,du,dp}_individual.html — Dashboards individuais
- **Saídas:** menu; Voltar → `index.html` (L~1093). Só o **docente** tem botão "Avaliar" → `FORMULARIO.html` (L1190).
- **Entradas:**
  - docente: `professor_id`, `professor`, `cargo`
  - supervisão: `supervisor_id`, `supervisor`, `cargo`
  - unidade: `unidade_id`, `diretor`, `cargo`
  - direção pedagógica: `diretor_id`, `diretor`, `cargo`

### 11. ferias.html — Controle de Férias
- **Saídas:** menu; Voltar → `history.back()`/`index.html` (L1737).
- **Entradas:** `demo` (pré-visualização sem backend).

### 12. dashboard_unico_sup.html — LEGADO
- **Saídas:** → `dashboard_sup_individual.html?<q>` (L130); `index.html` (L107/111).
- **Ação recomendada:** confirmar se algum link ainda aponta para cá; se não, **não migrar**.

---

## Recomendação de implementação (evita ~275 edições manuais)

Em vez de trocar cada botão à mão em cada arquivo, adicione **um único bloco** no topo do
`<script>` de cada tela e faça toda navegação passar por ele:

```js
/* ---- MAPA DE TELAS (n8n) — editar só aqui ---- */
const BASE_TELAS = "https://SEU-N8N/webhook";
const TELAS = {
  "index.html":                    BASE_TELAS + "/portal",
  "FORMULARIO.html":               BASE_TELAS + "/tela/acompanhamento-docente",
  "formulario_supervisao.html":    BASE_TELAS + "/tela/avaliacao-supervisao",
  "formulario_du.html":            BASE_TELAS + "/tela/avaliacao-direcao-unidade",
  "formulario_dp.html":            BASE_TELAS + "/tela/avaliacao-direcao-pedagogica",
  "dashboard_geral_v1.html":       BASE_TELAS + "/tela/dashboard-geral",
  "dashboard_doc_individual.html": BASE_TELAS + "/tela/dashboard-docente",
  "dashboard_sup_individual.html": BASE_TELAS + "/tela/dashboard-supervisao",
  "dashboard_du_individual.html":  BASE_TELAS + "/tela/dashboard-unidade",
  "dashboard_dp_individual.html":  BASE_TELAS + "/tela/dashboard-direcao-pedagogica",
  "ferias.html":                   BASE_TELAS + "/tela/ferias"
};
// resolve "arquivo.html?a=1&b=2" -> "https://.../webhook/slug?a=1&b=2"
function rotaTela(dest){
  const i = dest.indexOf("?");
  const arq = i === -1 ? dest : dest.slice(0, i);
  const qs  = i === -1 ? ""   : dest.slice(i);
  return (TELAS[arq] || dest) + qs;
}
```

Depois, a migração de cada tela vira: (a) fazer `go(x)` chamar `location.href = rotaTela(x)`,
e (b) trocar os poucos `window.location.href = "xxx.html?..."` diretos por
`window.location.href = rotaTela("xxx.html?...")`. Assim, quando você criar/renomear um webhook
no n8n, muda **um mapa** e não caça botão por botão.
