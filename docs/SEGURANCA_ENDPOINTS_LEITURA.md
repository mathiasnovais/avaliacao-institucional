# Mapa de segurança — endpoints de leitura/listagem dos formulários

**Objetivo:** garantir, **no servidor (n8n)**, que cada avaliador só receba a avaliação que **ele mesmo** fez.
Hoje o frontend confia no que o webhook devolve — se o webhook devolver a avaliação de outro avaliador, o dado vaza (ex.: **Coordenação de Área** vendo a avaliação que a **Supervisão de Segmento** fez do mesmo professor).

> **Regra de ouro (vale para TODOS os endpoints abaixo):**
> Derivar o avaliador **do token de sessão**, nunca confiar no `avaliador_id` que vem no corpo (principalmente quando vem `null`).
> - `buscar-avaliacao` → validar que o `avaliacao_id` pedido pertence ao avaliador logado (ou que o cargo dele tem direito explícito de ver). Senão, recusar (403 / vazio).
> - `analise-individual` → `avaliador_id: null` deve resolver para **a identidade da sessão**, jamais devolver a avaliação de outro avaliador.
> - `salvar-avaliacao` → validar que o `avaliacao_id` alterado pertence ao avaliador logado.
> - **Toda** resposta de leitura deve incluir `avaliador_email` e `avaliador_nome` (a trava do frontend usa isso como defesa extra).

Base: `https://SEU-N8N/webhook`

---

## 1) Formulário Docente — `FORMULARIO.html`
Avaliadores concorrentes: **Coordenação de Área** e **Supervisão de Segmento/Bilinguismo** (ambos avaliam o mesmo professor → **não podem** ver a avaliação um do outro).

| Uso | Método/rota | Payload enviado | O que o servidor PRECISA garantir |
|---|---|---|---|
| Listagem | `POST /acompanhamento-docente/listar-docentes` | `{ tipo_codigo:"ACOMPANHAMENTO_DOCENTE", filtros:{} }` | Status e `ultima_avaliacao_id` **por avaliador logado** — nunca expor o id da avaliação de outro avaliador. |
| Leitura principal | `POST /acompanhamento-docente/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id: <ultima_avaliacao_id> }` | Conferir que o `avaliacao_id` é **do avaliador logado**. Se for de outro → recusar. |
| **Leitura fallback ⚠️** | `POST /dashboard-docente/analise-individual` | `{ professor_id, avaliador_id: null }` | **`avaliador_id` vai `null`** → resolver pela sessão; devolver só a avaliação do próprio solicitante. |
| Salvar | `POST /webhook/SEU-WEBHOOK-SALVAR-ACOMPANHAMENTO-DOCENTE` | payload completo com `avaliacao_id` | Só criar/atualizar o registro **do próprio avaliador**; bloquear alterar `avaliacao_id` de outro. |

---

## 2) Formulário Supervisão — `formulario_supervisao.html`
Avaliador: **Direção de Unidade** (e DP de Bilinguismo). Vários diretores/admin não podem ver a avaliação um do outro.

| Uso | Método/rota | Payload enviado | O que o servidor PRECISA garantir |
|---|---|---|---|
| Listagem | `POST /acompanhamento-supervisao/listar-supervisores` | `{ tipo_codigo:"ACOMPANHAMENTO_SUPERVISAO" }` | Escopar por avaliador logado. |
| Leitura principal | `POST /acompanhamento-supervisao/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id }` | Conferir posse/autorização do `avaliacao_id`. |
| **Leitura fallback ⚠️** | `POST /dashboard-supervisao/analise-individual` | `{ supervisor_id, avaliador_id: null }` | **`avaliador_id` `null`** → resolver pela sessão. |
| Agendar devolutiva | `POST /acompanhamento-supervisao/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id }` | Mesma regra da leitura (usado p/ travar agendamento de terceiros). |
| Salvar / agendar | `POST /acompanhamento-supervisao/salvar-avaliacao` | payload / `{apenas_devolutiva,...}` | Validar posse do `avaliacao_id`. |

---

## 3) Formulário Direção de Unidade — `formulario_du.html`
Avaliador: **Direção Pedagógica / DP Geral**.

| Uso | Método/rota | Payload enviado | O que o servidor PRECISA garantir |
|---|---|---|---|
| Listagem | `POST /acompanhamento-direcao/listar-unidades` | `{ tipo_codigo:"ACOMPANHAMENTO_DIRECAO_UNIDADE" }` | Escopar por avaliador logado. |
| Leitura principal | `POST /acompanhamento-direcao/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id }` | Conferir posse/autorização do `avaliacao_id`. |
| **Leitura fallback ⚠️** | `POST /dashboard-direcao/analise-individual` | `{ unidade_id, avaliador_id: null }` | **`avaliador_id` `null`** → resolver pela sessão. |
| Agendar devolutiva | `POST /acompanhamento-direcao/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id }` | Mesma regra da leitura. |
| Salvar / agendar | `POST /acompanhamento-direcao/salvar-avaliacao` | payload / `{apenas_devolutiva,...}` | Validar posse do `avaliacao_id`. |

---

## 4) Formulário Direção Pedagógica — `formulario_dp.html`
Avaliador: **DP Geral / Admin**.

| Uso | Método/rota | Payload enviado | O que o servidor PRECISA garantir |
|---|---|---|---|
| Listagem | `POST /acompanhamento-direcao-pedagogica/listar-diretores` | `{ tipo_codigo:"ACOMPANHAMENTO_DIRECAO_PEDAGOGICA" }` | Escopar por avaliador logado. |
| Leitura principal | `POST /acompanhamento-direcao-pedagogica/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id }` | Conferir posse/autorização do `avaliacao_id`. |
| **Leitura fallback ⚠️** | `POST /dashboard-direcao-pedagogica/analise-individual` | `{ diretor_id, avaliador_id: null }` | **`avaliador_id` `null`** → resolver pela sessão. |
| Agendar devolutiva | `POST /acompanhamento-direcao-pedagogica/buscar-avaliacao` | `{ tipo_codigo, avaliacao_id }` | Mesma regra da leitura. |
| Salvar / agendar | `POST /acompanhamento-direcao-pedagogica/salvar-avaliacao` | payload / `{apenas_devolutiva,...}` | Validar posse do `avaliacao_id`. |

---

## 5) Seletor "Dashboard Individual - Liderado" (embutido em TODOS os formulários)
O menu lateral, ao abrir o dashboard individual, chama **as 4 listagens em paralelo**:

- `POST /acompanhamento-docente/listar-docentes`
- `POST /acompanhamento-supervisao/listar-supervisores`
- `POST /acompanhamento-direcao/listar-unidades`
- `POST /acompanhamento-direcao-pedagogica/listar-diretores`

> Cada uma deve devolver **apenas as pessoas do recorte do usuário logado**. E o filtro **"Avaliado por"** dos dashboards (`setAvaliadores`) só pode listar avaliadores que o viewer tem direito de ver — a cascata é responsabilidade do servidor.

---

## Resumo dos pontos críticos (prioridade)
1. **Todos os `analise-individual`** enviam `avaliador_id: null` → hoje o servidor decide sozinho qual avaliação devolver. **É o furo principal.** Deve travar na sessão.
2. **Todos os `buscar-avaliacao`** recebem um `avaliacao_id` vindo do cliente → validar posse/autorização antes de devolver.
3. **Listagens** devem trazer status e `avaliacao_id` **por avaliador logado**.
4. **Salvar** deve recusar gravar sobre `avaliacao_id` de outro avaliador.
5. Incluir `avaliador_email` / `avaliador_nome` em toda leitura (reforça a trava do frontend).
