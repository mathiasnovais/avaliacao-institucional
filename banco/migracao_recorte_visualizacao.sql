-- ============================================================
-- RECORTE DE VISUALIZAÇÃO: segmentos que um usuário só VÊ (não avalia)
--   Caso de uso: uma Direção Pedagógica de um segmento precisa VER também
--   outro segmento no Comparativo por Cargo, sem passar a avaliar ninguém dele.
--
-- Por que uma tabela à parte, e não um acesso a mais em usuario_acessos:
-- o acesso vale para TUDO (formulários, férias, dashboards, login). Esta
-- tabela só é lida pelos SQLs de listagem quando o pedido vem do Comparativo
-- (filtros.nota_recebida). Nenhuma outra tela conhece esta tabela.
--
-- ORDEM: rode ESTE arquivo ANTES de atualizar os SQLs de listagem no n8n;
-- eles leem a tabela e dariam erro "relation does not exist" sem ela.
-- ============================================================

-- PASSO 1: tabela (idempotente)
create table if not exists public.usuario_recorte_visualizacao (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid not null references public.app_usuarios(id),
  segmento_codigo text not null,           -- EI | EFAI | EFAF | EM
  ativo           boolean not null default true,
  observacao      text,
  criado_em       timestamptz not null default now(),
  unique (usuario_id, segmento_codigo)
);

-- PASSO 2: conceder o recorte a uma pessoa (exemplo; troque o e-mail e o segmento)
-- insert into public.usuario_recorte_visualizacao (usuario_id, segmento_codigo, observacao)
-- select u.id, 'EM', 'Comparativo por Cargo: vê também o Ensino Médio (só visualização)'
-- from public.app_usuarios u
-- where lower(u.email) = 'usuario@exemplo.edu.br'
-- on conflict (usuario_id, segmento_codigo) do update set ativo = true;

-- PASSO 3: conferência
select u.nome, rv.segmento_codigo, rv.ativo, rv.observacao
from public.usuario_recorte_visualizacao rv
join public.app_usuarios u on u.id = rv.usuario_id;

-- DESFAZER (a tabela pode ficar):
-- update public.usuario_recorte_visualizacao set ativo = false
--  where usuario_id = (select id from public.app_usuarios where lower(email) = 'usuario@exemplo.edu.br');
