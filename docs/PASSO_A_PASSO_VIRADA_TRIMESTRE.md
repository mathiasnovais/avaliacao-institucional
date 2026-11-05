# Passo a passo da virada de trimestre

Virada para o 3º tri/2026 feita em 07/10/2026 (janela 07/10 → 23/11). O que compõe uma virada de trimestre:

1. **Banco**: `config_trimestre.sql` → `update app_config set valor='3º Trimestre · 2026' where chave='trimestre_atual'`. Já zerava sozinho só o form docente (listar-docentes lê a config) e o painel da rede.
2. **Filtro de RODADA nos SQLs** (adicionado em 07/10): `n8n_sup_listar_supervisores.sql` (raiz), `n8n/n8n_dp_listar_diretores.sql`, `n8n/n8n_du_listar_unidades.sql`, `n8n/n8n_coord_listar_coordenadores.sql` e os 4 laterais do `n8n/n8n_dash_meus_liderados.sql` só contam avaliação cujo `coalesce(identificacao->>'periodo_referencia', identificacao->>'trimestre')` = `trimestre_atual` da config (config nula = sem filtro). Sem isso, a última avaliação do tri anterior continuava aparecendo como "concluído".
3. **Fronts**: janela em [[prazo-do-ciclo-6-arquivos]] (7 arquivos + cycleInfo do dashboard geral) + fallbacks `PERIODO_ATUAL`/`PERIODO_SIGLA` do dashboard_individual.
4. **Mural**: release nova em `publica/assets/releases.js` (fonte única) + ilustrações no `IMGS` do index.html (chaves tri3/painel/pessoas/termo/extras criadas em 07/10).

**Why:** a "rodada" não é uma entidade no banco — é a conjunção config + chave de período gravada no identificacao + filtros. Esquecer um dos 3 pontos dá telas dizendo coisas diferentes (form pendente × dashboard concluído).

**How to apply:** na próxima virada, trocar config + 7 fronts (datas/rótulos, grep `new Date(2026,` e a data por extenso) + release do mural; os filtros de rodada dos SQLs viram sozinhos com a config. Deploy: colar os SQLs nos nós do n8n, rodar o update no Supabase e `node gerar_publica.js` + wrangler ([[publica-cloudflare-deploy]]). Os dash individuais (atual × anterior por recência) seguem SEM filtro de config — mostram a última avaliação existente até sair a nova.
