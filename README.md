# Avaliação institucional: formulários, dashboards em cascata e devolutivas

Plataforma de avaliação das equipes pedagógicas de uma rede de escolas. Cada profissional é avaliado por quem o lidera, dentro de uma janela por trimestre: o avaliador preenche o instrumento do cargo (com critérios condicionais por função), agenda a devolutiva e, ao concluir, a avaliação alimenta os painéis. Os dashboards seguem a cascata da rede (supervisão vê docentes, direção de unidade vê supervisores, direção pedagógica vê a cascata abaixo, direção geral vê tudo em leitura). A devolutiva gera uma ata para impressão. Completam o portal um painel da direção, a gestão de pessoas (organograma e acessos), o controle de férias e um canal de chamados de suporte.

## Como está organizado

Este repositório é a pasta publicada do portal (o que sobe para a hospedagem), e não o projeto de desenvolvimento. Por isso os HTML ficam na raiz.

| Caminho | O que é |
|---|---|
| `index.html` | Login por código enviado ao e-mail e portal de entrada |
| `FORMULARIO.html` | Avaliação de docentes |
| `formulario_supervisao.html`, `formulario_direcao_unidade.html`, `formulario_direcao_pedagogica.html`, `formulario_coordenacao.html` | Avaliação da supervisão, direção de unidade, direção pedagógica e coordenação de área |
| `dashboard_geral.html` | Painel do gestor sobre a própria equipe |
| `dashboard_comparativo.html` | Comparativo entre cargos |
| `dashboard_*_individual.html` | Painel individual (docente, supervisão, direção de unidade, direção pedagógica) |
| `gestao-pessoas.html` | Organograma e cadastro de acessos |
| `ferias.html` | Controle de férias |
| `painel_suporte.html`, `atualizacoes.html` | Chamados de suporte e mural de novidades |
| `assets/portal-nav.js` | Menu de navegação único das telas: item ativo, itens por cargo, cascata e botão de suporte |
| `assets/releases.js` | Fonte única das notas de versão do mural |
| `functions/webhook/[[path]].js` | Proxy `/webhook/*` para o n8n (único lugar onde a URL da API é configurada) |
| `_redirects` | Redirecionamentos de URLs antigas |
| `banco/schema.sql` | DDL parcial do banco (tabelas de config, bloqueio, férias, notificações, suporte) |
| `banco/migracao_*.sql` | Migrações: recorte de visualização por segmento e série como recorte de supervisão |
| `docs/` | Mapa de segurança dos endpoints, mapa de navegação, checklist de deploy, auditoria das telas, requisitos do controle de férias e notas sobre a virada de trimestre |

Três camadas, com responsabilidades separadas:

- Telas: HTML autocontido, sem framework nem build. Cada arquivo é uma tela inteira.
- API: fluxos do n8n que respondem a cada tela (listar, buscar, salvar). Toda chamada exige o token de sessão e devolve apenas o que aquele usuário pode ver. A regra de visibilidade mora no servidor, nunca na tela.
- Banco: PostgreSQL, com cadastro de pessoas, acessos por cargo, alocações de docentes e as avaliações.

Os SQL que rodam dentro de cada nó do n8n não fazem parte deste repositório; os documentos em `docs/` descrevem os endpoints e o que cada um precisa garantir.

## Stack

- Front: HTML, CSS e JavaScript puros
- API: n8n (webhooks)
- Banco: PostgreSQL
- Hospedagem: Cloudflare Pages, com uma Pages Function como proxy da API

## Como publicar

1. Crie as tabelas: rode `banco/schema.sql` e depois `banco/migracao_recorte_visualizacao.sql` e `banco/migracao_series_supervisao.sql` no seu PostgreSQL. As tabelas centrais (usuários, acessos, unidades, professores, alocações, avaliações) não têm DDL versionado aqui.
2. Monte os fluxos no n8n com as rotas listadas em `docs/SEGURANCA_ENDPOINTS_LEITURA.md`.
3. Em `functions/webhook/[[path]].js`, troque `https://SEU-N8N/webhook` pela base dos seus webhooks. As telas chamam `/webhook/...` em caminho relativo e o proxy repassa.
4. Troque `SEU-WEBHOOK-SALVAR-ACOMPANHAMENTO-DOCENTE` (em `FORMULARIO.html`, `dashboard_geral.html` e nos dashboards individuais) pelo caminho do seu webhook de salvar avaliação docente.
5. Ajuste os e-mails e nomes de exemplo (`usuarioN@exemplo.edu.br`) em `assets/portal-nav.js`, `index.html`, `formulario_supervisao.html` e `gestao-pessoas.html`.
6. Publique: `npx wrangler login` (uma vez) e `npx wrangler pages deploy . --project-name SEU-PROJETO --branch production`. Confira na saída a linha `Uploading Functions bundle`; sem ela o proxy não subiu.
7. Para testar antes: `npx wrangler pages dev .`

## Convenções que evitam retrabalho

- Toda regra de quem vê o quê existe em dois lugares: na tela e no servidor. Esconder um botão não impede o envio.
- Cada tela tem dois controles de acesso: o da própria tela e o do menu (`assets/portal-nav.js`).
- O prazo do ciclo alimenta o contador e só; não bloqueia ninguém. Onde ele está escrito: `docs/PRAZO_DO_CICLO_7_ARQUIVOS.md`.
- A sessão dura 3 horas e é guardada por origem: todas as telas precisam estar no mesmo endereço.

## Dados

Este repositório não contém dados pessoais; os arquivos de importação e as listas ficam fora por LGPD. E-mails e nomes que aparecem no código são fictícios.
