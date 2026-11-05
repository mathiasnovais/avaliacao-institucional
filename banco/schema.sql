-- ============================================================
-- SCHEMA PARCIAL DO BANCO (PostgreSQL)
--
-- Reunido a partir dos blocos de DDL que existiam em arquivos separados
-- do projeto original. Não é o schema completo: as tabelas centrais
-- (app_usuarios, usuario_acessos, unidades, disciplinas, professores,
-- professor_alocacoes, acompanhamento_respostas, login_sessoes) foram
-- criadas antes e não têm DDL versionado. Os blocos abaixo referenciam
-- essas tabelas por FK.
--
-- Origem de cada bloco (arquivo da fonte):
--   1. app_config                       <- config_trimestre.sql
--   2. docente_visibilidade_bloqueio    <- bloqueio_visibilidade_docente.sql
--   3. ferias_colaboradores/lancamentos <- n8n/n8n_ferias_schema.sql
--   4. analise em acompanhamento_respostas <- n8n/n8n_analise_ia_migration.sql
--   5. notificacoes                     <- notificacoes.sql
--   6. suporte_chamados                 <- suporte_chamados.sql
-- As migrações usuario_recorte_visualizacao e series ficam em arquivos
-- próprios nesta pasta. Tudo idempotente (if not exists).
-- ============================================================

create extension if not exists pgcrypto;   -- gen_random_uuid(), digest()

-- ------------------------------------------------------------
-- 1. CONFIG: trimestre atual (fonte única da "rodada" de avaliação).
--    Os nós de listagem filtram o STATUS pelo trimestre lido aqui.
--    Histórico preservado: avaliações antigas continuam no banco, só
--    deixam de contar como "rodada atual". O valor INCLUI O ANO.
-- ------------------------------------------------------------
create table if not exists public.app_config (
  chave         text primary key,
  valor         text,
  atualizado_em timestamptz default now()
);
-- virar de trimestre:
-- update public.app_config set valor='1º Trimestre · 2027', atualizado_em=now() where chave='trimestre_atual';

-- ------------------------------------------------------------
-- 2. LISTA DE BLOQUEIO: "este docente não aparece para este avaliador".
--    Para quando vários supervisores dividem o mesmo recorte
--    (unidade + segmento) e a divisão real não cabe na regra automática.
--    A listagem de docentes no n8n entra com "and not exists (...)".
-- ------------------------------------------------------------
create table if not exists public.docente_visibilidade_bloqueio (
  professor_id  uuid not null references public.professores(id)  on delete cascade,
  usuario_id    uuid not null references public.app_usuarios(id) on delete cascade,
  motivo        text,
  criado_em     timestamptz not null default now(),
  primary key (professor_id, usuario_id)
);

comment on table public.docente_visibilidade_bloqueio is
  'Esconde um docente da lista de um avaliador especifico. Usado quando '
  'varios supervisores dividem o mesmo recorte (unidade+segmento) e a '
  'divisao real do trabalho nao cabe na regra automatica.';
-- uso:
-- insert into public.docente_visibilidade_bloqueio (professor_id, usuario_id, motivo)
-- select pr.id, au.id, 'motivo aqui'
-- from public.professores pr, public.app_usuarios au
-- where pr.email = 'docente@exemplo.edu.br' and au.email = 'usuario@exemplo.edu.br'
-- on conflict do nothing;

-- ------------------------------------------------------------
-- 3. CONTROLE DE FÉRIAS
--    ferias_colaboradores  -> 1 linha por gestor/colaborador (banco de dias)
--    ferias_lancamentos    -> períodos gozados (debitam do banco)
--    O vínculo com o login (app_usuarios) é opcional (usuario_id).
-- ------------------------------------------------------------
create table if not exists public.ferias_colaboradores (
  id             uuid primary key default gen_random_uuid(),
  usuario_id     uuid references public.app_usuarios(id) on delete set null,
  nome           text not null,
  cargo          text,
  email          text,
  unidade_id     uuid references public.unidades(id) on delete set null,  -- unidade onde trabalha
  segmentos      text[] not null default '{}',                            -- EI/EFAI/EFAF/EM/Bilinguismo
  total_dias     integer not null default 30,
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);

-- upgrade de instalações antigas (idempotente)
alter table public.ferias_colaboradores add column if not exists unidade_id uuid references public.unidades(id) on delete set null;
alter table public.ferias_colaboradores add column if not exists segmentos  text[] not null default '{}';

-- evita duplicar o mesmo usuário ao importar/gerar (quando há vínculo de login)
create unique index if not exists ux_ferias_colab_usuario
  on public.ferias_colaboradores(usuario_id) where usuario_id is not null;

create table if not exists public.ferias_lancamentos (
  id                     uuid primary key default gen_random_uuid(),
  colaborador_id         uuid not null references public.ferias_colaboradores(id) on delete cascade,
  tipo                   text not null default 'ferias',   -- 'ferias' (período corrido) | 'avulso' (desconto de dias)
  data_inicio            date not null,
  data_fim               date not null,
  dias                   integer not null,
  observacao             text,
  criado_por_usuario_id  uuid,
  criado_em              timestamptz not null default now()
);

-- upgrade de instalações antigas (idempotente)
alter table public.ferias_lancamentos add column if not exists tipo text not null default 'ferias';

create index if not exists ix_ferias_lanc_colab
  on public.ferias_lancamentos(colaborador_id);

-- ------------------------------------------------------------
-- 4. CACHE DA ANÁLISE QUALITATIVA no dashboard individual.
--    Guarda o texto gerado uma vez e o hash das entradas (respostas +
--    síntese) para invalidar o cache quando a avaliação muda.
-- ------------------------------------------------------------
alter table public.acompanhamento_respostas
  add column if not exists analise_ia       jsonb,
  add column if not exists analise_ia_hash  text,
  add column if not exists analise_ia_em    timestamptz;

comment on column public.acompanhamento_respostas.analise_ia is
  'Análise qualitativa gerada automaticamente p/ o dashboard individual: observacoes, pontos_fortes, causa_raiz, autoavaliacao.';
comment on column public.acompanhamento_respostas.analise_ia_hash is
  'sha256 das entradas (respostas+sintese) que geraram analise_ia; se mudar, regenerar';

-- Função canônica do hash de entrada, usada na geração e na leitura.
-- Considera só o que a IA lê: código+letra+resposta+observação de cada resposta,
-- em ordem estável, + as notas por dimensão.
create or replace function public.fn_analise_ia_hash(_avaliacao_id uuid)
returns text
language sql stable
as $$
  select encode(digest(
    coalesce((
      select string_agg(
               upper(coalesce(r->>'codigo', r->>'letra','')) || '|' ||
               upper(coalesce(r->>'resposta','')) || '|' ||
               coalesce(r->>'observacao',''),
               chr(30) order by upper(coalesce(r->>'codigo', r->>'letra','')))
      from public.acompanhamento_respostas ar
      cross join lateral jsonb_array_elements(coalesce(ar.respostas,'[]'::jsonb)) r
      where ar.id = _avaliacao_id
    ),'') || chr(29) ||
    coalesce((
      select string_agg(
               upper(coalesce(d->>'secao', d->>'letra','')) || '=' || coalesce(d->>'score',''),
               ',' order by upper(coalesce(d->>'secao', d->>'letra','')))
      from public.acompanhamento_respostas ar
      cross join lateral jsonb_array_elements(coalesce(ar.sintese_avaliativa->'dimensoes','[]'::jsonb)) d
      where ar.id = _avaliacao_id
    ),'')
  ,'sha256'),'hex');
$$;

-- ------------------------------------------------------------
-- 5. NOTIFICAÇÕES: o sino da tela inicial.
--    Derivadas do que já está no banco (hoje, dos chamados de suporte) e
--    gravadas na hora em que a pessoa lê. Gravação idempotente pelo índice
--    único (destinatário + origem + marco). Limpar a caixa ARQUIVA, não apaga.
-- ------------------------------------------------------------
create table if not exists public.notificacoes (
  id                      uuid primary key default gen_random_uuid(),
  destinatario_usuario_id uuid not null references public.app_usuarios(id),

  titulo                  text not null,
  texto                   text,
  link                    text,              -- arquivo.html para onde o aviso leva

  -- de onde veio o aviso; juntos com `marco` formam a chave anti-duplicata
  origem_tipo             text not null default 'geral',
  origem_id               uuid,
  marco                   text not null default '',

  lida_em                 timestamptz,

  -- >>> LIMPAR A CAIXA ARQUIVA, NÃO APAGA. <<<
  -- Os avisos são DERIVADOS do que está no banco e regravados a cada leitura;
  -- quem é apagado renasce no próximo clique no sininho, e a caixa "limpa"
  -- volta cheia. Arquivar mantém a linha (e com ela a trava anti-duplicata),
  -- só some da lista.
  arquivada_em            timestamptz,

  criado_em               timestamptz not null default now()
);

-- para quem rodou o PASSO 1 antes desta coluna existir (30/09/2026)
alter table public.notificacoes
  add column if not exists arquivada_em timestamptz;

-- >>> A TRAVA ANTI-DUPLICATA. <<<
-- Sem ela, cada abertura do sininho regravaria os mesmos avisos.
-- coalesce porque origem_id pode ser nulo (aviso solto, sem evento de origem),
-- e em índice único NULL não colide com NULL.
create unique index if not exists ux_notificacoes_origem
  on public.notificacoes (
    destinatario_usuario_id,
    origem_tipo,
    coalesce(origem_id, '00000000-0000-0000-0000-000000000000'::uuid),
    marco
  );
-- a consulta do sininho: as minhas, não lidas primeiro, mais recentes no topo
create index if not exists ix_notificacoes_destinatario
  on public.notificacoes (destinatario_usuario_id, lida_em, criado_em desc);


-- ------------------------------------------------------------
-- 6. SUPORTE: chamados abertos pelo menu "Suporte".
--    Conteúdo variável em jsonb (itens, pessoa); o que é comum a todo
--    chamado (quem abriu, quando, status) fica em coluna.
-- ------------------------------------------------------------
create table if not exists public.suporte_chamados (
  id            uuid primary key default gen_random_uuid(),

  -- quem abriu: id de verdade, não nome digitado
  aberto_por    uuid not null references public.app_usuarios(id),
  tela_origem   text,                       -- de qual tela o chamado saiu

  tipo          text not null,              -- 'visualizacao_pessoas'
  subtipo       text not null,              -- 'vejo_indevido' | 'nao_vejo'

  -- vejo_indevido: as pessoas que a lista dela mostra e não deveria.
  -- Guarda id E nome: o id serve para conferir o cadastro; o nome preserva o
  -- que ela viu na tela, mesmo que o cadastro mude depois.
  itens         jsonb not null default '[]'::jsonb,

  -- nao_vejo: dados de quem está faltando (nome, cargo e o que o cargo pede)
  pessoa        jsonb not null default '{}'::jsonb,

  observacao    text,

  -- o ciclo de vida do chamado
  status        text not null default 'aberto',   -- aberto | em_analise | resolvido | descartado
  resolvido_por uuid references public.app_usuarios(id),
  resolvido_em  timestamptz,
  resolucao     text,

  criado_em     timestamptz not null default now()
);

-- a consulta do dia a dia é "o que está aberto, mais recente primeiro"
create index if not exists ix_suporte_chamados_status
  on public.suporte_chamados (status, criado_em desc);

-- e "o que esta pessoa já abriu" (para não tratar o mesmo caso duas vezes)
create index if not exists ix_suporte_chamados_autor
  on public.suporte_chamados (aberto_por, criado_em desc);

-- >>> TRAVA DE CONTEÚDO, no banco e não só na tela. <<<
-- Sem isso um POST fora da tela grava tipo/subtipo inventado, e a consulta de
-- acompanhamento passa a ter lixo que ninguém sabe ler.
alter table public.suporte_chamados
  drop constraint if exists ck_suporte_chamados_subtipo;
alter table public.suporte_chamados
  add constraint ck_suporte_chamados_subtipo
  -- 'outro' (30/09/2026): assunto livre, o que a pessoa quiser relatar.
  -- Nele o conteúdo vai todo em `observacao` — não há itens nem pessoa.
  check (subtipo in ('vejo_indevido','nao_vejo','outro'));

alter table public.suporte_chamados
  drop constraint if exists ck_suporte_chamados_status;
alter table public.suporte_chamados
  add constraint ck_suporte_chamados_status
  check (status in ('aberto','em_analise','resolvido','descartado'));
