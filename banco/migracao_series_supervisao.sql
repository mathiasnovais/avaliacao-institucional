-- ============================================================
-- SÉRIE COMO RECORTE DE SUPERVISÃO
--
-- Substitui a lista de bloqueio nos casos em que o supervisor
-- responde por PARTE de um segmento.
--
-- O PROBLEMA QUE ISTO RESOLVE
--   A visibilidade era unidade + segmento + disciplina. Mas a
--   divisão real do trabalho é por SÉRIE: na rede, a supervisão do
--   Infantil costuma levar também o 1º ano do Fundamental. Não é
--   exceção, é política, e o sistema não tinha como expressar.
--
-- >>> A REGRA <<<
--   Declarar série é OPT-IN, por acesso:
--   . acesso SEM series  -> nada muda. Vê o segmento inteiro.
--   . acesso COM series  -> vê SÓ docentes cujas séries cruzam com as dele.
--   Consequência: assim que um supervisor declara série, docente SEM série
--   some da tela dele. A lista dele precisa estar completa antes de ligar.
--   Quem não declarou continua igual, então dá para migrar uma unidade por vez.
--
-- POR QUE SÉRIE E NÃO TURMA
--   Supervisor cobre "o 1º ano", não "o 1º ano A". Série é mais grosso, mais
--   fácil de preencher e casa melhor com o sistema acadêmico.
--   professor_alocacoes.turmas (jsonb) continua existindo e vazia.
--
-- ORDEM: PASSO 1 (schema) -> 2 (referência) -> 3 (dados, por unidade) -> 4 (n8n)
-- ============================================================

-- ############################################################
-- PASSO 1: SCHEMA. Tudo aditivo e anulável: nada quebra. Idempotente.
-- ############################################################
alter table public.professor_alocacoes
  add column if not exists series text[];

alter table public.usuario_acessos
  add column if not exists series text[];

comment on column public.professor_alocacoes.series is
  'Series que o docente atende nesta alocacao (ex.: {1ANO}). '
  'NULL/vazio = nao informado -> visivel para todo supervisor do segmento (regra antiga).';

comment on column public.usuario_acessos.series is
  'Recorte de series deste acesso. NULL/vazio = ve o segmento inteiro (regra antiga). '
  'Preenchido = ve SO docentes cujas series cruzam com estas.';

-- Campos para a futura integração com o sistema acadêmico. Ficam nulos por ora;
-- existirem agora evita nova migração depois.
alter table public.professores
  add column if not exists sistema_academico_id text;

alter table public.professor_alocacoes
  add column if not exists sistema_academico_turma_id text;

create index if not exists ix_professores_sistema_academico_id
  on public.professores (sistema_academico_id) where sistema_academico_id is not null;


-- ############################################################
-- PASSO 2: TABELA DE REFERÊNCIA DAS SÉRIES.
--   Não tem FK (arrays não aceitam). Serve de dicionário: garante que
--   todo mundo escreva '1ANO' e não '1º ano'/'1 Ano'/'PRIMEIRO'.
--   A Educação Infantil não está aqui: inclua seguindo o mesmo padrão
--   quando a nomenclatura da rede estiver definida.
-- ############################################################
create table if not exists public.series (
  codigo          text primary key,
  nome            text not null,
  segmento_codigo text not null,
  ordem           int  not null
);

insert into public.series (codigo, nome, segmento_codigo, ordem) values
  ('1ANO','1º ano','EFAI',1),
  ('2ANO','2º ano','EFAI',2),
  ('3ANO','3º ano','EFAI',3),
  ('4ANO','4º ano','EFAI',4),
  ('5ANO','5º ano','EFAI',5),
  ('6ANO','6º ano','EFAF',6),
  ('7ANO','7º ano','EFAF',7),
  ('8ANO','8º ano','EFAF',8),
  ('9ANO','9º ano','EFAF',9),
  ('1EM','1ª série EM','EM',10),
  ('2EM','2ª série EM','EM',11),
  ('3EM','3ª série EM','EM',12)
on conflict (codigo) do nothing;


-- ############################################################
-- PASSO 3: DADOS (exemplo; adapte por unidade).
--   3a. marcar a série das alocações dos docentes
--   3b. dar o recorte ao acesso do supervisor (só no segmento certo)
-- ############################################################
-- update public.professor_alocacoes pa
--    set series = array['1ANO']
--   from public.professores pr
--  where pr.id = pa.professor_id
--    and pa.segmento_codigo = 'EFAI'
--    and coalesce(pa.ativo,true)
--    and pr.email in ('docente1@exemplo.edu.br','docente2@exemplo.edu.br')
-- returning pr.nome, pa.series;

-- update public.usuario_acessos ua
--    set series = array['1ANO']
--   from public.app_usuarios au
--  where au.id = ua.usuario_id
--    and ua.cargo_codigo    = 'SUPERVISAO_SEGMENTO'
--    and ua.segmento_codigo = 'EFAI'
--    and lower(au.email) = 'usuario@exemplo.edu.br'
-- returning au.nome, ua.segmento_codigo, ua.series;

-- Verificação: simula o que o supervisor VAI ver depois do PASSO 4.
-- select au.nome as supervisor, pr.nome as vai_ver, array_to_string(pa.series,',') as serie
-- from public.usuario_acessos ua
-- join public.app_usuarios au on au.id = ua.usuario_id
-- join public.professor_alocacoes pa on pa.unidade_id = ua.unidade_id
--                                   and pa.segmento_codigo = ua.segmento_codigo
--                                   and coalesce(pa.ativo,true)
-- join public.professores pr on pr.id = pa.professor_id and coalesce(pr.ativo,true)
-- where ua.series is not null
--   and coalesce(pa.series,'{}') && ua.series      -- a MESMA regra do n8n
-- order by au.nome, pr.nome;


-- ############################################################
-- PASSO 4: NO n8n (sem isto, a tela não muda).
--   No nó Postgres de acompanhamento-docente/listar-docentes:
--   (a) em acessos_base, no select, acrescente:  ua.series
--   (b) em docentes_base, no select, acrescente:  pa.series
--   (c) nos DOIS ramos de supervisão dentro de docentes_permitidos
--       (SUPERVISAO_SEGMENTO e SUPERVISAO_BILINGUISMO), acrescente:
--         and ( ab.series is null or cardinality(ab.series) = 0
--               or coalesce(db.series,'{}') && ab.series )
--   Salve e ative o workflow.
-- ############################################################


-- ############################################################
-- DESFAZER: zerar as series dos ACESSOS já basta; sem recorte, todo
-- supervisor volta a ver o segmento inteiro.
-- ############################################################
-- update public.usuario_acessos set series = null
--  where series is not null;
