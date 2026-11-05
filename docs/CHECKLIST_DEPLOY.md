# Checklist de Deploy — n8n / PostgreSQL

> Marque cada item conforme aplicar. Base do webhook: `https://SEU-N8N/webhook`
> "Republicar SQL" = abrir o workflow → nó **Postgres ("Execute a SQL query")** → colar o conteúdo do arquivo → **Save** → deixar ativo.

---

## 🔴 A) DOCENTE — correções (prioridade)

- [ ] **1. Listar docentes** — nó do webhook `acompanhamento-docente/listar-docentes`
  → colar [n8n_listar_docentes_2tri.sql](n8n_listar_docentes_2tri.sql)
  *(garante que a LISTA volte; esse nó não pode ter o SQL de salvar)*

- [ ] **2. Salvar docente (SQL)** — webhook `SEU-WEBHOOK-SALVAR-ACOMPANHAMENTO-DOCENTE`
  → colar [n8n_salvar_acompanhamento_2tri.sql](n8n_salvar_acompanhamento_2tri.sql)
  *(unidade_id tolerante: aceita nome "Tijuca" e resolve p/ UUID)*

- [ ] **3. Salvar docente (Code node)** — mesmo workflow do item 2, no nó **"Code in JavaScript"** que monta o `sql_payload`
  → dentro do objeto `payload`, adicionar a linha:
  ```js
  apenas_devolutiva: body.apenas_devolutiva === true,
  ```
  *(sem isso, agendar devolutiva ZERA a avaliação)*

- [ ] **4. Análise individual docente** — nó do webhook `dashboard-docente/analise-individual`
  → colar [n8n_dash_doc_individual.sql](n8n_dash_doc_individual.sql)
  *(expõe `avaliacao_id` p/ o botão do dashboard)*

---

## 🟠 B) DIREÇÃO DE UNIDADE (DU)

- [ ] **5. Análise individual DU** — nó do webhook `dashboard-direcao/analise-individual`
  → colar [n8n_dash_du_individual.sql](n8n_dash_du_individual.sql)
  *(expõe `avaliacao_id`)*

- [ ] **6. Salvar DU (Code node)** — workflow do webhook `acompanhamento-direcao/salvar-avaliacao`, nó **"Code in JavaScript"** que monta o `sql_payload`
  → garantir a linha `apenas_devolutiva: body.apenas_devolutiva === true,`
  *(o SQL de salvar [n8n_du_salvar_avaliacao.sql](n8n_du_salvar_avaliacao.sql) JÁ suporta — só o Code node pode faltar)*
  **Teste rápido:** se agendar devolutiva pelo formulário DU já preserva os dados, este item já está OK.

---

## 🟡 C) DIREÇÃO PEDAGÓGICA (DP)

- [ ] **7. Análise individual DP** — nó do webhook `dashboard-direcao-pedagogica/analise-individual`
  → colar [n8n_dash_dp_individual.sql](n8n_dash_dp_individual.sql)

- [ ] **8. Salvar DP (Code node)** — workflow do webhook `acompanhamento-direcao-pedagogica/salvar-avaliacao`
  → garantir `apenas_devolutiva: body.apenas_devolutiva === true,` no Code node
  *(SQL [n8n_dp_salvar_avaliacao.sql](n8n_dp_salvar_avaliacao.sql) já suporta)*

---

## 🟢 D) SUPERVISÃO (SUP)

- [ ] **9. Análise individual SUP** — nó do webhook `dashboard-supervisao/analise-individual`
  → colar [n8n_dash_sup_individual.sql](n8n_dash_sup_individual.sql)

- [ ] **10. Salvar SUP (Code node)** — workflow do webhook `acompanhamento-supervisao/salvar-avaliacao`
  → garantir `apenas_devolutiva: body.apenas_devolutiva === true,` no Code node
  *(SQL [n8n_sup_salvar_avaliacao.sql](n8n_sup_salvar_avaliacao.sql) já suporta)*

---

## 🔵 E) CONTROLE DE FÉRIAS (se for usar as melhorias novas)

- [ ] **11. Schema (PostgreSQL)** — rodar 1x no **editor SQL do PostgreSQL**:
  [n8n_ferias_schema.sql](n8n_ferias_schema.sql)
  *(adiciona `unidade_id`, `segmentos` em colaboradores e `tipo` em lançamentos — idempotente)*

- [ ] **12. Ferias listar** — nó do webhook `ferias/listar`
  → colar [n8n_ferias_listar.sql](n8n_ferias_listar.sql)

- [ ] **13. Ferias salvar colaborador** — nó do webhook `ferias/colaborador/salvar`
  → colar [n8n_ferias_salvar_colaborador.sql](n8n_ferias_salvar_colaborador.sql)

- [ ] **14. Ferias salvar lançamento** — nó do webhook `ferias/lancamento/salvar`
  → colar [n8n_ferias_salvar_lancamento.sql](n8n_ferias_salvar_lancamento.sql)

*(Os nós de ferias `excluir` x2 e `importar-gestores` NÃO mudaram.)*

---

## Frontend (HTML) — já está pronto no seu projeto
Não precisa "deploar" nada além de servir os arquivos atualizados. Foram alterados:
`ferias.html`, `FORMULARIO.html`, `dashboard_doc_individual.html`,
`dashboard_du_individual.html`, `dashboard_dp_individual.html`, `dashboard_sup_individual.html`,
`formulario_du.html`, `formulario_dp.html`.
*(Dê Ctrl+F5 pra pegar a versão nova.)*

---

## Como saber se cada papel está 100%
Preencher avaliação → Concluir → cai no dashboard individual → **Agendar devolutiva** → escolher data → volta pra lista.
Prova no banco (não pode zerar):
```sql
select professor_id, status,
       identificacao->>'data_devolutiva' as data_devolutiva,
       jsonb_array_length(coalesce(respostas,'[]'::jsonb)) as qtd_respostas
from acompanhamento_respostas
where tipo_codigo in ('ACOMPANHAMENTO_DOCENTE','ACOMPANHAMENTO_DIRECAO_UNIDADE',
                      'ACOMPANHAMENTO_DIRECAO_PEDAGOGICA','ACOMPANHAMENTO_SUPERVISAO')
order by atualizado_em desc limit 5;
```
`qtd_respostas > 0` **e** `data_devolutiva` preenchida = funcionando. ✅
