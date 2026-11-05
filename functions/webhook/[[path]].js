/**
 * PROXY /webhook/* -> n8n
 * Cloudflare Pages Function
 *
 * POR QUE ISTO EXISTE
 * -------------------
 * Hoje as telas e a API moram no mesmo host (SEU-N8N),
 * entao os fetch sao "same-origin" e nao existe CORS.
 *
 * No Pages as telas passam a morar em outro host. Se o navegador falasse
 * direto com o n8n, TODA chamada viraria cross-origin: como elas sao
 * POST + Content-Type: application/json + Authorization: Bearer, o
 * navegador dispararia um preflight OPTIONS antes de cada uma, e seria
 * preciso habilitar CORS em ~30 nos de webhook, um por um.
 *
 * Com este proxy o navegador so conhece UMA origem (a do Pages).
 * Zero CORS, e o n8n nao precisa ser tocado.
 *
 * O caminho e repassado igual:
 *   /webhook/acompanhamento-docente/listar-docentes
 *      -> https://SEU-N8N/webhook/acompanhamento-docente/listar-docentes
 */

const N8N = 'https://SEU-N8N/webhook';   // <<< troque pela base dos webhooks do seu n8n (único lugar a configurar)

export async function onRequest(context) {
  const { request, params } = context;

  // [[path]] entrega o resto do caminho; pode vir como array ou string
  const caminho = Array.isArray(params.path) ? params.path.join('/') : (params.path || '');
  const entrada = new URL(request.url);
  const destino = `${N8N}/${caminho}${entrada.search}`;

  // repassa metodo, headers e corpo sem alterar
  const encaminhada = new Request(destino, request);

  // deixa o n8n saber de onde veio (util para log/debug do lado de la)
  encaminhada.headers.set('X-Forwarded-Host', entrada.host);
  encaminhada.headers.set('X-Forwarded-Proto', entrada.protocol.replace(':', ''));

  try {
    const resposta = await fetch(encaminhada);

    // clona para poder mexer nos headers da resposta
    const saida = new Response(resposta.body, resposta);

    // a API e por sessao: nao deixa nada em cache
    saida.headers.set('Cache-Control', 'no-store');

    return saida;
  } catch (erro) {
    // se o n8n estiver fora, devolve um JSON que as telas conseguem ler
    return new Response(
      JSON.stringify({ ok: false, mensagem: 'Servico indisponivel no momento. Tente novamente.' }),
      { status: 502, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } }
    );
  }
}
