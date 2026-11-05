# Auditoria das telas do Portal Alfa CEM

Este relatório consolida a auditoria de **12 telas** do Portal Alfa CEM, resultando em **64 vulnerabilidades após verificação**, **2191 comentários no total** e **90 apontamentos de código morto**. As telas auditadas concentram-se no fluxo de avaliação pedagógica (index/login, formulários de acompanhamento docente/supervisão/direção de unidade/direção pedagógica, dashboards geral e individuais, controle de férias e um dashboard de supervisão legado), todas servidas via webhooks do n8n. O padrão de vulnerabilidade dominante é XSS via `innerHTML` com dados de API sem escape, agravado pelo armazenamento do `session_token` em `sessionStorage` (exfiltrável por qualquer XSS). Além das falhas de segurança, o relatório aponta forte duplicação de CSS/JS inline entre telas, data-URIs base64 gigantes (mandala e logos) replicados byte-a-byte e dados mock/demo embutidos que deveriam sair de produção.

## Sumario por severidade

| Severidade | Quantidade |
|---|---|
| CRÍTICA | 0 |
| ALTA | 20 |
| MÉDIA | 22 |
| BAIXA | 22 |
| **Total** | **64** |

## Vulnerabilidades (detalhado)

### index.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS refletido/armazenado via innerHTML (dado de API sem escape) | 2613 | `buscarRecorte()` monta pessoas com `p.nome`/`p.area`/`p.u` das APIs apenas via `norm()` (trim), sem escape; `rowHTML()` injeta em `lst.innerHTML`. Um nome/unidade com `<img src=x onerror=...>` executa no contexto logado, com `session_token` em sessionStorage. Mesmo fluxo em `montarBarraIndividual` (L2746). | Aplicar `imEsc()`/`textContent` em `p.nome`, `p.area`, `p.u` e no cargo antes de concatenar, ou usar `createElement + textContent`. |
| ALTA (verificada) | XSS via innerHTML com URL de foto da API | 1788 | `applyProfile()` usa `user.foto_url/foto/avatar/photo` de `validate_code` e injeta em `innerHTML` sem escapar aspas. Valor como `"><img src=x onerror=...>` quebra o atributo e injeta markup logo após o login. | Criar `<img>` via `document.createElement` e setar `img.src`, validando prefixo `https://` ou `data:image/`. Não usar innerHTML. |
| MEDIA (a confirmar) | Token de sessão (Bearer) em sessionStorage acessível a JS | 2227 | `session_token` persistido em sessionStorage e enviado como Bearer (L2227, L2528); legível por qualquer script, então qualquer XSS exfiltra o token. Combinado com as XSS ALTAs, impacto é sequestro de sessão. | Mover a sessão para cookie HttpOnly+Secure+SameSite; enquanto isso, eliminar os sinks de innerHTML com dado de API. |
| BAIXA (a confirmar) | Reflexão de query param sem sanitização (open-redirect-like) | 2793 | `setAvaliadores` usa o `id` do `<option>` (dados de API) para montar URL. Sem XSS direto (searchParams codifica), mas valor não validado. | Validar/normalizar `id` (esperar UUID/número) antes de setar em searchParams. |
| BAIXA (a confirmar) | Segredo/endpoint hardcoded (base de webhook exposta) | 1474 | Endpoints do n8n hardcoded no front. Sem token/segredo estático; risco baixo (URLs públicas por natureza). Expõe apenas a topologia de rotas. | Manter, mas garantir no n8n: rate-limiting em request_code, validação de Bearer server-side e CORS restrito. |

### FORMULARIO.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS armazenado/refletido via innerHTML (dados de API sem escape) | 5752 | Em `rowHTML()` (modal 'Dashboard Individual - Liderado'), `p.nome`/`p.area`/`p.u` vêm de `buscarRecorte()` sem escape e são injetados via `lst.innerHTML` (L5762). A lista principal (`renderizarListaDocentes`) usa textContent e é segura; este módulo inline é a exceção. | Aplicar `imEsc()` (L5814) antes de concatenar, ou construir nós com `createElement/textContent`. |
| MEDIA (a confirmar) | Token de sessão em sessionStorage + Bearer manual | 2387 | `session_token` em sessionStorage enviado DUPLICADO: no header Authorization e no corpo JSON. Combinado com o XSS, um payload lê e exfiltra a sessão. Token no body aumenta superfície (logs). | Preferir cookie httpOnly+SameSite; se mantido, corrigir XSS e parar de duplicar o token no body. |
| MEDIA (a confirmar) | UUID de webhook exposto / endpoints sem token | 2176 | `API_TURMAS` e `API_SALVAR` identificados por UUID hardcoded. Turmas é GET SEM Authorization; qualquer um com a URL enumera turmas/alocações via query params. | Exigir token no endpoint de turmas; mover UUIDs para rotas com autorização; não confiar em 'URL secreta'. |
| BAIXA (a confirmar) | window.open('_blank') sem noopener/noreferrer | 3089 | Abre Google Calendar via `window.open('_blank')` sem 3º arg; destino recebe `window.opener` (reverse tabnabbing). Destino é google.com (baixo risco). | `window.open(url, '_blank', 'noopener,noreferrer')` ou `win.opener=null`. |
| BAIXA (a confirmar) | Autorização apenas client-side (bypassável) | 2419 | `CARGOS_PERMITIDOS` lido de `sessionStorage.permissoes` e checado no front; usuário pode editar sessionStorage. Risco real depende de o n8n revalidar cada webhook. | Garantir que todo webhook revalide cargo e recorte no servidor a partir do token, ignorando dados do cliente. |

### formulario_supervisao.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS via innerHTML (dados de API sem escape) | 4817 | `rowHTML()` concatena `p.nome`/`p.area`/`p.u` (de 4 APIs de listagem) em `lst.innerHTML` (L4827) sem escape. Payload executa ao abrir 'Dashboard Individual - Liderado', com `session_token` em sessionStorage. | Escapar campos com `imEsc()` (L4879) ou construir nós com `createElement + textContent` como em `criarCardSupervisor()`. |
| ALTA (verificada) | XSS via innerHTML em `<option>` (dados de API sem escape) | 4950 | `montarBarraIndividual()` monta o `<select>` com `p.nome`/`p.area`/`p.u` crus em `personSel.innerHTML` (L4953). O texto é relido por `imCselRefresh/imCselOpt`, mas o caminho do option text não passa por `imEsc`. | Aplicar `imEsc()` na montagem do `<option>` ou usar `new Option(text,value)`. |
| ALTA (verificada) | XSS via innerHTML em `<option>` (lista de avaliadores da API) | 4987 | `setAvaliadores()` escreve `sel.innerHTML` (L4982) com `nome`/`cargo` apenas normalizados por `norm()`. Um `avaliador_nome` com tags injeta HTML no menu individual. | Escapar `nome` e `cargo` com `imEsc` antes de interpolar, ou usar `new Option()`. |
| MEDIA (a confirmar) | XSS via innerHTML (usuário.foto_url do sessionStorage/API) | 3807 | `renderizarHeader()` insere `usuario.foto_url/foto` em innerHTML sem escapar aspas. `"><img src=x onerror=...>` quebra o atributo `src`. Depende de foto_url controlável. | Criar `<img>` via `createElement` e atribuir `img.src`, ou validar URL http(s). |
| MEDIA (a confirmar) | Token de sessão em sessionStorage transmitido em Bearer e no corpo | 3008 | `session_token` em sessionStorage enviado no header e DUPLICADO no corpo JSON em `apiPost`, `carregarAvaliacaoSalva` (L3729), `buscarRecorte` (L4733). Combinado com XSS, roubo do token. | Manter o token apenas no header; considerar cookie HttpOnly. |
| BAIXA (a confirmar) | window.open target _blank sem noopener | 3539 | Abre Google Calendar via `window.open` sem 'noopener'; destino ganha `window.opener` (reverse tabnabbing). Destino fixo (baixo risco). | `window.open(url,'_blank','noopener')` ou `win.opener=null`. |
| BAIXA (a confirmar) | XSS refletido teórico via nome montado em innerHTML de datepicker/agenda | 3526 | `elSel.innerHTML='Devolutiva em <b>'+_fmtDataBR(selecionada)+'</b>'`; `selecionada` vem de dataset.d ISO (regex-validado). Não injetável hoje; padrão frágil. `nomeAlvo` usa textContent (seguro). | Preferir `textContent` + `<b>` via createElement; manter validação estrita da data. |

### formulario_du.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS via innerHTML (dados de API sem escape) | 4792 | `rowHTML()` concatena `p.nome`/`p.area`/`p.u` (crus das 4 APIs) via `paint()->selList.innerHTML` (L4802). `imEsc()` existe mas não é aplicado. Alcançável via `<a data-acao="dash-individual">` (L1957). Stored-XSS via dado de RH. | Aplicar `imEsc()` a `p.nome`, `p.area`, `p.u`, `c.sh`, `p.ini`, ou usar `createElement + textContent` como em `criarCardDiretor`. |
| MEDIA (a confirmar) | XSS por injeção de atributo (innerHTML de `<img src>`) | 3692 | `renderizarHeader()` insere `usuario.foto_url/foto` sem escapar aspas. `" onerror=alert(1) x="` injeta handler. Depende de o backend aceitar foto_url arbitrária. | Criar `<img>` via `createElement` e setar `img.src`, ou validar prefixo `https://` e escapar aspas. |
| MEDIA (a confirmar) | Token de sessão em sessionStorage transmitido no corpo/header | 2903 | `session_token` em sessionStorage enviado no header e duplicado no corpo JSON. Combinado com os XSS confirmados, roubo de sessão concreto. | Enviar token apenas no header; considerar cookie HttpOnly. |
| BAIXA (a confirmar) | target=_blank / window.open sem noopener | 3546 | Abre calendar.google.com sem 'noopener'; URL montada com encodeURIComponent (baixo risco), mas a aba ganha `window.opener`. | `window.open(url, '_blank', 'noopener,noreferrer')`. |
| BAIXA (a confirmar) | UUID/segredo — avaliação do risco | 2852 | Sem tokens/UUIDs opacos/credenciais hardcoded — apenas caminhos nomeados de webhook e URL de login. Endpoints públicos por natureza; gating de cargo é só client-side e contornável. | Nenhuma correção no front além de confirmar validação de permissão no n8n; não tratar gating client-side como controle de segurança. |

### dashboard_geral_v1.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS armazenado/refletido via innerHTML com dados da API (nome, unidade, área) | 2160 | `renderRoster` concatena `p.nome`/`p.u`/`p.area`/`p.ini` dos webhooks (via `norm()` = trim) em `tbl.innerHTML` (L2165). Padrão repetido em `openIndividualList` (1645), `personDetail`, `heatmap`, `evolucao`, `feedbacks` (2495-2549), `seletor_individual` (3042/3175). Executa no dashboard do gestor com `session_token`. | Reaproveitar `imEsc`/`esc` e aplicar em TODO dado textual de API (`p.nome`, `p.u`, `p.area`, `p.ini`, disciplina, cargo_rotulo). Preferir textContent/createElement. |
| MEDIA (a confirmar) | DOM-based self-XSS via query/search refletido em innerHTML | 2167 | `state.busca` recebe valor bruto de `#fBusca` (L2362) e é reinjetado sem escape em `#rosterCount.innerHTML`. Digitar `<img src=x onerror=...>` executa. Self-XSS, mas explorável via engenharia social/colagem. | Escapar `state.busca` (usar textContent para a parte variável ou `esc(state.busca)`). |
| MEDIA (a confirmar) | Token de sessão em sessionStorage transmitido como Bearer e DUPLICADO no corpo | 2958 | `session_token` lido de sessionStorage e enviado no header (ok) MAS também no JSON body (L2958). Duplicar aumenta vazamento (logs, workflows salvos, proxies). Combinado com XSS, exfiltrável. | Enviar token só no header; avaliar cookie httpOnly; garantir que o n8n não logue o Authorization. |
| BAIXA (a confirmar) | Interceptador de fetch faz resp.clone().text() de TODAS as respostas | 78 | `sessao_guard` sobrescreve `fetch` e clona+lê o corpo de toda resposta para checar `sessao_valida:false`. Processa payloads grandes em memória; amplia processamento de dados sensíveis. Baixo risco direto. | Limitar o parse a endpoints conhecidos (checar URL) ou só quando content-type for JSON e tamanho pequeno; evitar clonar streaming/download. |
| BAIXA (a confirmar) | Endpoints de webhook n8n expostos no cliente | 2708 | Caminhos dos webhooks hardcoded e visíveis. São rotas nomeadas (não UUIDs), risco menor. Proteção real depende de o n8n validar o Bearer server-side. | Garantir no n8n que todos os nós exijam/validem `session_token` e apliquem a matriz de visibilidade server-side; considerar rate-limit. |

### dashboard_doc_individual.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS armazenado via innerHTML (dados da API sem escape) | 1904 | `i.o` vem de `BANCO.respostas[].observacao` (texto livre de avaliadores) e é injetado em `el.innerHTML` (L1890/1904) sem escape. Reaparece em `mItem` (1382), quotes (1947), att-item (1976). Executa no navegador de qualquer gestor. | Escapar interpolação com `esc()`/`imEsc()` (ou textContent). Ex.: `${esc(i.o)}` em todos os sinks. |
| ALTA (verificada) | XSS via innerHTML (pontos_positivos / plano_acao / classificação) | 1964 | `p` vem de `BANCO.pontos_positivos` injetado em `d.innerHTML`; plano de ação injeta `r.pt/r.ac/r.resp/r.ind` (`BANCO.plano_acao`) em `apBody.innerHTML` (1999-2001) sem escape. | Aplicar `esc()` em `p`, `r.pt`, `r.ac`, `r.resp`, `r.ind`, `r.ref` e devolutiva, ou construir nós com textContent (como em `aplicarAutoanalise`). |
| ALTA (verificada) | XSS via innerHTML (nomes vindos das 4 APIs de listagem) | 2363 | `p.nome`/`p.area`/`p.u` de `buscarRecorte()` injetados sem escape no `<option>` (L2363), `rowHTML` do modal (2206-2207), card lateral (2520-2523) e tabela de comparação (2402/2414). O dropdown custom usa `imEsc`, mas o `<option>` nativo e demais sinks não. | Reutilizar `imEsc()`/`esc()` para `p.nome`, `p.area`, `p.u`, `a.nome`, `a.cargo`, `b.name` em todos os innerHTML. |
| MEDIA (a confirmar) | UUID de webhook n8n exposto no cliente | 1101 | Endpoint de gravação é webhook n8n por UUID hardcoded, visível no HTML. Sem auth além do Bearer; se o workflow não validar rigidamente, é possível gravar agendamentos arbitrários. | Não confiar na obscuridade: validar `session_token`, permissão do viewer e `avaliacao_id` no n8n. Preferir rota nomeada com auth server-side. |
| MEDIA (a confirmar) | Token de sessão em sessionStorage transmitido em Bearer e no body | 1166 | `session_token` lido de sessionStorage e enviado no header (L1069/1165/2121) e duplicado no body (L1166/2122). Arquivo TEM vários XSS, tornando o roubo plausível. | Corrigir XSS primeiro; enviar token só no header; avaliar cookie HttpOnly+SameSite. |
| BAIXA (a confirmar) | window.open('_blank') sem noopener | 1244 | Abre Google Agenda via `window.open` sem 'noopener'; URL interna confiável (baixo risco), mas a janela recebe `window.opener`. | `window.open(url,'_blank','noopener,noreferrer')`. |
| BAIXA (a confirmar) | Query param refletido no DOM/título | 1467 | `professor` (de location.search) usado como fallback via `textContent` (L1462) e `document.title` — sem injeção HTML. `cargo` também via textContent. Registrado só por ser refletido. | Manter textContent (correto). Opcional: validar tamanho/caracteres de `professor` e `cargo`. |

### dashboard_sup_individual.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS refletido/armazenado via innerHTML (dados da API) | 1906 | `i.o` vem de `BANCO.respostas[].observacao` (texto livre do diretor) injetado em innerHTML sem escape (L1444). Reaparece em 1949 (quoteList), 1978 (attList), 1381 (mItem). | Criar/usar `esc()` (2751/2840) e `${esc(i.o)}`, ou montar nó com textContent. Aplicar em 1381,1906,1949,1978. |
| ALTA (verificada) | XSS via innerHTML (plano de ação da API) | 2002 | `apData` de `BANCO.plano_acao` (`pt/ac/resp/ind/ref`, texto livre) injetado cru na tabela; `r.ref` também cru (L2001). | Escapar cada campo (`esc(r.pt)` etc.) ou preencher células via textContent. |
| ALTA (verificada) | XSS via innerHTML (nome do liderado da API) | 2208 | No modal do seletor, `p.nome` (de `buscarRecorte`) concatenado cru em `selBody.innerHTML`. `imEsc()` (L2276) existe mas não é usado. Padrão cru em 2365/2404/2498/2522/2588. | Usar `imEsc(p.nome)`/`esc()` em todos esses pontos antes de interpolar. |
| ALTA (verificada) | XSS via innerHTML (ranking da rede da API) | 1783 | `roster`=`BANCO.ranking`; `r.n` injetado cru no atributo `title` (L1751) e no corpo da célula (1783). Nome com aspas/HTML quebra atributo ou injeta markup. | Escapar `r.n` com `esc()` nos dois pontos; para o title, escapar aspas duplas. |
| MEDIA (a confirmar) | Token de sessão em sessionStorage transmitido como Bearer | 1069 | `session_token` em sessionStorage (17,1066,1164,2170,2350) vai no header; qualquer XSS exfiltra. Em `_apiPostSalvar` (1168) e `buscarRecorte` (2124) também vai no corpo JSON. | Corrigir XSS primeiro; preferir cookie HttpOnly+SameSite; não duplicar o token no body. |
| BAIXA (a confirmar) | window.open target=_blank sem noopener | 1244 | Abre Google Agenda via `window.open` sem 'noopener'; URL interna (baixo risco), mas nova aba recebe `window.opener`. | `window.open(url,'_blank','noopener,noreferrer')` ou `win.opener=null`. |
| BAIXA (a confirmar) | UUID de webhook n8n exposto no cliente | 1061 | Rotas de webhook hardcoded (1061,1101,2056,2134-2137). São paths nomeados que exigem Bearer; exposição esperada numa SPA. Risco depende de validação server-side. | Nenhuma ação obrigatória além de garantir que o n8n valide sessão e escopo; não confiar em ocultação de URL. |

### dashboard_du_individual.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS armazenado via innerHTML (observação do gestor) | 1987 | `i.o` de `BANCO.respostas[].observacao` (texto livre do DP) mapeado em `it.o` (L1528) sem escape, injetado em `blk-body innerHTML`. Mesmo sink em 1465 (modal), 2030 (quotes), 2059 (att-item). Token em sessionStorage exfiltrável. | Usar `esc()` (2921/2832): `${esc(i.o)}`, ou textContent/createElement como em 1632. |
| ALTA (verificada) | XSS via innerHTML (ranking / nomes da rede) | 1864 | `r.n` de `BANCO.ranking[].n` (1816-1818) sem sanitização, interpolado em innerHTML da tabela e do gráfico de barras (1832) e no `title`. Propagação ampla (ranking compartilhado). | Escapar `r.n`/`r.uni`/`r.seg` com `esc()`; usar textContent para o atributo title. |
| ALTA (verificada) | XSS via innerHTML (plano de ação / pontos positivos) | 2083 | `r.pt/r.ac/r.resp/r.ind` de `BANCO.plano_acao` (2074-2077) e `BANCO.pontos_positivos` (L2047) injetados em innerHTML sem escape. | Aplicar `esc()` em cada campo (`r.pt`, `r.ac`, `r.resp`, `r.ind`, `p`) antes de interpolar. |
| MEDIA (a confirmar) | XSS via innerHTML (lista de avaliadores) | 2668 | `nome`/`cargo` de `window._AVALIADORES` (via `norm()`, sem escape) e `id` no atributo `data-aval` concatenados em `menu.innerHTML` (2678). `imEsc()` (L2355) existe mas não é usado aqui. | Usar `imEsc()` para `nome`, `cargo` e `id`. |
| MEDIA (a confirmar) | Token de sessão (Bearer) em sessionStorage enviado a múltiplos endpoints | 1070 | `session_token` lido de sessionStorage (1067,1165,2251,2431) e enviado como Bearer; qualquer XSS o lê. Em `_apiPostSalvar` (1169) duplicado no body. | Reduzir superfície de XSS; considerar cookie httpOnly; não duplicar token no body. |
| BAIXA (a confirmar) | target/_blank sem rel=noopener | 1245 | Abre Google Calendar via `window.open('_blank')` sem 'noopener'; URL interna fixa (risco mínimo), mas destino recebe `window.opener`. | `window.open(url,'_blank','noopener')` ou `w.opener=null`. |
| BAIXA (a confirmar) | UUID de webhook n8n exposto no cliente | 1062 | Endpoints n8n hardcoded (1062,1102,2137,15). Rotas nomeadas; controle depende do Bearer e do sessao_guard. `unidade_id` vem de query param manipulável. | Manter validação de autorização no n8n (já checa `dd.autorizado===false`); confirmar que o backend não confia só no `unidade_id` do cliente. |

### dashboard_dp_individual.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| MEDIA (verificada) | XSS via innerHTML com dados não escapados (nome do liderado) | 2224 | `rowHTML()` concatena `p.nome`/`p.u`/`p.area` das APIs (via `norm()`) sem escape em `lst.innerHTML` (L2234). `imEsc()` existe mas não é usado aqui. Stored XSS gated (exige dado persistido). | Escapar `p.nome`, `p.u`, `p.area` com `imEsc/esc`, ou construir nós via textContent. |
| MEDIA (verificada) | XSS via innerHTML no dropdown de pessoas (barra individual) | 2381 | `montarBarraIndividual` monta o `<select>` com `p.nome`/`p.area`/`p.u` sem escape em `personSel.innerHTML` (2379-2384). Nome com aspas ou `</option>...<img onerror>` quebra a estrutura. | Escapar `p.nome`/`p.area`/`p.u`; `esc/imEsc` já existe. |
| MEDIA (a confirmar) | XSS via innerHTML com observações/textos do banco | 1922 | Render de blocos (1908-1923), quotes (1965), atenção (1994) e `mItem` (1400) injetam `i.o`/`i.c`/`i.ev` de `BANCO.respostas[].observacao` em innerHTML. Fonte é usuário interno autenticado. | Escapar `i.o`/`i.c`/`i.ev` antes de interpolar, ou usar textContent. Centralizar num helper `esc()`. |
| MEDIA (a confirmar) | XSS via innerHTML em campos de devolutiva do banco | 2432 | `abrirComparacao` usa `a.nome` (nome do avaliador da API) em `th` (L2420) sem escape: `th+='...'+n+'...'`. Nome comprometido injeta HTML no modal 'Todos juntos'. | Escapar nomes de avaliador (`a.nome`/cargos) antes de concatenar no th/rows. |
| MEDIA (a confirmar) | Token de sessão em sessionStorage enviado como Bearer | 1066 | `session_token` em sessionStorage acessível a qualquer JS; combinado com os múltiplos innerHTML, XSS exfiltra o Bearer. Token também reenviado no body (L1168). | Preferir cookie httpOnly+SameSite; eliminar sinks de innerHTML não escapados; não duplicar o token no corpo. |
| BAIXA (a confirmar) | window.open target _blank sem noopener | 1244 | Abre Google Calendar sem 'noopener'; a página aberta acessa `window.opener`. URL fixa (risco baixo). | `window.open(url,'_blank','noopener')`. |
| BAIXA (a confirmar) | UUIDs de webhook expostos no cliente | 1061 | Todos os endpoints n8n hardcoded (analise-individual, salvar-avaliacao, 4 de listagem em 2150-2153, LOGIN_URL). Paths de webhook, não segredos; risco baixo. Expõe superfície a enumeração. | Aceitável se o backend valida o Bearer/sessão em todos; garantir rate-limit e authz server-side. Opcional: gateway com paths opacos. |

### ferias.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| MEDIA (a confirmar) | Exposição de token em sessionStorage transmitido no corpo E no header | 852 | `postJSON` (852-863) e `postRaw` (1498-1510) enviam o `session_token` DUAS vezes: no header Bearer e no body JSON. Duplicar no corpo aumenta vazamento (logs do n8n, proxies). | Enviar o token APENAS no header; remover o campo `token` do body em `postJSON` e `postRaw`. |
| BAIXA (a confirmar) | OTP/login-validacao chamado sem Authorization e email do admin no corpo | 1398 | `callLogin` dispara request_code/validate_code sem token de sessão, com e-mail lido do client. Um usuário pode disparar OTP para e-mails arbitrários (spam/enumeração). Exclusão só ocorre após validar o código. | No n8n, exigir e validar o `session_token` no login-validacao para request_code de exclusão; confirmar server-side que o e-mail pertence ao usuário; rate-limit. |
| BAIXA (a confirmar) | URL de foto de perfil injetada em innerHTML sem validação de esquema | 1724 | `av.innerHTML = '<img src="'+escapeHtml(foto)+'" alt="">'`; `escapeHtml` escapa aspas (sem XSS de script). Risco é carregamento de recurso externo arbitrário (SSRF de imagem/beacon). | Criar `<img>` via `createElement` e atribuir `img.src` validando prefixo `https://` ou `data:image/`; evitar innerHTML. |
| BAIXA (a confirmar) | Confiança total em flags de autorização vindas do cliente (permissoes) | 749 | `ehAdmin()` e `PODE_EDITAR` derivam de `sessionStorage.permissoes` (editável no DevTools). Libera botões de editar/excluir e edição local. Se algum `/ferias/*` confiar só no token sem re-checar admin, um não-admin muta dados. | Garantir que TODOS os endpoints `/ferias/colaborador/salvar|excluir` e `/ferias/lancamento/*` revalidem `admin_global`/`pode_editar` server-side, ignorando flags do cliente. |
| BAIXA (a confirmar) | Guard de sessão inline faz JSON.parse de resposta clonada de TODA requisição fetch | 79 | `sessao_guard` sobrescreve `fetch` e faz `clone().text()+JSON.parse` de toda resposta. Não é XSS, mas: qualquer resposta com `sessao_valida:false` (inclusive terceiros/CDN) dispara o overlay; e há custo de clonar/ler todo corpo. | Restringir a checagem às respostas do próprio `API_BASE_URL` (verificar `resp.url`) antes de clonar/parsear. |

### dashboard_unico_sup.html

| Severidade | Tipo | Linha | Detalhe | Correção sugerida |
|---|---|---|---|---|
| ALTA (verificada) | XSS via innerHTML com dados de API | 156 | `nome` e `sub` vêm do JSON da API (supervisor_nome/nome, cargo_rotulo, unidade_nome, L151-153) e são concatenados sem escape em `li.innerHTML` (155-158). Um nome com `<img src=x onerror=...>` executa. Fluxo: `fetch(API_LISTA)` -> JSON.parse -> forEach -> innerHTML. | Usar `textContent` para `nome`/`sub` (spans + `.textContent`), ou escapar HTML antes de concatenar. |
| MEDIA (a confirmar) | XSS via innerHTML com dado derivado de API | 118 | `nome` (da API, L151) propagado para `confirmar(nome,id)` (L159) e injetado em `confirm-msg.innerHTML` sem escape. Mesmo vetor da L156, dispara ao clicar 'Análise individual'. | Montar a mensagem com textContent; texto fixo + `<b>` separado cujo textContent recebe `nome`, ou escapar. |
| MEDIA (a confirmar) | Token de sessão em sessionStorage transmitido como Bearer | 138 | `session_token` lido de sessionStorage e enviado no header Authorization; qualquer XSS (118/156) exfiltra o token, único credencial da tela. | Preferir cookie HttpOnly+SameSite; enquanto ficar em storage, eliminar os vetores de XSS. |
| BAIXA (a confirmar) | UUID/URL de webhook exposto no front-end | 96 | `API_LISTA` hardcoded no HTML. Não é UUID secreto (path nomeado) e o acesso exige Bearer; risco baixo, revela topologia. | Garantir que o webhook valide o Bearer e o escopo por token no backend. Manter URL no front é aceitável. |

## Comentarios (para remocao segura)

| Tela | HTML | Bloco | Linha | Total |
|---|---|---|---|---|
| index.html | 34 | 30 | 90 | 154 |
| FORMULARIO.html | 30 | 298 | 38 | 366 |
| formulario_supervisao.html | 25 | 285 | 24 | 334 |
| formulario_du.html | 34 | 44 | 130 | 208 |
| dashboard_geral_v1.html | 7 | 155 | 152 | 314 |
| dashboard_doc_individual.html | 17 | 99 | 58 | 174 |
| dashboard_sup_individual.html | 17 | 97 | 54 | 168 |
| dashboard_du_individual.html | 18 | 108 | 54 | 180 |
| dashboard_dp_individual.html | 17 | 97 | 60 | 174 |
| ferias.html | 11 | 90 | 14 | 115 |
| dashboard_unico_sup.html | 0 | 4 | 0 | 4 |
| **Total** | **210** | **1307** | **674** | **2191** |

### Comentários "notable" (NÃO apagar antes de virar documentação)

**index.html**
- L1472 — "Backend via webhook do n8n (não alterar sem ajustar o fluxo)." — acopla o front ao fluxo n8n.
- L1474 — `const WEBHOOK_URL = '.../webhook/login-validacao'` — endpoint operacional de login a mapear.
- L1569 — "o n8n às vezes manda um '=' ...limpa antes de parsear" — workaround do backend; remover sem doc quebra o parse.
- L1761 — "rótulos amigáveis para os cargos (edite/adicione aqui)" — ponto de config `CARGO_LABELS`.
- L2208 — "Atualize os valores abaixo com os dados reais do gestor logado / trimestre." — marcador ADAPTAR (`JANELA_ACOMPANHAMENTO`).
- L2212 — `inicio: '2026-06-29'` — config hardcoded do trimestre (countdown).
- L2344 — "cada dashboard abre em SEU arquivo separado (DASH_PAGINA)" — comentário induz a erro (4 dashboards apontam ao mesmo arquivo).
- L2765 — "DEMO opcional p/ ver a UI antes do n8n: ?demo_avaliadores=1" — feature de DEMO por query param.
- L2757 — "O dashboard chama window.setAvaliadores(lista, avaliadorAtual)..." — contrato de integração entre telas.
- L2809 — "Requer seletor_individual.js para o 'Dashboard Individual - Liderado'." — dependência entre blocos inline.

**FORMULARIO.html**
- L2166 — "CONFIGURAÇÃO (ADAPTAR AQUI)" — fronteira do bloco de URLs de webhook/login por ambiente.
- L2174 — "Turmas: GET simples (sem token)... cai no fallback" — contrato de API e fallback.
- L5904 — "DEMO opcional p/ ver a UI antes do n8n: ?demo_avaliadores=1" — flag de dev que injeta avaliadores falsos.
- L2159 — "...O backend/n8n é a fonte da verdade sobre sessão, cargo, ... permissões." — nota arquitetural de autorização.
- L3721 — "TURMAS — trazidas por API (GET simples, sem token)..." — reforça que o endpoint não usa token.

**formulario_supervisao.html**
- L2951 — "CONFIGURAÇÃO (ADAPTAR AQUI) — webhooks do n8n" — bloco de config de endpoints.
- L2957 — "Endpoints específicos deste formulário. Ajuste os caminhos no n8n." — instrução de deploy.
- L2953 — "NUNCA coloque tokens/credenciais aqui: a validação real é do n8n." — regra de segurança operacional.
- L3022 — "UNIDADES = []; /* mantido p/ compatibilidade ... */" — código legado; candidato a remoção.
- L3885 — "TRAVADO no trimestre atual (config)" — período fixado via `JANELA_ACOMPANHAMENTO`.
- L4969 — "DEMO opcional p/ ver a UI antes do n8n: ?demo_avaliadores=1" — modo DEMO por query param.
- L4964 — "senão → recarrega com &avaliador_id=<id>" — contrato de navegação do filtro 'Avaliado por'.

**formulario_du.html**
- L2847 — "CONFIGURAÇÃO (ADAPTAR AQUI) — webhooks... NUNCA coloque tokens/credenciais aqui" — bloco de config de endpoints.
- L2854 — "Endpoints específicos deste formulário. Ajuste os caminhos no n8n." — instrução de deploy.
- L2856 — "API_ANALISE_INDIVIDUAL ... fallback (traz respostas/plano)" — endpoint é fallback do buscar-avaliacao.
- L3179 — "rede de segurança: se o segmento não veio no topo, busca dentro de acessos[]..." — contrato real do payload de login.
- L2942 — "status_avaliacao ... status POR avaliador (vem da API)" — contrato de campos de listar-unidades.
- L3768 — "TRAVADO no trimestre atual (config)" — `periodo_ref` fixado por `JANELA_ACOMPANHAMENTO`.
- L4944 — "DEMO opcional... ?demo_avaliadores=1" — debug/demo por query param.
- L3251 — "const JANELA_ACOMPANHAMENTO = { trimestre, inicio:2026-06-29, fim:2026-09-04 }" — janela/trimestre hardcoded (ponto de manutenção).

**dashboard_geral_v1.html**
- L5 — "sessao_guard.js (embutido/inline)... Deve ser incluído NO <head>..." — ordem de inclusão do guard de sessão.
- L3234 — "portal_nav.js — ... Liga [data-portal]. Requer seletor_individual.js" — contrato de navegação e dependência.
- L2879 — "seletor_individual.js — ... Usado em TODAS as telas ... Uso: window.abrirSeletorIndividual()" — componente compartilhado e APIs.
- L3440 — "exportador.js — ... Inclua ANTES do script da página ... Exportador.montarBotaoExport(...)" — ordem de inclusão e API pública.
- L2194 — "DEMO opcional... ?demo_avaliadores=1" — flag de dev/demo.
- L2855 — "diagnóstico: admin/DP-Geral deveria ver todos os grupos..." — comportamento ligado à saúde dos webhooks.
- L2674 — "setTimeout(hideBootLoader, 12000); // rede de segurança..." — timeout operacional (12s) do loader.

**dashboard_doc_individual.html**
- L1056 — "URL: dashboard_doc_individual.html?professor_id=<uuid>&professor=<nome>" — contrato de entrada da tela.
- L1101 — `API_SALVAR_ACOMPANHAMENTO = '.../webhook/d4e62b32-...'` — endpoint n8n com UUID hardcoded.
- L2551 — "DEMO opcional... ?demo_avaliadores=1" — modo DEMO por query param.
- L2372 — "A lista de avaliadores vem da API (o servidor aplica a cascata...)" — regra de negócio/segurança e contrato.
- L2227 — "BARRA DE MENUS DA TELA INDIVIDUAL (inline) — trocar o liderado + pular seções" — mecanismo de navegação.
- L5 — "sessao_guard.js — trava de acesso dos dashboards" — regra de segurança do guard.

**dashboard_sup_individual.html**
- L5 — "sessao_guard.js (embutido/inline)... Deve ser incluído NO <head>..." — ordem de carga do guard.
- L1054 — "PARAMETRIZAÇÃO — ...?supervisor_id=<uuid>&supervisor=<nome>" — contrato de entrada e endpoint.
- L2553 — "DEMO opcional... ?demo_avaliadores=1" — modo DEMO por query param.
- L2373 — "Filtro 'Avaliado por' — A lista de avaliadores vem da API (cascata server-side)" — regra de negócio de autorização.
- L1445 — "it.re = false; // reincidência não é capturada pelo formulário" — decisão de escopo do backend.
- L2044 — "seletor_individual.js — ... Usado em TODAS as telas ... Uso: window.abrirSeletorIndividual()" — bloco compartilhado.
- L461 — "régua de continuidade (0-100%) com 3 pinos" — regra fixa do termômetro (regra de RH).

**dashboard_du_individual.html**
- L2634 — "DEMO opcional... ?demo_avaliadores=1" — modo de teste por query param.
- L5 — "sessao_guard.js — ... Deve ser incluído NO <head>..." — ordem de inclusão do guard.
- L2125 — "seletor_individual.js ... Usado em TODAS as telas ... Uso: window.abrirSeletorIndividual()" — lib compartilhada e API pública.
- L2703 — "portal_nav.js ... Liga [data-portal]. Requer seletor_individual.js" — dependência de ordem entre scripts.
- L1054 — "PARAMETRIZACAO ... ?unidade_id=<uuid>&diretor=<nome>" — contrato de entrada e endpoint.
- L1529 — "it.re = false; // reincidência não é capturada / it.th = undefined; // tema não é capturado" — limitação do formulário real.
- L1514 — "respostas: { codigo, letra, resposta(S/P/N/NA), observacao }" — shape do payload da API.

**dashboard_dp_individual.html**
- L1054 — "URL: dashboard_dp_individual.html?diretor_id=<uuid>&diretor=<nome>" — contrato de query params.
- L1101 — `API_SALVAR_AVALIACAO_DEV = '.../salvar-avaliacao'` — endpoint operacional de gravação.
- L1464 — "reincidência não é capturada pelo formulário" — limitação funcional (re/th vazios com dado do banco).
- L1569 — "DEMO opcional... ?demo_avaliadores=1" — modo debug/demo que injeta dados falsos.
- L2395 — "se o dashboard definir window.trocarAvaliador(id) → troca SEM recarregar; senão → &avaliador_id=<id>" — contrato de troca de avaliador.
- L2849 — "Inclua ANTES do script da página (window.Exportador fica disponível)" — ordem de carga do exportador.js.

**ferias.html**
- L727 — "Endpoints do backend (n8n)... cai automaticamente em modo local (localStorage)." — estratégia de fallback api->local.
- L763 — "catálogos (unidade + segmento)... Vêm do endpoint /ferias/listar..." — contrato do endpoint e SEG_FALLBACK.
- L739 — "modo demonstração: SOMENTE com ?demo=1 ... a trava de sessão bloqueia..." — hatch de bypass de sessão.
- L1394 — "exclusão de colaborador com re-autenticação por OTP... código enviado ao PRÓPRIO e-mail." — fluxo de segurança de exclusão.
- L8 — "sessao_guard.js (embutido/inline)... Exceção: ?demo=1..." — guard de sessão inline e exceção.
- L1518 — "modo API: endpoint dedicado gera os colaboradores... modo local: agrega os endpoints de listagem" — mapa de integração de `importarGestores`.
- L1655 — "aplica o papel: editor (administradores)... gestor vê só o dashboard" — regra de autorização (`PODE_EDITAR`); nomes hardcoded a revisar.

**dashboard_unico_sup.html**
- L133 — "carrega a lista via API (escopo resolvido no backend pelo token)" — contrato operacional do endpoint.

## Codigo morto e linhas sem utilidade

**index.html**
- L1782 — branch-morto/elemento inexistente — `if($('session-email'))...` — não existe `#session-email`; ramo nunca executa.
- L2722 — função nunca acionada nesta tela — `window.montarBarraIndividual` — depende de `#indMenuBar` (só nos dashboards individuais). Todo o subsistema (~2634-2799) é código morto no index.
- L2712 — função órfã — `opcoesSecoes()` — depende de `.sidebar`/`.nav-item`, inexistentes; nem é chamada.
- L1998 — fallback inalcançável na prática — `if(typeof abrirSeletorIndividual...)...else...` — `abrirSeletorIndividual` sempre definida.
- L2823 — fallback inalcançável — `else if(typeof window.openIndividualList...)` — nunca definido.
- L1563 — console de debug — `console.error('[login] fetch falhou...')`.
- L1575 — console de debug — `console.warn('[login] resposta não-JSON...')`.
- L2766 — código de DEMO em produção — dados fake por `?demo_avaliadores=1`.
- L2358 — constante frágil/duplicada — `const TODAS_UNIDADES = 'Todas as 9 direções de unidade';`.
- L2345 — mapa redundante — `DASH_PAGINA` (4 chaves apontam ao mesmo arquivo).
- L1833 — possível helper subutilizado — `function materiaDoUsuario(perm)` (usada só em 1873).

**FORMULARIO.html**
- L5904 — flag-de-dev / código de demo — bloco DEMO em `setAvaliadores()` (linhas 5905-5908).
- L5217 — console de debug — `console.error("[buscarAcompanhamento] falha:", erro)`.
- L2373 — branch inalcançável — `if (typeof mostrarTelaLogin === "function")...` — função não existe.
- L5962 — branch inalcançável — `else if(typeof window.openIndividualList...)`.
- L3625 — duplicação entre telas / lib inline — seletor_individual + portal_nav + trava de identificação, idênticos em todas as telas.
- L16 — asset de dev possivelmente órfão — `--logo-dev` (data-URI ~14KB) só alimenta a assinatura do dev.
- L1854 — elemento oculto / markup morto — `.topbar-left` inteiro com `display:none` + img data-URI ~14KB.
- L2199 — estilo CSS possivelmente órfão — `.topbar/.topbar-title/.logout-link/.back-link` substituídos por `.app-topbar`.

**formulario_supervisao.html**
- L3051 — função nunca chamada — `unidadePorCodigo(cod)` (cadeia legada; UNIDADES sempre []).
- L3074 — função nunca chamada — `segmentosDaUnidade(cod)`.
- L3082 — função nunca chamada — `cargoEhAdmin()`.
- L3086 — função nunca chamada — `unidadesDisponiveis()`.
- L3063 — constante nunca usada de fato — `const SEGMENTOS_POR_UNIDADE = {...}`.
- L3022 — variável de estado nunca populada — `let UNIDADES = [];`.
- L3924 — função efetivamente no-op / branch inalcançável — `renderizarParte2()` sempre limpa `#parte2-area`.
- L4294 — função que sempre retorna vazio — `coletarChecklist()`.
- L4172 — função efetivamente no-op — `renderizarChecklist()` (não existe `#checklist-area`).
- L15 — asset dev órfão (data-URI) — `--logo-dev` (~13.9KB) sem HTML correspondente.
- L253 — seletores CSS órfãos — `.app-foot-row/.rodape-brand/.rodape-connector/.assinatura-dev-inline`.
- L3032 — console de diagnóstico — `console.warn("[supervisores] HTTP", resp.status)` (5 ocorrências).
- L3325 — possível duplicação inline entre telas — `ICON_PIN/ICON_USER` + blocos seletor_individual/portal_nav/trava-ident.

**formulario_du.html**
- L2856 — endpoint-fallback pouco usado — `API_ANALISE_INDIVIDUAL` (fallback em abrirAvaliacao 3580).
- L4813 — código de outra tela (inerte aqui) — bloco `montarBarraIndividual/setAvaliadores/...` depende de `#indMenuBar`/`.sidebar` inexistentes.
- L4891 — função nunca acionada nesta tela — `opcoesSecoes()` (depende de `.sidebar`).
- L5005 — branches inalcançáveis do switch — `case 'form-docente'/'form-supervisao'/'form-du'/'form-dp'` nunca disparam.
- L4665 — branch default provavelmente inalcançável — `default: return 'dashboard_sup_individual.html?...'`.
- L2932 — console.warn de diagnóstico — (2932, 2947, 3577, 3581, 3618).
- L4317 — campos coletados de inputs inexistentes — `tipo_visita/outros_participantes/docs_conferidos/data_followup` (getVal retorna '' sempre).
- L3220 — constante declarada e não usada (conferência) — `ICON_USER`/`ICON_PIN` ambos em uso; sem órfãos.
- L1731 — regra CSS de view inexistente / topbar antiga — `.topbar/.topbar-*` órfãos (header real é `.app-topbar`).
- L117 — seletores CSS órfãos — `.logout-link, .back-link` (layout antigo; body usa `.tb-btn/.tb-exit`).

**dashboard_geral_v1.html**
- L2864 — console de debug — `console.warn('[carregarReal] grupos sem retorno:'...)`.
- L187 — seletor/feature morta (renderizada mas escondida) — `#quickChips{display:none}` mas `syncQuickChips()` ainda constrói innerHTML.
- L2906 — função duplicada de navegação — `rota()` vs `rotaIndividual()` (1627).
- L1638 — branch de navegação raramente alcançável — `else if(typeof window.openIndividualList...)`.
- L1194 — definição duplicada de CARGOS — global (1194, 9 cargos) vs local no IIFE (2892, 5 cargos).
- L3104 — helper de escape sub-utilizado — `imEsc` não aplicado nos rowHTML (3042, 1645, 2160, 3175).
- L2674 — constante de comportamento de dev — `setTimeout(hideBootLoader, 12000)` (número mágico).

**dashboard_doc_individual.html**
- L1723 — dados-demo/mock — `let roster=[{n:"Patrícia Rocha",...}]` (ranking fictício de 10 docentes).
- L1983 — dados-demo/mock — `let apData=[...]` (plano de ação fictício, 5 linhas).
- L1958 — dados-demo/mock — `?BANCO.pontos_positivos : ["Conduz atendimentos difíceis...",...]`.
- L1299 — dados-demo/mock — `const blocks=[{id:'A',...}]` (blocos A-H com notas/observações de exemplo, ~1290-1337).
- L2552 — código de demo atrás de flag — `?demo_avaliadores=1` injeta 3 avaliadores falsos.
- L1079 — console debug — `console.warn('Falha ao carregar análise do docente:', e)` (idem 2039).
- L2639 — branch/fallback provavelmente morto — `else if(typeof window.openIndividualList...)`.
- L1805 — comentário enganoso / código morto de rótulo — `// juliana` (contexto é Mariana).
- L1755 — string hardcoded inconsistente com dados — `Mariana (5º)` fixa mesmo com roster do banco.

**dashboard_sup_individual.html**
- L1101 — constante mal-nomeada (não morta) — `API_SALVAR_AVALIACAO_DEV/TIPO_COD_DEV/LISTA_DEV` (usadas em produção; renomear).
- L2553 — modo demo acionável por query — `?demo_avaliadores=1` (dados falsos).
- L1079 — console.warn de debug — `console.warn('Falha ao carregar análise do supervisor:', e)`.
- L2041 — console.warn de debug — `console.warn('export wiring', e)`.
- L1445 — atribuições sempre no-op com dados reais — `it.re = false; it.th = undefined;` (UI de reincidência/tema morta com dado real).
- L1264 — estrutura de dados só usada pelo exemplo — `const THEMES={...}` (depende de `it.th`, nunca vem do banco).
- L1985 — dados de exemplo hardcoded (fallback) — `let apData=[...]` (plano de ação fictício); junto com blocks/roster/strengthList.
- L527 — timeout de segurança redundante — `setTimeout(window.hideBootLoader,12000)` (também chamado em 2022).
- L1105 — possível helper duplicado — `_fmtDataBR(iso)` e `fmtData(v)` (quase idênticos).

**dashboard_du_individual.html**
- L1277 — dados-exemplo/mortos em produção — `let blocks=[...]` (~10 blocos, centenas de itens; c/ev sempre do template).
- L2067 — dados-exemplo mortos — `let apData=[...]` (5 linhas fake com nomes reais).
- L1807 — dados-exemplo mortos — `roster=[...]` (~11 pessoas fake; legenda `Claudia (5º)` hardcoded).
- L2634 — bloco de debug/demo — `?demo_avaliadores=1` (2635-2640).
- L1080 — console de debug — `console.warn('Falha ao carregar análise do Diretor de Unidade:', e)` (idem 2122).
- L1809 — referência inconsistente / nome próprio hardcoded — `// juliana` (1888) + caption `Claudia` (copy/paste).
- L1435 — flag possivelmente sempre-undefined — `if (typeof VAZIO!=='undefined' && VAZIO) roster=[];` (branch possivelmente morto).

**dashboard_dp_individual.html**
- L1103 — constante possivelmente redundante — `const LISTA_DEV = 'formulario_dp.html';` (usada em salvarAgenda 1190; alvo .html hardcoded).
- L1357 — variável de exemplo/mock embutida — `let blocks=[...]` (~80 itens fictícios; Karla Lavrador).
- L1741 — dados mock (roster) nunca usados quando há banco — `let roster=[{n:"Patrícia Rocha",...}]`.
- L2001 — dados mock (apData) nunca usados quando há banco — `let apData=[{ref:"D2 · D4",...}]`.
- L1977 — fallback de conteúdo fictício hardcoded — `["Conduz atendimentos difíceis...(D9, G6)", ...]` (refs inexistentes no instrumento DP).
- L2569 — código de debug/demo acionável por query param — `?demo_avaliadores=1` (Maria Silva/João Costa/Ana Prado).
- L1079 — console.warn de debug — `console.warn('Falha ao carregar análise do diretor pedagógico:', e)` (idem 2057).
- L2657 — branch praticamente inalcançável — `else if(typeof window.openIndividualList...)`.
- L608 — conteúdo estático inconsistente (resíduo) — `<div class="avatar">JM</div>` (nome exibido é 'Karla Lavrador').
- L1823 — comentário/nome de variável residual — `// juliana`.
- L1273 — tema nunca atribuído — `comunicacao:{...}` em THEMES (nenhum item usa `th:'comunicacao'`; idem 'tecnico').

**ferias.html**
- L1200 — função usada apenas internamente (ok, não morta) — `function isoDe(d)` (usada em renderGrafico/seedDemo).
- L969 — constante/função de baixo uso — `const tipoLancRotulo = ...` (uso legítimo em cardConfigHTML).
- L753 — variável de baixo uso — `const meuEmail = ...` (usada em ehSelf; não morta).
- L1105 — objeto local recriado a cada render — `const BADGE = {...}` (micro-ineficiência; içar para módulo).
- L794 — constante usada — `const GRUPO_OUTROS = {...}` (usada em grupoDe/renderConfig; não morta).

**dashboard_unico_sup.html**
- (nenhum item de código morto registrado)

## Otimizacoes

| Tela | Otimização | Economia estimada (KB) |
|---|---|---|
| index.html | Externalizar/otimizar data-URI base64 gigante (logo do hero) | 160 |
| index.html | Externalizar mandala PNG base64 (--mandala) | 34 |
| index.html | Externalizar CSS compartilhado | 30 |
| index.html | Externalizar JS compartilhado (seletor_individual + portal_nav) | 14 |
| index.html | Remover código morto da barra individual no index | 9 |
| index.html | Minificação geral | 12 |
| FORMULARIO.html | Data-URI gigante repetido entre telas (--mandala) | 36 |
| FORMULARIO.html | Data-URI de logo duplicado / oculto | 28 |
| FORMULARIO.html | JS inline duplicado → externalizar e compartilhar | 18 |
| FORMULARIO.html | CSS inline extenso → externalizar tema compartilhado | 30 |
| FORMULARIO.html | Minificação geral (HTML/CSS/JS) | 40 |
| formulario_supervisao.html | Data-URI PNG grande (mandala) | 36 |
| formulario_supervisao.html | Data-URI PNG dev órfão (--logo-dev) | 14 |
| formulario_supervisao.html | JS inline duplicado entre telas (externalizar) | 22 |
| formulario_supervisao.html | CSS inline compartilhável (externalizar) | 60 |
| formulario_supervisao.html | Remoção de código morto | 6 |
| formulario_supervisao.html | Minificação geral | 120 |
| formulario_du.html | Data-URI PNG gigante inline (mandala) | 35 |
| formulario_du.html | Data-URI PNG inline (logo-dev) | 13 |
| formulario_du.html | CSS inline não compartilhado entre telas | 45 |
| formulario_du.html | JS de helpers/menu duplicado entre telas | 30 |
| formulario_du.html | Regras CSS órfãs/duplicadas | 6 |
| formulario_du.html | Minificação geral | 40 |
| dashboard_geral_v1.html | Data-URI PNG duplicado (logo Alfa CEM, 3×) | 70 |
| dashboard_geral_v1.html | Data-URI PNG grande único (mandala mask) | 30 |
| dashboard_geral_v1.html | CSS inline não compartilhado entre telas | 45 |
| dashboard_geral_v1.html | JS inline compartilhado não externalizado | 40 |
| dashboard_geral_v1.html | Minificação geral | 60 |
| dashboard_geral_v1.html | Dados sintéticos embutidos (MANAGERS/PEOPLE/seed) | 25 |
| dashboard_doc_individual.html | Data-URI base64 gigante (logo PNG) | 34 |
| dashboard_doc_individual.html | Data-URI base64 gigante (mandala PNG de fundo) | 36 |
| dashboard_doc_individual.html | CSS/JS inline compartilhável entre telas | 60 |
| dashboard_doc_individual.html | CSS inline extenso não minificado | 18 |
| dashboard_doc_individual.html | Dados de exemplo embutidos | 8 |
| dashboard_doc_individual.html | Minificação geral do HTML/JS | 30 |
| dashboard_sup_individual.html | Data-URI PNG gigante (logo hero) | 34 |
| dashboard_sup_individual.html | Data-URI PNG gigante (mandala do menu) | 35 |
| dashboard_sup_individual.html | CSS/JS inline compartilhado não externalizado | 40 |
| dashboard_sup_individual.html | CSS inline grande e não minificado | 18 |
| dashboard_sup_individual.html | Dados mock embutidos | 12 |
| dashboard_sup_individual.html | Minificação geral | 30 |
| dashboard_du_individual.html | Data-URI PNG gigante (mandala) inline em CSS | 36 |
| dashboard_du_individual.html | Data-URI PNG gigante (hero logo) inline em HTML | 34 |
| dashboard_du_individual.html | CSS/JS inline duplicado entre telas (libs compartilhadas) | 70 |
| dashboard_du_individual.html | CSS inline extenso não minificado | 25 |
| dashboard_du_individual.html | Dados de exemplo embutidos removíveis em produção | 12 |
| dashboard_du_individual.html | Minificação geral do HTML/JS inline | 20 |
| dashboard_dp_individual.html | Data-URI PNG gigante (mandala) inline | 34 |
| dashboard_dp_individual.html | Segundo data-URI/CSS bloco grande | 20 |
| dashboard_dp_individual.html | CSS inline duplicado entre telas | 40 |
| dashboard_dp_individual.html | JS inline duplicado entre telas (libs) | 45 |
| dashboard_dp_individual.html | Dados mock removíveis em produção | 12 |
| dashboard_dp_individual.html | Minificação geral | 30 |
| ferias.html | Data-URI PNG gigante inline (mandala) | 36 |
| ferias.html | CSS inline duplicado entre telas | 18 |
| ferias.html | JS de chrome/menu inline duplicado | 8 |
| ferias.html | Minificação do JS/CSS inline da aplicação | 10 |
| dashboard_unico_sup.html | Externalizar CSS compartilhado | 2.5 |
| dashboard_unico_sup.html | Externalizar JS de navegação/sair comum | 0.5 |
| dashboard_unico_sup.html | Minificação | 1 |
| **Total** | | **2130.5** |

## Observacoes

- **Tela legada:** `dashboard_unico_sup.html` está marcada como POSSÍVEL LEGADO (dashboard único de supervisão, arquivo curto de ~7KB / 169 linhas). Não possui `portal_nav.js` embutido nem menu lateral `.vnav-item`; a navegação resume-se a Voltar/Sair→index.html e o modal→`dashboard_sup_individual.html`. Nenhuma outra tela mapeada referencia `dashboard_unico_sup.html` no contexto fornecido — recomenda-se verificar quem ainda a utiliza antes de manter.
- **Arquivo de teste vazio:** o registro `test` (screenTitle "t", role "t", ~370KB aproximado) não possui comentários, vulnerabilidades, código morto nem otimizações registradas — aparenta ser um placeholder/artefato sem conteúdo relevante para a auditoria.
- **Duplicação massiva entre telas:** os blocos inline `seletor_individual.js`, `portal_nav.js`, `sessao_guard.js`, `vnav.js` e `exportador.js` são colados idênticos em praticamente todas as telas do portal (os próprios comentários indicam "embutido/inline" e "usado em TODAS as telas"). O mesmo vale para o data-URI da mandala (~34-36KB por tela, replicado byte-a-byte), os logos base64 (hero/logo-dev) e grandes blocos de CSS de tema holográfico/topbar/vnav. Externalizar esses ativos em `.js`/`.css`/imagens compartilhadas é a maior oportunidade de redução de payload e de centralização de correções (inclusive dos fixes de XSS, que hoje precisam ser replicados em cada arquivo).
- **CSS/assets órfãos herdados por cópia:** várias telas trazem estilos e markup de uma topbar antiga (`.topbar`, `.logout-link`, `.back-link`, `.assinatura-dev-inline`) e o asset `--logo-dev`, sem HTML correspondente — resíduos de copy/paste entre telas.
- **Resíduos de cópia entre dashboards individuais:** comentários e strings com nomes próprios de outras telas (`// juliana`, captions "Claudia (5º)"/"Mariana (5º)", avatar `JM` em tela da Karla) confirmam reaproveitamento entre `dashboard_*_individual.html`, gerando dados/legendas incoerentes com o registro real.
- **Modo DEMO em produção:** todas as telas do fluxo carregam código de demonstração acionável por `?demo_avaliadores=1` (e `?demo=1` em `ferias.html`, que também faz bypass da trava de sessão) — deve ser documentado e removido antes de produção.
